// ============================================================================
// lib/providers/purchase_provider.dart
//
// Manages Google Play In-App Purchases, Lifetime Pro entitlements, and
// recurring Sadaqah Jariyah subscriptions with active synchronization,
// receipt verification, and cancellation/expiration enforcement.
//
// Key Protections:
//   1. Distinguishes Lifetime Pro (non-consumable) from recurring subscriptions.
//   2. Startup synchronization via restorePurchases() with Google Play authority.
//   3. Clears local cache when subscriptions expire or are refunded/canceled.
//   4. Authoritative Source: Entitlements verified via Google Play restore & purchase stream.
//   5. Strictly guards debug test overrides with kDebugMode.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/purchase_service.dart';
import '../services/purchase_verification_service.dart';

class PurchaseProvider extends ChangeNotifier {
  static const String _prefKeyActiveSub = 'active_subscription_id';
  static const String _prefKeyHasLifetimePro = 'has_lifetime_pro';
  static const String _prefKeySubExpiry = 'subscription_expiry_ms';
  static const String _prefKeyLastVerified = 'last_verified_timestamp_ms';

  final PurchaseService _service = PurchaseService();
  final PurchaseVerificationService _verificationService =
      PurchaseVerificationService();

  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isSyncing = false;
  bool _isLoaded = false;
  String? _lastError;
  Map<String, ProductDetails> _products = {};

  bool _hasLifetimePro = false;
  String? _activeSubscriptionId;
  DateTime? _subscriptionExpiry;
  DateTime? _lastVerified;

  bool _isDebugOverride = false;
  final Set<String> _restoredProductIds = {};
  Completer<void>? _syncCompleter;

  // ── Public Getters ─────────────────────────────────────────────────────────

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  bool get isSyncing => _isSyncing;
  bool get isLoaded => _isLoaded;
  String? get lastError => _lastError;
  Map<String, ProductDetails> get products => _products;

  /// Returns true if user holds verified Lifetime Pro.
  bool get hasLifetimePro => _hasLifetimePro;

  /// Returns active recurring subscription ID if not expired.
  String? get activeSubscriptionId {
    if (_activeSubscriptionId == null) return null;
    if (_subscriptionExpiry != null &&
        DateTime.now().isAfter(_subscriptionExpiry!)) {
      return null;
    }
    return _activeSubscriptionId;
  }

  /// Returns true if user has an active, unexpired subscription.
  bool get hasActiveSubscription {
    if (_activeSubscriptionId == null) return false;
    if (_subscriptionExpiry != null &&
        DateTime.now().isAfter(_subscriptionExpiry!)) {
      return false;
    }
    return true;
  }

  /// Pro status is granted if user owns Lifetime Pro OR holds an active subscription.
  bool get isPro => _hasLifetimePro || hasActiveSubscription;

  DateTime? get subscriptionExpiry => _subscriptionExpiry;
  DateTime? get lastVerified => _lastVerified;

  // ── Initialization ─────────────────────────────────────────────────────────

  PurchaseProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Load cached entitlement so offline users retain access while traveling
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasLifetimePro = prefs.getBool(_prefKeyHasLifetimePro) ?? false;
      _activeSubscriptionId = prefs.getString(_prefKeyActiveSub);

      final expiryMs = prefs.getInt(_prefKeySubExpiry);
      if (expiryMs != null) {
        _subscriptionExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      }

      final verifiedMs = prefs.getInt(_prefKeyLastVerified);
      if (verifiedMs != null) {
        _lastVerified = DateTime.fromMillisecondsSinceEpoch(verifiedMs);
      }

      // Check if cached subscription has already passed its expiry timestamp
      if (_subscriptionExpiry != null &&
          DateTime.now().isAfter(_subscriptionExpiry!)) {
        debugPrint('[PurchaseProvider] Cached subscription has expired.');
        _activeSubscriptionId = null;
        await prefs.remove(_prefKeyActiveSub);
        await prefs.remove(_prefKeySubExpiry);
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[PurchaseProvider] load cached state error: $e');
      _isLoaded = true;
      notifyListeners();
    }

    // 2. Start listening to Play Billing purchase events
    _service.listen(_onPurchaseUpdate);

    _isAvailable = await _service.isAvailable;
    if (!_isAvailable) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 3. Query Play Store product details
    try {
      final response =
          await _service.queryProducts(DonationProductIds.all);
      _products = {for (final p in response.productDetails) p.id: p};
    } catch (e) {
      _lastError = 'Could not load donation options right now.';
      debugPrint('[PurchaseProvider] queryProducts failed: $e');
    }

    // 4. Authoritative startup synchronization with Google Play Store
    await syncPurchases();

    _isLoading = false;
    notifyListeners();
  }

  // ── Purchase Synchronization & Verification ───────────────────────────────

  /// Synchronizes active purchases with Google Play Store authority.
  /// If Google Play returns an authoritative response omitting subscriptions, local cache is purged.
  /// Network timeouts or offline states PRESERVE existing cached entitlements.
  Future<void> syncPurchases() async {
    if (!_isAvailable) return;
    if (kDebugMode && _isDebugOverride) return;

    _isSyncing = true;
    _restoredProductIds.clear();
    _syncCompleter = Completer<void>();
    bool streamResponded = false;

    try {
      await _service.restorePurchases();

      // Wait for stream callback or healthy timeout (up to 3500ms)
      await _syncCompleter!.future.timeout(
        const Duration(milliseconds: 3500),
        onTimeout: () {
          debugPrint('[PurchaseProvider] syncPurchases stream wait completed/timed out.');
        },
      );
      streamResponded = _syncCompleter!.isCompleted;
    } catch (e) {
      debugPrint('[PurchaseProvider] syncPurchases restore exception: $e');
    }

    if (kDebugMode && _isDebugOverride) {
      _isSyncing = false;
      _syncCompleter = null;
      return;
    }

    // Offline-First & Network Latency Guard:
    // If Play Store stream timed out or was unreachable (offline / airplane mode / slow network),
    // NEVER revoke already-verified Lifetime Pro or active subscription entitlements!
    if (!streamResponded) {
      debugPrint('[PurchaseProvider] Preserving cached entitlement state due to network/stream timeout.');
      _isSyncing = false;
      _syncCompleter = null;
      notifyListeners();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Lifetime Pro Verification ──────────────────────────────────────────
      if (_restoredProductIds.contains(DonationProductIds.proLifetime)) {
        _hasLifetimePro = true;
        await prefs.setBool(_prefKeyHasLifetimePro, true);
      } else if (_hasLifetimePro) {
        // Authoritative response from Google Play explicitly omitting lifetime product
        // -> Refunded or revoked by Google Play
        debugPrint('[PurchaseProvider] Authoritative Google Play response: Lifetime Pro revoked/refunded. Clearing.');
        _hasLifetimePro = false;
        await prefs.remove(_prefKeyHasLifetimePro);
      }

      // ── Subscription Verification ──────────────────────────────────────────
      final activeSub = _restoredProductIds.firstWhere(
        (id) => DonationProductIds.subscriptionTiers.contains(id),
        orElse: () => '',
      );

      if (activeSub.isNotEmpty) {
        _activeSubscriptionId = activeSub;
        await prefs.setString(_prefKeyActiveSub, activeSub);
      } else if (_activeSubscriptionId != null) {
        // Authoritative response from Google Play: no active subscription
        debugPrint('[PurchaseProvider] Authoritative Google Play response: Subscription expired or canceled. Clearing.');
        _activeSubscriptionId = null;
        _subscriptionExpiry = null;
        await prefs.remove(_prefKeyActiveSub);
        await prefs.remove(_prefKeySubExpiry);
      }

      _lastVerified = DateTime.now();
      await prefs.setInt(
          _prefKeyLastVerified, _lastVerified!.millisecondsSinceEpoch);

      notifyListeners();
    } catch (e) {
      debugPrint('[PurchaseProvider] syncPurchases error: $e');
    } finally {
      _isSyncing = false;
      _syncCompleter = null;
    }
  }

  // ── Purchase Flow ──────────────────────────────────────────────────────────

  Future<void> buy(String productId) async {
    final product = _products[productId];
    if (product == null) return;
    _isPurchasing = true;
    _lastError = null;
    notifyListeners();
    try {
      final isSub = DonationProductIds.isSubscription(productId);
      if (isSub) {
        await _service.buySubscription(product);
      } else {
        await _service.buyProduct(product, isConsumable: false);
      }
    } catch (e) {
      _isPurchasing = false;
      _lastError = 'Purchase failed. Please try again.';
      debugPrint('[PurchaseProvider] buy failed: $e');
      notifyListeners();
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    final prefs = await SharedPreferences.getInstance();

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (DonationProductIds.all.contains(purchase.productID)) {
            _restoredProductIds.add(purchase.productID);

            // Inspect purchase status and verification token from Google Play
            final record =
                _verificationService.verifyLocalReceipt(purchase);

            if (record.isValid) {
              if (DonationProductIds.isLifetimePro(purchase.productID)) {
                _hasLifetimePro = true;
                await prefs.setBool(_prefKeyHasLifetimePro, true);
              } else if (DonationProductIds.isSubscription(purchase.productID)) {
                _activeSubscriptionId = purchase.productID;
                await prefs.setString(_prefKeyActiveSub, _activeSubscriptionId!);

                // Estimate billing period expiry based on product duration
                final now = DateTime.now();
                if (purchase.productID == DonationProductIds.annual) {
                  _subscriptionExpiry = now.add(const Duration(days: 370));
                } else {
                  _subscriptionExpiry = now.add(const Duration(days: 33));
                }
                await prefs.setInt(_prefKeySubExpiry,
                    _subscriptionExpiry!.millisecondsSinceEpoch);
              }

              _lastVerified = DateTime.now();
              await prefs.setInt(
                  _prefKeyLastVerified, _lastVerified!.millisecondsSinceEpoch);
            }
          }

          if (purchase.pendingCompletePurchase) {
            await _service.completePurchase(purchase);
          }
          _isPurchasing = false;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _isPurchasing = false;
          _lastError = purchase.error?.message ?? 'Purchase failed.';
          if (purchase.pendingCompletePurchase) {
            await _service.completePurchase(purchase);
          }
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          _isPurchasing = false;
          notifyListeners();
          break;
      }
    }

    // Complete sync completer if waiting
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      _syncCompleter!.complete();
    }
  }

  Future<void> restorePurchases() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await syncPurchases();
    } catch (e) {
      _lastError = 'Could not restore purchases.';
      debugPrint('[PurchaseProvider] restore failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearSubscription() async {
    _activeSubscriptionId = null;
    _hasLifetimePro = false;
    _subscriptionExpiry = null;
    _restoredProductIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyActiveSub);
      await prefs.remove(_prefKeyHasLifetimePro);
      await prefs.remove(_prefKeySubExpiry);
      await prefs.remove(_prefKeyLastVerified);
    } catch (e) {
      debugPrint('[PurchaseProvider] clearSubscription error: $e');
    }
    notifyListeners();
  }

  /// Toggle Pro status for developer testing / QA without real payment (Debug only)
  Future<void> toggleProForTesting() async {
    assert(kDebugMode, 'toggleProForTesting must never be called in release builds');
    if (!kDebugMode) return;
    _isDebugOverride = true;
    final prefs = await SharedPreferences.getInstance();
    if (isPro) {
      _hasLifetimePro = false;
      _activeSubscriptionId = null;
      await prefs.remove(_prefKeyHasLifetimePro);
      await prefs.remove(_prefKeyActiveSub);
    } else {
      _hasLifetimePro = true;
      await prefs.setBool(_prefKeyHasLifetimePro, true);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
