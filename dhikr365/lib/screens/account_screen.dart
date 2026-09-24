// ============================================================================
// lib/screens/account_screen.dart
//
// "Account & Sync" — sign in with Google or Apple so the user's custom dua
// plan / favorites list is saved to their account and restored automatically
// on every login, on any device. Signed-out state explains the benefit and
// offers the two sign-in buttons; signed-in state shows the profile and a
// sign-out action. Nothing here is required — the app fully works without
// an account, purely from local storage, exactly as before.
// ============================================================================

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/custom_plan_provider.dart';
import '../providers/language_provider.dart';
import '../utils/responsive.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final ap = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: AppDeco.radialBg(center: Alignment.topLeft),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: R.px(16)),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(lp.getText('account_title'),
                      textAlign: TextAlign.center, style: AppText.heading(20)),
                ),
                const SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                physics: const BouncingScrollPhysics(),
                children: [
                  ap.isSignedIn
                      ? _SignedInCard(ap: ap, lp: lp)
                      : _SignedOutCard(ap: ap, lp: lp),
                  const SizedBox(height: 24),
                  _BenefitsCard(lp: lp),
                  if (!ap.isFirebaseReady) ...[
                    const SizedBox(height: 20),
                    _NotConfiguredNotice(lp: lp),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SignedOutCard extends StatelessWidget {
  final AuthProvider ap;
  final LanguageProvider lp;
  const _SignedOutCard({required this.ap, required this.lp});

  Future<void> _handleSignIn(
      BuildContext context, Future<bool> Function() action) async {
    final cp = Provider.of<CustomPlanProvider>(context, listen: false);
    final ok = await action();
    if (!context.mounted) return;
    if (ok) {
      await cp.attachUser(ap.user?.uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lp.getText('account_signed_in_toast')),
          backgroundColor: Colors.green,
        ),
      );
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
    return Container(
      decoration: AppDeco.glassCard(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_outline_rounded,
              size: 32, color: AppColors.primary),
        ),
        const SizedBox(height: 14),
        Text(lp.getText('account_signed_out_title'),
            textAlign: TextAlign.center, style: AppText.heading(16)),
        const SizedBox(height: 6),
        Text(lp.getText('account_signed_out_body'),
            textAlign: TextAlign.center,
            style: AppText.body(color: AppColors.textSlate400)
                .copyWith(height: 1.5)),
        const SizedBox(height: 20),
        _ProviderButton(
          label: lp.getText('account_continue_google'),
          icon: Icons.g_mobiledata_rounded,
          background: Colors.white,
          foreground: Colors.black87,
          loading: ap.isLoading,
          onTap: () => _handleSignIn(context, ap.signInWithGoogle),
        ),
        if (Platform.isIOS || Platform.isMacOS) ...[
          const SizedBox(height: 12),
          _ProviderButton(
            label: lp.getText('account_continue_apple'),
            icon: Icons.apple_rounded,
            background: Colors.black,
            foreground: Colors.white,
            loading: ap.isLoading,
            onTap: () => _handleSignIn(context, ap.signInWithApple),
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
      ]),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  final AuthProvider ap;
  final LanguageProvider lp;
  const _SignedInCard({required this.ap, required this.lp});

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lp.getText('account_sign_out'), style: AppText.heading(18)),
        content: Text(lp.getText('account_sign_out_confirm'),
            style: AppText.body(color: AppColors.textSlate300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lp.getText('cancel'),
                style: AppText.body(color: AppColors.textSlate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lp.getText('account_sign_out'),
                style: AppText.body(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) await ap.signOut();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lp.getText('account_delete'),
            style: AppText.heading(18).copyWith(color: Colors.redAccent)),
        content: Text(lp.getText('account_delete_confirm'),
            style: AppText.body(color: AppColors.textSlate300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lp.getText('cancel'),
                style: AppText.body(color: AppColors.textSlate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lp.getText('account_delete_btn'),
                style: AppText.body(color: Colors.redAccent)
                    .copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final success = await ap.deleteAccount();
      if (!context.mounted) return;
      if (success) {
        final cp = Provider.of<CustomPlanProvider>(context, listen: false);
        await cp.attachUser(null);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lp.getText('account_deleted_toast')),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (ap.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ap.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ap.user?.email ?? '';
    final photoUrl = ap.user?.photoURL;
    final name = ap.displayName.isNotEmpty ? ap.displayName : email;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: AppDeco.glassCard(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              image: (photoUrl != null && photoUrl.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(photoUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Center(
                    child: Text(initials,
                        style: AppText.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.manrope(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                if (email.isNotEmpty && email != name)
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(color: AppColors.textSlate400)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_done_rounded,
                      size: 14, color: Colors.greenAccent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(lp.getText('account_sync_active'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(color: Colors.greenAccent)
                            .copyWith(fontSize: 11.5)),
                  ),
                ]),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _confirmSignOut(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(lp.getText('account_sign_out'),
                  style: AppText.manrope(
                      fontWeight: FontWeight.w700, color: Colors.redAccent)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _confirmDeleteAccount(context),
          icon: Icon(Icons.delete_forever_rounded,
              size: 16, color: AppColors.textSlate500),
          label: Text(
            lp.getText('account_delete'),
            style: AppText.body(color: AppColors.textSlate500).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  final LanguageProvider lp;
  const _BenefitsCard({required this.lp});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.favorite_rounded, lp.getText('account_benefit_1')),
      (Icons.sync_rounded, lp.getText('account_benefit_2')),
      (Icons.phone_iphone_rounded, lp.getText('account_benefit_3')),
    ];
    return Container(
      decoration: AppDeco.glassCard(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(item.$1, size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.$2,
                      style: AppText.body(color: AppColors.textSlate300)
                          .copyWith(height: 1.4)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _NotConfiguredNotice extends StatelessWidget {
  final LanguageProvider lp;
  const _NotConfiguredNotice({required this.lp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            size: 18, color: Colors.amberAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(lp.getText('account_not_configured'),
              style: AppText.body(color: Colors.amberAccent)
                  .copyWith(fontSize: 12, height: 1.4)),
        ),
      ]),
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
      height: 50,
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
