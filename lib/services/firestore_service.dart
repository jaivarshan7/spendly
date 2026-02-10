import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/person_model.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';

class FirestoreService {
  final String uid;
  FirestoreService({required this.uid});

  // Collection references
  final CollectionReference userCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference personCollection = FirebaseFirestore.instance
      .collection('persons');
  final CollectionReference categoryCollection = FirebaseFirestore.instance
      .collection('categories');
  final CollectionReference incomeCollection = FirebaseFirestore.instance
      .collection('income_transactions');
  final CollectionReference expenseCollection = FirebaseFirestore.instance
      .collection('expense_transactions');

  // --- Person Operations ---

  Future<void> addPerson(PersonModel person) async {
    // Ideally, person should be linked to the user, but for now we follow the structure
    var personMap = person.toMap();
    personMap['userId'] = uid;
    return await personCollection.doc(person.id).set(personMap);
  }

  Stream<List<PersonModel>> get persons {
    return personCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(_personListFromSnapshot);
  }

  List<PersonModel> _personListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return PersonModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  Future<void> updatePersonBalance(
    String personId,
    double amount, {
    bool isIncome = true,
  }) async {
    DocumentReference personRef = personCollection.doc(personId);
    DocumentSnapshot doc = await personRef.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      // Ensure the person belongs to the current user
      if (data['userId'] != uid) {
        throw Exception("Unauthorized access to person data");
      }
      PersonModel person = PersonModel.fromMap(data, doc.id);
      if (isIncome) {
        await personRef.update({
          'balance': person.balance + amount,
          'totalReceived': person.totalReceived + amount,
        });
      } else {
        await personRef.update({
          'balance': person.balance - amount,
          'totalSpent': person.totalSpent + amount,
        });
      }
    }
  }

  // Method to update generic fields of a person
  Future<void> updatePerson(String personId, Map<String, dynamic> data) async {
    return await personCollection.doc(personId).update(data);
  }

  // --- Category Operations ---

  Future<void> addCategory(String name) async {
    // Categories can be simple documents with just a name and id
    await categoryCollection.add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': uid,
    });
  }

  Stream<List<Map<String, dynamic>>> get categories {
    return categoryCollection.where('userId', isEqualTo: uid).snapshots().map((
      snapshot,
    ) {
      var docs = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
          'createdAt': doc['createdAt'],
        }; // Include createdAt for sorting
      }).toList();

      // Sort by createdAt descending (newest first) or ascending?
      // Previous was orderBy('createdAt'). Default is ascending.
      docs.sort((a, b) {
        Timestamp? t1 = a['createdAt'] as Timestamp?;
        Timestamp? t2 = b['createdAt'] as Timestamp?;
        if (t1 == null) return 1;
        if (t2 == null) return -1;
        return t1.compareTo(t2);
      });

      return docs;
    });
  }

  // --- Income Operations ---

  Future<void> addIncome(IncomeModel income) async {
    var incomeMap = income.toMap();
    incomeMap['userId'] = uid;
    await incomeCollection.doc(income.id).set(incomeMap);
    // Update person balance
    await updatePersonBalance(income.personId, income.amount, isIncome: true);
  }

  Stream<List<IncomeModel>> get incomes {
    return incomeCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(_incomeListFromSnapshot);
  }

  List<IncomeModel> _incomeListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return IncomeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  // --- Expense Operations ---

  Future<void> addExpense(ExpenseModel expense) async {
    var expenseMap = expense.toMap();
    expenseMap['userId'] = uid;
    await expenseCollection.doc(expense.id).set(expenseMap);

    // Update contributors' balances
    for (var contributor in expense.contributors) {
      String personId = contributor['personId'];
      double amount = (contributor['amount'] as num).toDouble();
      await updatePersonBalance(personId, amount, isIncome: false);
    }
  }

  Stream<List<ExpenseModel>> get expenses {
    return expenseCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(_expenseListFromSnapshot);
  }

  List<ExpenseModel> _expenseListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }
}
