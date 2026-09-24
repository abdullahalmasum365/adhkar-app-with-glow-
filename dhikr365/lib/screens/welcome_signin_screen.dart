// ============================================================================
// lib/screens/welcome_signin_screen.dart
//
// Shown exactly ONCE — right before the very first entry into Dashboard —
// offering Google/Apple sign-in so favorites/custom plan sync across
// devices. Always skippable: the app is fully usable without an account,
// exactly like before this feature existed. Never shown again after this
// (see utils/first_launch_navigation.dart), but reachable any time later
// from Settings → Account & Sync.
// ============================================================================

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/custom_plan_provider.dart';
import '../providers/language_provider.dart';
import 'dashboard_screen.dart';
import '../utils/first_launch_navigation.dart';

class WelcomeSignInScreen extends StatelessWidget {
  const WelcomeSignInScreen({super.key});

  Future<void> _enterDashboard(BuildContext context) async {
    await markSignInPromptShown();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (_) => false,
    );
  }

  Future<void> _handleSignIn(
    BuildContext context,
    AuthProvider ap,
    Future<bool> Function() action,
  ) async {
    final cp = Provider.of<CustomPlanProvider>(context, listen: false);
    final ok = await action();
    if (!context.mounted) return;
    if (ok) {
      await cp.attachUser(ap.user?.uid);
      if (!context.mounted) return;
      await _enterDashboard(context);
    } else if (ap.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ap.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final ap = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: AppDeco.radialBg(center: Alignment.topCenter, radius: 1.6),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.cloud_sync_rounded,
                      size: 42, color: AppColors.primary),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.85, 0.85), delay: 150.ms),
                const SizedBox(height: 24),
                Text(
                  lp.getText('welcome_signin_title'),
                  textAlign: TextAlign.center,
                  style: AppText.heading(24),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 12),
                Text(
                  lp.getText('welcome_signin_body'),
                  textAlign: TextAlign.center,
                  style: AppText.body(color: AppColors.textSlate400)
                      .copyWith(height: 1.6, fontSize: 15),
                ).animate().fadeIn(delay: 350.ms),
                const Spacer(),
                _ProviderButton(
                  label: lp.getText('account_continue_google'),
                  icon: Icons.g_mobiledata_rounded,
                  background: Colors.white,
                  foreground: Colors.black87,
                  loading: ap.isLoading,
                  onTap: () => _handleSignIn(context, ap, ap.signInWithGoogle),
                ),
                if (Platform.isIOS || Platform.isMacOS) ...[
                  const SizedBox(height: 12),
                  _ProviderButton(
                    label: lp.getText('account_continue_apple'),
                    icon: Icons.apple_rounded,
                    background: Colors.black,
                    foreground: Colors.white,
                    loading: ap.isLoading,
                    onTap: () => _handleSignIn(context, ap, ap.signInWithApple),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      lp.getText('terms_consent_prefix'),
                      style: AppText.body(color: AppColors.textSlate400).copyWith(fontSize: 11),
                    ),
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('https://abdullahalmasum365.github.io/adhkar-app-with-glow-/terms-of-service.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        lp.getText('terms_of_service'),
                        style: AppText.body(color: AppColors.primary).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      lp.getText('terms_consent_and'),
                      style: AppText.body(color: AppColors.textSlate400).copyWith(fontSize: 11),
                    ),
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('https://abdullahalmasum365.github.io/adhkar-app-with-glow-/privacy-policy.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        lp.getText('privacy_policy'),
                        style: AppText.body(color: AppColors.primary).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: ap.isLoading ? null : () => _enterDashboard(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      lp.getText('continue_without_account'),
                      style: AppText.body(color: AppColors.textSlate400)
                          .copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool loading;
  final VoidCallback onTap;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: foreground),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: 8),
                  Text(label,
                      style: AppText.manrope(fontWeight: FontWeight.w700)
                          .copyWith(color: foreground)),
                ]),
              ),
      ),
    );
  }
}
