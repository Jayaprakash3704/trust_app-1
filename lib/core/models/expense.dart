import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final int amount;
  final String description;
  final String category;
  final String createdBy;
  final DateTime? timestamp;

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.createdBy,
    required this.timestamp,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parsed;
    final raw = data['timestamp'];
    if (raw is Timestamp) {
      parsed = raw.toDate();
    }

    return Expense(
      id: id,
      amount: data['amount'] ?? 0,
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      createdBy: data['createdBy'] ?? '',
      timestamp: parsed,
    );
  }
}
