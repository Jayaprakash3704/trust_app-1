import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle({
    String? linkEmail,
    String? linkPassword,
  }) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw StateError('Google sign-in cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
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

      rethrow;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  User? get currentUser => _auth.currentUser;
}
