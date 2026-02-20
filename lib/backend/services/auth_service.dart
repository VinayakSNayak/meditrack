import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      return null;
    }
  }

  static Future<User?> signup(
      String email, String password) async {
    try {
      final userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null) {
        await FirestoreService
            .createUserWithSelfMember(email);
      }

      return user;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> resetPassword(
      String email) async {
    try {
      await _auth.sendPasswordResetEmail(
          email: email);
      return true;
    } catch (e) {
      return false;
    }
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }
}
