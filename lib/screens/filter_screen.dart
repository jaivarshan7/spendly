import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../services/firestore_service.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  _FilterScreenState createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Reports & Analysis')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2101),
                );
                if (picked != null) {
                  setState(() {
                    _dateRange = picked;
                  });
                }
              },
              child: Text(
                _dateRange == null
                    ? 'Select Date Range'
                    : '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<IncomeModel>>(
              stream: firestoreService.incomes,
              builder: (context, incomeSnapshot) {
                return StreamBuilder<List<ExpenseModel>>(
                  stream: firestoreService.expenses,
                  builder: (context, expenseSnapshot) {
                    if (!incomeSnapshot.hasData || !expenseSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    List<IncomeModel> incomes = incomeSnapshot.data!;
                    List<ExpenseModel> expenses = expenseSnapshot.data!;

                    // Filter
                    if (_dateRange != null) {
                      incomes = incomes
                          .where(
                            (i) =>
                                i.date.isAfter(
                                  _dateRange!.start.subtract(Duration(days: 1)),
                                ) &&
                                i.date.isBefore(
                                  _dateRange!.end.add(Duration(days: 1)),
                                ),
                          )
                          .toList();
                      expenses = expenses
                          .where(
                            (e) =>
                                e.date.isAfter(
                                  _dateRange!.start.subtract(Duration(days: 1)),
                                ) &&
                                e.date.isBefore(
                                  _dateRange!.end.add(Duration(days: 1)),
                                ),
                          )
                          .toList();
                    }

                    double totalIncome = incomes.fold(
                      0,
                      (sum, item) => sum + item.amount,
                    );
                    double totalExpense = expenses.fold(
                      0,
                      (sum, item) => sum + item.totalAmount,
                    );
                    double balance = totalIncome - totalExpense;

                    // Category Stats
                    Map<String, double> categoryStats = {};
                    for (var e in expenses) {
                      for (var c in e.categories) {
                        categoryStats[c['name']] =
                            (categoryStats[c['name']] ?? 0) +
                            (c['amount'] as num).toDouble();
                      }
                    }

                    // Pie Chart Data
                    List<PieChartSectionData> pieSections = categoryStats
                        .entries
                        .map((e) {
                          return PieChartSectionData(
                            value: e.value,
                            title: e.key,
                            color:
                                Colors.primaries[categoryStats.keys
                                        .toList()
                                        .indexOf(e.key) %
                                    Colors.primaries.length],
                            radius: 50,
                          );
                        })
                        .toList();

                    return ListView(
                      padding: EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'Total Income: ₹$totalIncome',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'Total Expense: ₹$totalExpense',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 18,
                                  ),
                                ),
                                Divider(),
                                Text(
                                  'Net Balance: ₹$balance',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Category-wise Spending',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(
                          height: 200,
                          child: pieSections.isEmpty
                              ? Center(child: Text("No expenses"))
                              : PieChart(
                                  PieChartData(
                                    sections: pieSections,
                                    centerSpaceRadius: 40,
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
