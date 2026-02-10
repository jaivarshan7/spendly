import 'package:flutter/material.dart';
import '../models/person_model.dart';
import '../services/firestore_service.dart';

class PersonProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  List<PersonModel> _persons = [];
  bool _isLoading = false;

  PersonProvider(this._firestoreService) {
    _init();
  }

  List<PersonModel> get persons => _persons;
  bool get isLoading => _isLoading;

  void _init() {
    _isLoading = true;
    notifyListeners();

    _firestoreService.persons.listen(
      (personList) {
        _persons = personList;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        // Handle error
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> addPerson(String name) async {
    _isLoading = true;
    notifyListeners();
    try {
      final newPerson = PersonModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
      );
      await _firestoreService.addPerson(newPerson);
    } catch (e) {
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
