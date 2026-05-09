import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.bannerMessage});

  final String? bannerMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _bannerMessage;

  @override
  void initState() {
    super.initState();
    _bannerMessage = widget.bannerMessage;
    if (kIsWeb) {
      _completeWebRedirect();
    }
  }

  Widget _buildLogo() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Image.asset(
        'assets/images/app_logo.png',
        width: 140,
        height: 140,
        fit: BoxFit.contain,
      ),
    );
  }

  Future<void> _signInEmail() async {
    setState(() {
      _busy = true;
      _error = null;
      _bannerMessage = null;
    });

    try {
      await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (error) {
      setState(() {
        _error = 'Sign in failed. Check credentials.';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
      _bannerMessage = null;
    });

    try {
      await _authService.signInWithGoogle(
        linkEmail: _emailController.text.trim(),
        linkPassword: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _error = _googleAuthErrorMessage(error);
      });
    } catch (error) {
      setState(() {
        _error = 'Google sign-in failed.';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _completeWebRedirect() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _authService.completeGoogleSignInRedirect(
        linkEmail: _emailController.text.trim(),
        linkPassword: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _googleAuthErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Google sign-in failed.';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  String _googleAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'Account exists. Sign in with email/password to link Google.';
      case 'operation-not-allowed':
        return 'Google sign-in is disabled in Firebase Auth.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for Google sign-in.';
      case 'popup-blocked':
        return 'Popup blocked. Allow popups and try again.';
      default:
        return 'Google sign-in failed.';
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _error = 'Enter email to reset password.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _bannerMessage = null;
    });

    try {
      await _authService.sendPasswordReset(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } catch (error) {
      setState(() {
        _error = 'Password reset failed.';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: _buildMessage(context),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _signInEmail,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _signInGoogle,
                  child: const Text('Sign in with Google'),
                ),
                TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    final message = _error ?? _bannerMessage;
    if (message == null) {
      return const SizedBox.shrink();
    }
    final isError = _error != null;
    return Text(
      message,
      key: ValueKey(message),
      style: TextStyle(
        color: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
