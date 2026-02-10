import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/income_model.dart';
import '../models/person_model.dart';
import '../providers/person_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/validators.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  _AddIncomeScreenState createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedPersonId;
  String _selectedMode = 'Cash';
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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
    if (_formKey.currentState!.validate() && _selectedPersonId != null) {
      final transactionProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );

      final newIncome = IncomeModel(
        id: Uuid().v4(),
        amount: double.parse(_amountController.text),
        mode: _selectedMode,
        personId: _selectedPersonId!,
        date: _selectedDate,
        note: _noteController.text,
      );

      final success = await transactionProvider.addIncome(newIncome);

      if (success) {
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(transactionProvider.error ?? 'An error occurred'),
            ),
          );
        }
      }
    } else if (_selectedPersonId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a person')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final personProvider = Provider.of<PersonProvider>(context);
    final persons = personProvider.persons;

    if (persons.isEmpty && !personProvider.isLoading) {
      // Handle case where no persons exist (maybe prompt to create one)
      // For now, assuming persons exist or will be seeded.
    }

    return Scaffold(
      appBar: AppBar(title: Text('Add Income')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedPersonId,
                hint: Text('Select Person'),
                items: persons.map((PersonModel person) {
                  return DropdownMenuItem<String>(
                    value: person.id,
                    child: Text(person.name),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPersonId = newValue;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a person' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: Validators.validateAmount,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedMode,
                decoration: InputDecoration(
                  labelText: 'Mode',
                  border: OutlineInputBorder(),
                ),
                items: ['Cash', 'UPI'].map((String mode) {
                  return DropdownMenuItem<String>(
                    value: mode,
                    child: Text(mode),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMode = newValue!;
                  });
                },
              ),
              SizedBox(height: 16),
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
              SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: Text('Add Income')),
            ],
          ),
        ),
      ),
    );
  }
}
