import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models/app_user.dart';
import '../core/models/expense.dart';
import '../core/models/transaction.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<AppUser?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return AppUser.fromMap(doc.id, doc.data() ?? {});
    });
  }

  Stream<List<DonationTransaction>> watchUserTransactions(String uid) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => DonationTransaction.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Stream<List<DonationTransaction>> watchAllTransactions() {
    return _firestore
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => DonationTransaction.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Stream<List<AppUser>> watchUsers() {
    return _firestore.collection('users').orderBy('name').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<int> fetchUserCount() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.size;
  }

  Future<List<DonationTransaction>> fetchTransactions({
    DateTime? start,
    DateTime? end,
    String? status,
    String? userId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('transactions');

    if (userId != null && userId.isNotEmpty) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    if (start != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: start);
    }
    if (end != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: end);
    }

    query = query.orderBy('timestamp', descending: true);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => DonationTransaction.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Expense>> watchExpenses() {
    return _firestore
        .collection('expenses')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Expense.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Future<void> addExpense({
    required int amountPaise,
    required String description,
    required String category,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    await _firestore.collection('expenses').add({
      'amount': amountPaise,
      'description': description,
      'category': category,
      'createdBy': createdBy,
      'year': now.year,
      'month': now.month,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore.collection('expenses').doc(expenseId).delete();
  }

  Future<void> createReport({
    required int year,
    required int totalRevenue,
    required int totalUsers,
  }) async {
    await _firestore.collection('reports').add({
      'year': year,
      'totalRevenue': totalRevenue,
      'totalUsers': totalUsers,
      'generatedAt': FieldValue.serverTimestamp(),
    });
  }
}
