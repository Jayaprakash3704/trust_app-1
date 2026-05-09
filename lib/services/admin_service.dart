import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class AdminService {
  AdminService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  void _assertBackendConfigured() {
    if (AppConfig.backendBaseUrl.contains('your-render-service.onrender.com')) {
      throw StateError('Set BACKEND_BASE_URL to your backend URL.');
    }
  }

  Future<String> _requireToken() async {
    final token = await _auth.currentUser?.getIdToken(true);
    if (token == null) {
      throw StateError('Not signed in');
    }
    return token;
  }

  Future<Map<String, dynamic>> createUser({
    required String email,
    required String name,
    required String phone,
    required String address,
    required String aadhaar,
    required String pan,
  }) async {
    _assertBackendConfigured();

    final token = await _requireToken();

    http.Response response;
    try {
      response = await http.post(
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
        }),
      );
    } on http.ClientException {
      throw StateError('Backend unreachable. Check BACKEND_BASE_URL or CORS.');
    } catch (_) {
      throw StateError('Backend unreachable. Check BACKEND_BASE_URL or CORS.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Could not create member.';
      if (response.body.isNotEmpty) {
        try {
          final payload = jsonDecode(response.body);
          if (payload is Map && payload['error'] != null) {
            message = payload['error'].toString();
          } else {
            message = response.body;
          }
        } catch (_) {
          message = response.body;
        }
      }
      throw StateError(message);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateUser({
    required String userId,
    required String name,
    required String phone,
    required String address,
    String? aadhaar,
    String? pan,
  }) async {
    _assertBackendConfigured();

    final token = await _requireToken();

    final payload = {
      'userId': userId,
      'name': name,
      'phone': phone,
      'address': address,
      if (aadhaar != null && aadhaar.isNotEmpty) 'aadhaar': aadhaar,
      if (pan != null && pan.isNotEmpty) 'pan': pan,
    };

    http.Response response;
    try {
      response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/admin/update-user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    } on http.ClientException {
      throw StateError('Backend unreachable. Check BACKEND_BASE_URL or CORS.');
    } catch (_) {
      throw StateError('Backend unreachable. Check BACKEND_BASE_URL or CORS.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Could not update member.';
      if (response.body.isNotEmpty) {
        try {
          final payload = jsonDecode(response.body);
          if (payload is Map && payload['error'] != null) {
            message = payload['error'].toString();
          } else {
            message = response.body;
          }
        } catch (_) {
          message = response.body;
        }
      }
      throw StateError(message);
    }
  }

  Future<String> createPasswordResetLink({required String userId}) async {
    _assertBackendConfigured();

    final token = await _requireToken();

    http.Response response;
    try {
      response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/admin/reset-link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': userId}),
      );
    } on http.ClientException {
      throw StateError('Backend unreachable. Check BACKEND_BASE_URL or CORS.');
    } catch (_) {
      throw StateError('Backend unreachable. Check BACKEND_BASE_URL or CORS.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Could not generate reset link.';
      if (response.body.isNotEmpty) {
        try {
          final payload = jsonDecode(response.body);
          if (payload is Map && payload['error'] != null) {
            message = payload['error'].toString();
          } else {
            message = response.body;
          }
        } catch (_) {
          message = response.body;
        }
      }
      throw StateError(message);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final link = payload['passwordResetLink'] as String?;
    if (link == null || link.isEmpty) {
      throw StateError('Reset link missing in response');
    }
    return link;
  }
}
