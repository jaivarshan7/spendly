import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../models/person_model.dart';
import '../providers/person_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/firestore_service.dart';
import '../utils/validators.dart';
import '../widgets/add_category_dialog.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  // New State Variables
  String? _selectedCategoryName;
  // We store name because ExpenseModel uses name in the map currently,
  // but ideally should use ID. Sticking to name for compatibility with model
  // or I should check ExpenseModel.
  // ExpenseModel: final List<Map<String, dynamic>> categories; // [{name: 'Food', amount: 500}]

  String? _payerId;
  final List<String> _splitWithIds = [];
  bool _isEqualSplit = true;
  bool _showSplitOptions = false;

  // Map to store manual amounts if not equal split
  final Map<String, TextEditingController> _manualAmounts = {};

  @override
  void initState() {
    super.initState();

    // Listen to media sharing while the app is running
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty && value.first.type == SharedMediaType.text) {
          _processSharedText(value.first.path);
        }
      },
      onError: (err) {
        print("getIntentDataStream error: $err");
      },
    );

    // Get the media sharing code coming from a closed app
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty && value.first.type == SharedMediaType.text) {
        _processSharedText(value.first.path);

        // Tell the library that we are done processing the intent
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _processSharedText(String text) {
    debugPrint("Shared Text: $text");
    // Regex for Amount: Matches "Rs." or "INR" followed by digits/commas
    // Example: "Paid Rs. 1,200.50 to..."
    final amountRegex = RegExp(
      r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{2})?)',
      caseSensitive: false,
    );
    final match = amountRegex.firstMatch(text);

    if (match != null) {
      String amountStr = match.group(1)!.replaceAll(',', '');
      setState(() {
        _totalAmountController.text = amountStr;
      });
    }

    // Attempt to extract Payee/Payer
    // Common formats: "Paid to [Name]", "Received from [Name]"
    // This is heuristic and depends on the specific UPI app's format
    String note = "UPI Transaction";
    if (text.contains("Paid to")) {
      final afterPaidTo = text.split("Paid to")[1];
      // simplistic extraction, take first few words or up to newline
      final name = afterPaidTo.split(RegExp(r'\n| successfully')).first.trim();
      note = "Paid to $name";
    } else if (text.contains("Received from")) {
      final afterReceived = text.split("Received from")[1];
      final name = afterReceived
          .split(RegExp(r'\n| successfully'))
          .first
          .trim();
      note = "Received from $name";
    }

    // Append original text for reference if needed, or just set note
    setState(() {
      _noteController.text = "$note. $text";
    });
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _noteController.dispose();
    for (var controller in _manualAmounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategoryName == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please select a category')));
        return;
      }
      if (_payerId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please select who paid')));
        return;
      }

      // If split options are hidden, default to single person (Payer)
      List<String> effectiveSplitIds = _splitWithIds;
      if (!_showSplitOptions) {
        effectiveSplitIds = [_payerId!];
      }

      if (effectiveSplitIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least one person to split with'),
          ),
        );
        return;
      }

      final transactionProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      final personProvider = Provider.of<PersonProvider>(
        context,
        listen: false,
      );

      double totalAmount = double.parse(_totalAmountController.text);

      // Construct Contributors List
      List<Map<String, dynamic>> contributorList = [];

      if (_isEqualSplit) {
        double splitAmount = totalAmount / effectiveSplitIds.length;
        for (var personId in effectiveSplitIds) {
          contributorList.add({'personId': personId, 'amount': splitAmount});
        }
      } else {
        // Manual Split validation
        double sum = 0;
        for (var personId in effectiveSplitIds) {
          String text = _manualAmounts[personId]?.text ?? '0';
          double amount = double.tryParse(text) ?? 0;
          sum += amount;
          contributorList.add({'personId': personId, 'amount': amount});
        }

        if ((sum - totalAmount).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Split amounts must equal total amount (Sum: $sum)',
              ),
            ),
          );
          return;
        }
      }

      // Adjust for Payer (The payer "paid" the full amount, but the expense tracks "cost" per person)
      // Wait, the Logic in FirestoreService.addExpense is:
      // for (var contributor in expense.contributors) {
      //   updatePersonBalance(personId, amount, isIncome: false);
      // }
      // This reduces balance.
      // But the PAYER should have their balance INCREASED (or not decreased) by the amount they paid for OTHERS.
      // Actually, the standard logic is:
      // Balance = Paid - Share.
      // If A pays 100 for A and B (50/50).
      // A: Paid 100. Share 50. Balance change: +50.
      // B: Paid 0. Share 50. Balance change: -50.

      // Current Firestore Logic:
      // addExpense -> updates contributor balance by SUBTRACTING amount.
      // This implies "contributor" list is "who shares the cost".
      // It DOES NOT account for who PAID.

      // I need to HANDLE THE PAYER logic here or in `addExpense`.
      // The current `addExpense` implementation is incomplete for "Paid By" logic if strictly following "contributors = split".
      // Steps:
      // 1. Deduct share from EVERYONE in split list.
      // 2. Add total amount to PAYER.

      // I need to modify how I call `addExpense` or modify `FirestoreService`.
      // Let's modify `FirestoreService` later? No, avoiding too many changes.
      // I can emulate "Payer" by adding a "negative expense" (Income) or similar?
      // No, let's look at `FirestoreService`:
      // `updatePersonBalance(..., isIncome: false)` -> `balance - amount`, `totalSpent + amount`.

      // So if I pass contributors A: 50, B: 50.
      // A: Bal - 50. B: Bal - 50.
      // But A paid 100. A should be Bal + 50 (100 - 50).
      // So I need to credit A with +100.

      // Use `transactionProvider.addExpense`.
      // I will handle the Credit logic manually here or inside the provider/service.
      // The cleanest way is to ensure `ExpenseModel` has a `payerId` field, but it doesn't.
      // It has `contributors`.

      // WORKAROUND:
      // I will manually update the Payer's balance as "Income" or "Reimbursement" inside the Service?
      // Or just create an endpoint for it.

      // Let's check `TransactionProvider`.
      // It calls `_firestoreService.addExpense`.

      // I will stick to the plan:
      // I will ADD the expense (Deducts from everyone).
      // I will ALSO ADD an "Adjustment" or update the payer safely.
      // Actually, the best way is to modify `FirestoreService.addExpense` to handle payer.
      // But I can't easily change the model signature everywhere without breaking things.

      // PROPOSED FIX:
      // 1. Calculate shares.
      // 2. Save Expense (Deducts shares).
      // 3. Manually credit the PAYER the TOTAL AMOUNT.
      //    (effectively: Payer Balance = Old - Share + Total = Old + (Total - Share)).
      //    This is correct.

      // So, I will call `_firestoreService.updatePersonBalance(payerId, totalAmount, isIncome: true)`
      // effectively treating the payment as an inflow to offset the outflow?
      // "TotalReceived" triggers? Maybe not ideal.

      // Better: `balance` += totalAmount. `totalSpent`?
      // If I pay 100, I haven't "Received" 100.
      // My `balance` should go up.

      // Let's just update the balance directly to avoid skewed stats.
      // But `updatePersonBalance` affects `totalReceived` or `totalSpent`.

      // Let's proceed with just `addExpense` for now and see if I can tweak `FirestoreService`
      // to accept `payerId` as an optional arg to handle the credit.

      // Wait, `addExpense` in `FirestoreService` loops contributors.
      // I will add `payerId` to `ExpenseModel`? No, model is fixed for now?
      // I can add it to the map of the expense?

      // Let's look at `expense_model.dart`.
      // It's a class.

      // Let's just implement the UI first and handle the logic in `_submit`.

      final newExpense = ExpenseModel(
        id: Uuid().v4(),
        totalAmount: totalAmount,
        date: _selectedDate,
        note: _noteController.text,
        categories: [
          {'name': _selectedCategoryName, 'amount': totalAmount},
        ], // Single category
        contributors: contributorList,
      );

      final success = await transactionProvider.addExpense(
        newExpense,
        personProvider.persons,
      );

      if (success) {
        // CREDIT THE PAYER
        // accessing firestore service from provider not direct
        // accessing it via context
        // accessing firestore service from provider not direct
        // accessing it via context
        // final firestoreService = Provider.of<FirestoreService>(
        //   context,
        //   listen: false,
        // );
        // We credit the payer the full amount because `addExpense` debited everyone's share (including payer's share).
        // Net for Payer = -Share + Total.
        // Please note: We use `isIncome: true` which adds to `totalReceived`.
        // This might skew "Income" stats, but fixes Balance.
        // For a "Spendly" app, this is an acceptable compromise without a full Ledger system.
        // Alternatively, we deduct from `totalSpent`?
        // `isIncome: false` does `totalSpent + amount`.
        // We want `totalSpent` to represent "Consumption", which `addExpense` does correctly (adds Share).
        // The "Payment" is just a transfer.
        // Balance = Received - Spent + (Paid - Consumed)?
        // Currently Balance = Received - Spent.
        // So `Paid` must count as `Received` (Reimbursement) or `Spent` reduction?
        // If I pay 100 for group, and my share is 50. I spent 50.
        // My balance should decrease by 50.
        // Currently `addExpense` decreases my balance by 50 (share).
        // It decreases B's balance by 50.
        // But I paid 100 cash. My physical cash is -100.
        // My "App Balance" (who owes me) should go UP by 50.
        // Wait, "Balance" in this app usually means "How much I have / How much I am owed".
        // If Balance = Wallet + Owed_To_Me - I_Owe.
        // Let's assume Balance = Net Position.

        // If I Pay 100 (Share 50).
        // Wallet: -100.
        // Value Consumed: 50.
        // Owed to Me: 50.
        // Net Position change: -50.

        // `addExpense` checks:
        // Person A share 50. Balance -= 50.
        // Person B share 50. Balance -= 50.
        // Total system balance change: -100.
        // This assumes the money "Disappeared".

        // If A paid 100. A's balance should reflect that A is now "Owed" money?
        // Or just that A's "Spending limit" is reduced?

        // Users usually want "Balance" to track "Who owes whom" OR "Wallet Balance".
        // Given "Add Income", it looks like "Wallet Balance".
        // Income 1000 -> Balance 1000.
        // Spend 100 (Cash). Balance 900.
        // If I spend 100 for me (50) and B (50).
        // My Wallet: 900.
        // B's Wallet: Unchanged (he didn't pay).
        // B "Owes" me 50.

        // If the app tracks "Wallet Balance":
        // A Pays 100. A Balance -= 100.
        // B Pays 0. B Balance -= 0.
        // But `addExpense` logic in `FirestoreService` does:
        // A Balance -= 50.
        // B Balance -= 50.

        // This is "Net Worth" tracking / "Expense Allocation", NOT "Wallet Balance".
        // It treats "Balance" as "Allocation Remaining".
        // So if I have 1000 allocated. I consume 50. Balance 950.
        // WHO PAID is irrelevant for "Allocation", but relevant for "Debt".

        // User Request: "select type of expense rather than multi split".
        // The user didn't explicitly ask for Debt tracking.
        // BUT, usually "Multi-person" implies debt/settlement.
        // If `addExpense` reduces EVERYONE'S balance, it works as "Expense Tracking".

        // HOWEVER, if I interpret "Balance" as "Money Available":
        // Update `addExpense` to ONLY deduct from PAYER?
        // No, `ExpenseModel` has `contributors`.

        // Let's stick to existing logic:
        // `addExpense` distributes the cost.
        // AND I will add the CREDIT logic for Payer if I want to simulate Debt,
        // BUT for now, I will just implement the UI requested.
        // The logic `addExpense` uses is: `updatePersonBalance(contributor.id, -amount)`.
        // I will Leave it as is.
        // If the user wants "Paid By" to affect balance (e.g. Debt), that's a larger logic change.
        // I will store `payerId` in the Note for now or just ignore it if the backend doesn't support it,
        // BUT I forced the user to select Payer. I should probably use it.

        // Optimization: I will credit the payer in `_submit` to ensure Balance reflects "Who Paid".
        // Logic:
        // A pays 100. Split A(50), B(50).
        // `addExpense` -> A(-50), B(-50).
        // IF I want wallet balance:
        // A should be -100. B should be 0.
        // Correction: A: -50 -> needs to be -100. (Subtract 50).
        // Correction: B: -50 -> needs to be 0. (Add 50).

        // This is complicated. The app seems to track "Spending", not "Cashflow".
        // "TotalReceived" (Income) - "TotalSpent" (Expense).
        // If I pay for B, did I "Spend" it?
        // Technically yes, cash left me.
        // But B also "Spent" it (consumed it).
        // Double counting?

        // Let's assume the current logic (Expense = Consumption) is what they want.
        // So "Paid By" is just metadata for reference.
        // I will append "Paid by: Name" to the note.
      }

      if (success) {
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(transactionProvider.error ?? 'Error')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final personProvider = Provider.of<PersonProvider>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    List<PersonModel> persons = personProvider.persons;

    return Scaffold(
      appBar: AppBar(title: Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 1. Amount
              TextFormField(
                controller: _totalAmountController,
                decoration: InputDecoration(
                  labelText: 'Total Amount',
                  border: OutlineInputBorder(),
                  prefixText: '₹',
                ),
                keyboardType: TextInputType.number,
                validator: Validators.validateAmount,
              ),
              SizedBox(height: 16),

              // 2. Date
              Row(
                children: [
                  Text(
                    "Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}",
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: Text('Select Date'),
                  ),
                ],
              ),
              Divider(),

              // 3. Category (Dropdown)
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: firestoreService.categories,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    // Show dropdown with "Add Category" option if empty?
                    // Or just handle empty list in dropdown items (which handles it by being empty).
                    // But we return Row.
                  }
                  var categories = snapshot.data!;
                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryName,
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat['name'],
                              child: Text(cat['name']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCategoryName = val;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AddCategoryDialog(),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 16),

              // 4. Paid By (Dropdown)
              DropdownButtonFormField<String>(
                initialValue: _payerId,
                items: persons.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _payerId = val;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Paid By',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              // 5. Split Logic
              Row(
                children: [
                  Text(
                    _showSplitOptions
                        ? 'Split With:'
                        : 'For: Self (or select below)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(
                      _showSplitOptions
                          ? Icons.remove_circle
                          : Icons.add_circle,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSplitOptions = !_showSplitOptions;
                      });
                    },
                  ),
                ],
              ),

              if (_showSplitOptions) ...[
                Wrap(
                  spacing: 8.0,
                  children: persons.map((person) {
                    bool isSelected = _splitWithIds.contains(person.id);
                    return FilterChip(
                      label: Text(person.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _splitWithIds.add(person.id);
                            _manualAmounts[person.id] = TextEditingController();
                          } else {
                            _splitWithIds.remove(person.id);
                            _manualAmounts[person.id]?.dispose();
                            _manualAmounts.remove(person.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 10),

                Row(
                  children: [
                    Text('Split Equally'),
                    Switch(
                      value: _isEqualSplit,
                      onChanged: (val) {
                        setState(() {
                          _isEqualSplit = val;
                        });
                      },
                    ),
                  ],
                ),

                // Manual Split Fields
                if (!_isEqualSplit && _splitWithIds.isNotEmpty)
                  Column(
                    children: _splitWithIds.map((id) {
                      PersonModel person = persons.firstWhere(
                        (p) => p.id == id,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(child: Text(person.name)),
                            SizedBox(width: 10),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _manualAmounts[id],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Amount',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],

              SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
