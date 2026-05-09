import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleSignInInit;

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInit ??= _googleSignIn.initialize();
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential?> signInWithGoogle({
    String? linkEmail,
    String? linkPassword,
  }) async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      }

      await _ensureGoogleSignInInitialized();

      GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) {
          throw StateError('Google sign-in cancelled');
        }
        rethrow;
      }

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Missing Google ID token');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      final linked = await _linkWithPasswordIfPossible(
        error,
        linkEmail,
        linkPassword,
      );
      if (linked != null) {
        return linked;
      }
      rethrow;
    }
  }

  Future<UserCredential?> completeGoogleSignInRedirect({
    String? linkEmail,
    String? linkPassword,
  }) async {
    if (!kIsWeb) {
      return null;
    }

    try {
      return await _auth.getRedirectResult();
    } on FirebaseAuthException catch (error) {
      final linked = await _linkWithPasswordIfPossible(
        error,
        linkEmail,
        linkPassword,
      );
      if (linked != null) {
        return linked;
      }
      rethrow;
    }
  }

  Future<UserCredential?> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    await _auth.setPersistence(Persistence.LOCAL);

    try {
      return await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (error) {
      if (_shouldFallbackToRedirect(error)) {
        await _auth.signInWithRedirect(provider);
        return null;
      }
      rethrow;
    }
  }

  bool _shouldFallbackToRedirect(FirebaseAuthException error) {
    return error.code == 'popup-blocked' ||
        error.code == 'popup-closed-by-user' ||
        error.code == 'cancelled-popup-request';
  }

  Future<UserCredential?> _linkWithPasswordIfPossible(
    FirebaseAuthException error,
    String? linkEmail,
    String? linkPassword,
  ) async {
    if (error.code == 'account-exists-with-different-credential' &&
        error.email != null &&
        error.credential != null &&
        linkEmail != null &&
        linkPassword != null) {
      final email = error.email!;
      final pendingCredential = error.credential!;
      final normalizedInput = linkEmail.trim();
      if (normalizedInput.isNotEmpty &&
          linkPassword.isNotEmpty &&
          normalizedInput.toLowerCase() == email.toLowerCase()) {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: normalizedInput,
          password: linkPassword,
        );
        await userCredential.user?.linkWithCredential(pendingCredential);
        return userCredential;
      }
    }
    return null;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  User? get currentUser => _auth.currentUser;
}
