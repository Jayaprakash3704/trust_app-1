import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class PaymentService {
  PaymentService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> createOrder({
    required int donationAmount,
    String? clientRequestId,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('User not signed in');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/payment/create-order'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'donationAmount': donationAmount,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Create order failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> warmUp() async {
    await http.get(Uri.parse('${AppConfig.backendBaseUrl}/health'));
  }

  Future<String> verifyPayment({
    required String transactionId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('User not signed in');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/payment/verify-payment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'transactionId': transactionId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Verify payment failed: ${response.body}');
    }

    if (response.body.isEmpty) {
      return 'unknown';
    }

    final payload = jsonDecode(response.body);
    if (payload is Map && payload['status'] is String) {
      return payload['status'] as String;
    }

    return 'unknown';
  }

  Future<void> markPaymentFailed({required String transactionId}) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('User not signed in');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/payment/payment-failed'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'transactionId': transactionId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Payment failed update error: ${response.body}');
    }
  }
}
