import 'package:flutter/material.dart';

class CategoryAmountRow extends StatelessWidget {
  final String category;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const CategoryAmountRow({
    super.key,
    required this.category,
    required this.controller,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(category, style: TextStyle(fontSize: 16)),
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
          if (onRemove != null)
            IconButton(
              icon: Icon(Icons.remove_circle, color: Colors.red),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
