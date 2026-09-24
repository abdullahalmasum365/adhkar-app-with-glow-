// ============================================================================
// lib/services/auth_service.dart
//
// Wraps Firebase Auth + Google Sign-In + Sign in with Apple behind a single
// service. Every method is defensive about Firebase not being configured
// yet (no google-services.json / GoogleService-Info.plist / firebase_options
// registered) — in that state, calls throw a clear AuthNotConfiguredException
// instead of crashing, so the rest of the app keeps working with local-only
// storage until the project owner finishes the Firebase Console setup.
// ============================================================================

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thrown when a Firebase-backed auth action is attempted before the
/// Firebase project has been configured for this app (missing
/// google-services.json / GoogleService-Info.plist).
class AuthNotConfiguredException implements Exception {
  final String message;
  AuthNotConfiguredException([
    this.message =
        'Firebase is not configured for this app yet. Account sign-in and '
        'cloud sync will work once the Firebase project is set up.',
  ]);
  @override
  String toString() => message;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  /// True once Firebase.initializeApp() has succeeded (checked lazily —
  /// main.dart calls it once at startup and swallows failures so a missing
  /// config file never crashes the app before the first frame).
  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  User? get currentUser =>
      isFirebaseReady ? FirebaseAuth.instance.currentUser : null;

  Stream<User?> get authStateChanges {
    if (!isFirebaseReady) return const Stream<User?>.empty();
    return FirebaseAuth.instance.authStateChanges();
  }

  Future<User?> signInWithGoogle() async {
    if (!isFirebaseReady) throw AuthNotConfiguredException();
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled the picker
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    return result.user;
  }

  Future<User?> signInWithApple() async {
    if (!isFirebaseReady) throw AuthNotConfiguredException();
    // On Android (and any non-Apple platform), Sign in with Apple only
    // works through a web OAuth redirect (`webAuthenticationOptions`),
    // which needs a Services ID + return URL configured in the Apple
    // Developer Program — not set up yet. Without this guard, the
    // underlying plugin throws a raw ArgumentError that looks like a
    // crash to the user. Native (no extra setup) only works on iOS/macOS.
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw AuthNotConfiguredException(
        'Apple Sign-In needs additional setup that isn\'t finished yet on '
        'Android. Please use Google for now.',
      );
    }
    final rawNonce = _generateNonce();
    final nonceSha256 = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonceSha256,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final result =
        await FirebaseAuth.instance.signInWithCredential(oauthCredential);

    // Apple only returns the user's name on the FIRST authorization ever —
    // Firebase doesn't capture it automatically, so store it ourselves.
    final givenName = appleCredential.givenName;
    final familyName = appleCredential.familyName;
    if ((givenName != null || familyName != null) &&
        (result.user?.displayName == null ||
            result.user!.displayName!.isEmpty)) {
      final fullName = [givenName, familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (fullName.isNotEmpty) {
        await result.user?.updateDisplayName(fullName);
      }
    }

    return result.user;
  }

  Future<void> signOut() async {
    if (!isFirebaseReady) return;
    await Future.wait([
      FirebaseAuth.instance.signOut(),
      _googleSignIn.signOut().catchError((_) => null),
    ]);
  }

  Future<void> deleteAccount() async {
    if (!isFirebaseReady) throw AuthNotConfiguredException();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // 1. Delete Firestore user records
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plan')
          .doc('data')
          .delete();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();
    } catch (_) {
      // Proceed even if Firestore fails or collection doesn't exist
    }

    // 2. Delete the Firebase Auth user
    await user.delete();

    // 3. Clean up Google / Apple sign in session
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Cryptographically random nonce for the Apple Sign-In replay-attack
  /// mitigation Firebase requires (raw nonce sent to Apple, its SHA-256
  /// hash sent alongside the ID token for verification).
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
