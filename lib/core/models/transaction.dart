import 'package:cloud_firestore/cloud_firestore.dart';

class DonationTransaction {
  final String id;
  final String userId;
  final int donationAmount;
  final int platformFee;
  final int totalPaid;
  final String status;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final DateTime? timestamp;

  DonationTransaction({
    required this.id,
    required this.userId,
    required this.donationAmount,
    required this.platformFee,
    required this.totalPaid,
    required this.status,
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.timestamp,
  });

  factory DonationTransaction.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parsed;
    final raw = data['timestamp'];
    if (raw is Timestamp) {
      parsed = raw.toDate();
    }

    return DonationTransaction(
      id: id,
      userId: data['userId'] ?? '',
      donationAmount: data['donationAmount'] ?? 0,
      platformFee: data['platformFee'] ?? 0,
      totalPaid: data['totalPaid'] ?? 0,
      status: data['status'] ?? 'created',
      razorpayOrderId: data['razorpay_order_id'],
      razorpayPaymentId: data['razorpay_payment_id'],
      timestamp: parsed,
    );
  }
}
