import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/errors/app_exception.dart';
import 'firestore_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ========================= EMAIL / PASSWORD =========================

  static Future<User?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e.code), code: e.code);
    } catch (e) {
      throw AuthException('Login failed. Please try again.');
    }
  }

  // BUG FIX: added 'name' parameter — was passing email as name before
  static Future<User?> signup(
      String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name.trim());
        // Pass actual name, not email
        await FirestoreService.createUserWithSelfMember(name.trim());
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e.code), code: e.code);
    } catch (e) {
      throw AuthException('Signup failed. Please try again.');
    }
  }

  static Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e.code), code: e.code);
    }
  }

  // ========================= GOOGLE SIGN-IN =========================

  static Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        final displayName = user.displayName ?? googleUser.displayName ?? 'User';
        await FirestoreService.createUserWithSelfMember(displayName);
      }

      // Securely store the Google token for session continuity
      if (googleAuth.idToken != null) {
        await _secureStorage.write(
            key: 'google_id_token', value: googleAuth.idToken);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthError(e.code), code: e.code);
    } catch (e) {
      throw AuthException('Google sign-in failed. Please try again.');
    }
  }

  // ========================= BIOMETRICS =========================

  static Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Verify your identity to access MediTrack',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ========================= SESSION =========================

  static User? getCurrentUser() => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _secureStorage.delete(key: 'google_id_token');
    await _auth.signOut();
  }

  // ========================= HELPERS =========================

  static String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
