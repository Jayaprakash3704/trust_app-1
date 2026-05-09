import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../admin/dashboard/admin_shell.dart';
import '../user/dashboard/user_dashboard_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const String _missingProfileMessage =
      'No account exists for this sign-in. Please contact the admin.';
  final _authService = AuthService();
  String? _loginBannerMessage;
  bool _requestedSignOut = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          _requestedSignOut = false;
          return LoginScreen(bannerMessage: _loginBannerMessage);
        }

        return StreamBuilder(
          stream: FirestoreService().watchUser(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final appUser = userSnapshot.data;
            if (appUser == null) {
              _loginBannerMessage ??= _missingProfileMessage;
              if (!_requestedSignOut) {
                _requestedSignOut = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _authService.signOut();
                });
              }
              return LoginScreen(bannerMessage: _loginBannerMessage);
            }

            _loginBannerMessage = null;
            _requestedSignOut = false;

            if (appUser.role == 'admin') {
              return const AdminShell();
            }

            return const UserDashboardScreen();
          },
        );
      },
    );
  }
}
