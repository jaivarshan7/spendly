import 'package:flutter/material.dart';
import '../models/person_model.dart';

class PersonAmountRow extends StatelessWidget {
  final PersonModel person;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const PersonAmountRow({
    super.key,
    required this.person,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(person.name, style: TextStyle(fontSize: 16)),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Text(
              'Bal: ${person.balance.toStringAsFixed(0)}',
              style: TextStyle(
                color: person.balance < 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
