import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../models/person_model.dart';
import '../providers/person_provider.dart';
import '../services/firestore_service.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final personProvider = Provider.of<PersonProvider>(context);
    final persons = personProvider.persons;

    return Scaffold(
      appBar: AppBar(title: Text('Transactions')),
      body: StreamBuilder<List<IncomeModel>>(
        stream: firestoreService.incomes,
        builder: (context, incomeSnapshot) {
          return StreamBuilder<List<ExpenseModel>>(
            stream: firestoreService.expenses,
            builder: (context, expenseSnapshot) {
              if (incomeSnapshot.connectionState == ConnectionState.waiting ||
                  expenseSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!incomeSnapshot.hasData || !expenseSnapshot.hasData) {
                return Center(child: Text("No data"));
              }

              final incomes = incomeSnapshot.data!;
              final expenses = expenseSnapshot.data!;

              final transactions = [...incomes, ...expenses];
              transactions.sort((a, b) {
                DateTime dateA = a is IncomeModel
                    ? a.date
                    : (a as ExpenseModel).date;
                DateTime dateB = b is IncomeModel
                    ? b.date
                    : (b as ExpenseModel).date;
                return dateB.compareTo(dateA);
              });

              if (transactions.isEmpty) {
                return Center(child: Text('No transactions found'));
              }

              return ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];

                  if (transaction is IncomeModel) {
                    return ListTile(
                      leading: Icon(Icons.arrow_downward, color: Colors.green),
                      title: Text('Income: ${transaction.mode}'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(transaction.date),
                      ),
                      trailing: Text(
                        '+ ₹${transaction.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  } else if (transaction is ExpenseModel) {
                    return ExpansionTile(
                      leading: Icon(Icons.arrow_upward, color: Colors.red),
                      title: Text('Expense: ₹${transaction.totalAmount}'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(transaction.date),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Categories:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ...transaction.categories.map(
                                (c) => Text('${c['name']}: ₹${c['amount']}'),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Contributors:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ...transaction.contributors.map((c) {
                                final personId = c['personId'];
                                final person = persons.firstWhere(
                                  (p) => p.id == personId,
                                  orElse: () => PersonModel(
                                    id: 'unknown',
                                    name: 'Unknown',
                                  ),
                                );
                                return Text('${person.name}: ₹${c['amount']}');
                              }),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return SizedBox();
                },
              );
            },
          );
        },
      ),
    );
  }
}
