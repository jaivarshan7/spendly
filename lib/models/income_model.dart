import 'package:cloud_firestore/cloud_firestore.dart';

class IncomeModel {
  final String id;
  final double amount;
  final String mode; // 'Cash' or 'UPI'
  final String personId;
  final DateTime date;
  final String? note;

  IncomeModel({
    required this.id,
    required this.amount,
    required this.mode,
    required this.personId,
    required this.date,
    this.note,
  });

  factory IncomeModel.fromMap(Map<String, dynamic> map, String id) {
    return IncomeModel(
      id: id,
      amount: (map['amount'] ?? 0.0).toDouble(),
      mode: map['mode'] ?? 'Cash',
      personId: map['personId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'mode': mode,
      'personId': personId,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
}
