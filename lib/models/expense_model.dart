import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final double totalAmount;
  final DateTime date;
  final String? note;
  final List<Map<String, dynamic>> categories; // [{name: 'Food', amount: 500}]
  final List<Map<String, dynamic>>
  contributors; // [{personId: 'p1', amount: 700}]

  ExpenseModel({
    required this.id,
    required this.totalAmount,
    required this.date,
    this.note,
    required this.categories,
    required this.contributors,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseModel(
      id: id,
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
      categories: List<Map<String, dynamic>>.from(map['categories'] ?? []),
      contributors: List<Map<String, dynamic>>.from(map['contributors'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalAmount': totalAmount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'categories': categories,
      'contributors': contributors,
    };
  }
}
