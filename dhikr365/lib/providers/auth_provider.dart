// ============================================================================
// lib/providers/auth_provider.dart
//
// Thin state layer over AuthService: exposes the signed-in Firebase user (or
// null) to the widget tree, plus loading/error state for the Account screen.
// Mirrors the `loadFuture` pattern used by UserProvider/LanguageProvider so
// SplashScreen can await it the same way.
// ============================================================================

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSub;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isFirebaseReady => _authService.isFirebaseReady;

  String get displayName {
    final name = _user?.displayName;
    if (name != null && name.isNotEmpty) return name;
    final email = _user?.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return '';
  }

  final _loadCompleter = Completer<void>();
  Future<void> get loadFuture => _loadCompleter.future;

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = _authService.currentUser;
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    _authSub = _authService.authStateChanges.listen((u) {
      _user = u;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final u = await _authService.signInWithGoogle();
      _user = u ?? _user;
      return u != null;
    } on AuthNotConfiguredException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Sign-in failed. Please try again.';
      debugPrint('[AuthProvider] Google sign-in failed: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithApple() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final u = await _authService.signInWithApple();
      _user = u ?? _user;
      return u != null;
    } on AuthNotConfiguredException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Sign-in failed. Please try again.';
      debugPrint('[AuthProvider] Apple sign-in failed: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } finally {
      _user = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
