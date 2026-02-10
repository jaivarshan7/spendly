import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/person_provider.dart';
import 'add_income_screen.dart';
import 'add_expense_screen.dart';
import 'transaction_list_screen.dart';
import 'filter_screen.dart';

import 'profile_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final personProvider = Provider.of<PersonProvider>(context);
    final persons = personProvider.persons;

    return Scaffold(
      appBar: AppBar(
        title: Text('Spendly Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () {
              _showAddPersonDialog(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.account_circle, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: personProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance Summary',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: persons.length,
                      itemBuilder: (context, index) {
                        final person = persons[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text(person.name[0])),
                            title: Text(person.name),
                            subtitle: Text(
                              'Spent: ₹${person.totalSpent.toStringAsFixed(2)}',
                            ),
                            trailing: Text(
                              '₹${person.balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: person.balance >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('Income'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddIncomeScreen(),
                            ),
                          );
                        },
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.remove),
                        label: Text('Expense'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddExpenseScreen(),
                            ),
                          );
                        },
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.list),
                        label: Text('Transactions'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionListScreen(),
                            ),
                          );
                        },
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.pie_chart),
                        label: Text('Reports'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FilterScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  void _showAddPersonDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Person'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: "Enter person's name"),
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
                  final personProvider = Provider.of<PersonProvider>(
                    context,
                    listen: false,
                  );
                  await personProvider.addPerson(name);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
