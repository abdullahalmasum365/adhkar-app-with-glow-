// ============================================================================
// lib/utils/first_launch_navigation.dart
//
// Routes a brand-new user into the app for the very first time, inserting
// the skippable WelcomeSignInScreen before Dashboard exactly once ever.
// Every screen that used to `pushAndRemoveUntil(... DashboardScreen())` at
// the end of first-run setup (onboarding, location setup) now calls
// `enterAppForFirstTime()` instead so the prompt is never missed and never
// repeated on later cold starts (SplashScreen's returning-user path goes
// straight to Dashboard and never touches this file).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/dashboard_screen.dart';
import '../screens/welcome_signin_screen.dart';

const _signInPromptShownKey = 'signin_prompt_shown';

Future<void> markSignInPromptShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_signInPromptShownKey, true);
}

/// Clears the whole setup stack and enters the app — showing the one-time
/// sign-in prompt first if it hasn't been shown yet, otherwise Dashboard.
Future<void> enterAppForFirstTime(BuildContext context) async {
  final nav = Navigator.of(context);
  final prefs = await SharedPreferences.getInstance();
  final alreadyShown = prefs.getBool(_signInPromptShownKey) ?? false;

  nav.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) =>
          alreadyShown ? const DashboardScreen() : const WelcomeSignInScreen(),
    ),
    (_) => false,
  );
}
