import 'package:flutter/material.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../models/person_model.dart';
import '../services/firestore_service.dart';

class TransactionProvider with ChangeNotifier {
  final FirestoreService _firestoreService;

  TransactionProvider(this._firestoreService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  // Add Income
  Future<bool> addIncome(IncomeModel income) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.addIncome(income);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Add Expense with validation
  Future<bool> addExpense(
    ExpenseModel expense,
    List<PersonModel> currentPersons,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validation Logic
      double categoryTotal = expense.categories.fold(
        0,
        (sum, item) => sum + (item['amount'] as num).toDouble(),
      );
      double contributorTotal = expense.contributors.fold(
        0,
        (sum, item) => sum + (item['amount'] as num).toDouble(),
      );

      if ((categoryTotal - expense.totalAmount).abs() > 0.01) {
        throw "Category split total ($categoryTotal) does not match total expense (${expense.totalAmount})";
      }

      if ((contributorTotal - expense.totalAmount).abs() > 0.01) {
        throw "Contributor split total ($contributorTotal) does not match total expense (${expense.totalAmount})";
      }

      // Balance check
      for (var contributor in expense.contributors) {
        String personId = contributor['personId'];
        double amount = (contributor['amount'] as num).toDouble();

        PersonModel person = currentPersons.firstWhere(
          (p) => p.id == personId,
          orElse: () => throw "Person not found",
        );
        if (person.balance < amount) {
          throw "${person.name} has insufficient balance (Balance: ${person.balance}, Contribution: $amount)";
        }
      }

      await _firestoreService.addExpense(expense);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
