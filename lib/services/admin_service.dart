import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class AdminService {
  AdminService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> createUser({
    required String email,
    required String name,
    required String phone,
    required String address,
    required String aadhaar,
    required String pan,
    String role = 'user',
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('User not signed in');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.backendBaseUrl}/admin/create-user'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'email': email,
        'name': name,
        'phone': phone,
        'address': address,
        'aadhaar': aadhaar,
        'pan': pan,
        'role': role,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Create user failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
