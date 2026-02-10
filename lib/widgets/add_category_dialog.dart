import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';

class AddCategoryDialog extends StatelessWidget {
  const AddCategoryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();

    return AlertDialog(
      title: Text('Add New Category'),
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(hintText: "Enter category name"),
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text('Add'),
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              final firestoreService = Provider.of<FirestoreService>(
                context,
                listen: false,
              );
              await firestoreService.addCategory(name);
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}
