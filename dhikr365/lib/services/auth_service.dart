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
import 'package:flutter/foundation.dart';
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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '622768800935-dg8l5jsa6jlek9btv94hqt7veg93bpo7.apps.googleusercontent.com',
    scopes: ['email'],
  );

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
    // Clear any stale cached credentials
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled the picker
    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null && googleAuth.accessToken == null) {
      throw Exception('Could not retrieve tokens from Google Sign-In.');
    }
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

  /// Prompts the user to re-authenticate with their active provider (Google or Apple)
  /// so that sensitive operations (like account deletion) possess fresh credentials
  /// and don't fail midway with a `requires-recent-login` error.
  Future<void> reauthenticate() async {
    if (!isFirebaseReady) throw AuthNotConfiguredException();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user currently signed in.');

    final providerIds = user.providerData.map((p) => p.providerId).toList();
    if (providerIds.contains('google.com')) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'canceled',
          message: 'Re-authentication was canceled.',
        );
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Could not retrieve tokens from Google Sign-In.');
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else if (providerIds.contains('apple.com')) {
      if (!Platform.isIOS && !Platform.isMacOS) {
        throw AuthNotConfiguredException(
          'Apple Sign-In is only supported on Apple platforms.',
        );
      }
      try {
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
        await user.reauthenticateWithCredential(oauthCredential);
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
          throw FirebaseAuthException(
            code: 'canceled',
            message: 'Re-authentication was canceled.',
          );
        }
        rethrow;
      }
    }
  }

  Future<void> deleteAccount() async {
    if (!isFirebaseReady) throw AuthNotConfiguredException();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // 1. Re-authenticate first to guarantee valid/fresh credentials
    //    and prevent leaving orphaned or half-deleted states if re-auth fails or is canceled.
    await reauthenticate();

    // 2. Permanently purge all Firestore user records across all subcollections:
    //    - Settings data (users/{uid}/settings/theme, users/{uid}/settings/language)
    //    - Custom plan data (users/{uid}/plan/data)
    //    - Progress & streak data (users/{uid}/progress/data)
    //    - Root profile document (users/{uid})
    final db = FirebaseFirestore.instance.collection('users').doc(uid);
    final batch = FirebaseFirestore.instance.batch();

    // Explicitly delete known subcollection documents
    batch.delete(db.collection('settings').doc('theme'));
    batch.delete(db.collection('settings').doc('language'));
    batch.delete(db.collection('plan').doc('data'));
    batch.delete(db.collection('progress').doc('data'));

    // Dynamically query and delete any remaining documents across known subcollections
    // to guarantee 100% compliance with permanent data purge policy
    try {
      final subcollections = ['settings', 'plan', 'progress'];
      for (final sub in subcollections) {
        final querySnap = await db.collection(sub).get();
        for (final doc in querySnap.docs) {
          batch.delete(doc.reference);
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Subcollection query cleanup notice: $e');
    }

    // Delete root user document
    batch.delete(db);
    await batch.commit();
    debugPrint('[AuthService] Successfully purged all Firestore data for user $uid');

    // 3. Delete the Firebase Auth user account
    await user.delete();

    // 4. Clean up Google / Apple sign in session
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Inspects the root Firestore user doc `users/{uid}`. If it contains
  /// deprecated client-written entitlement fields (`isPro`, `latestPurchase`,
  /// `hasLifetimePro`, `activeSubscriptionId`, `lastPurchaseSync`) from earlier builds,
  /// deletes the root document so future writes comply with hardened Firestore rules.
  Future<bool> cleanLegacyUserDocIfPresent(String uid) async {
    if (!isFirebaseReady) return false;
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await docRef.get();
      if (snap.exists) {
        final data = snap.data();
        if (data != null &&
            (data.containsKey('isPro') ||
             data.containsKey('latestPurchase') ||
             data.containsKey('hasLifetimePro') ||
             data.containsKey('activeSubscriptionId') ||
             data.containsKey('lastPurchaseSync'))) {
          debugPrint('[AuthService] Found legacy entitlement fields in root doc $uid. Deleting document...');
          await docRef.delete();
          debugPrint('[AuthService] Successfully deleted legacy root doc $uid.');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Legacy user doc check notice: $e');
    }
    return false;
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
