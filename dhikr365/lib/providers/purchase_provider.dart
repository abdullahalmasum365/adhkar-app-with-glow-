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
  static const String _prefKeyHasLifetimePro = 'has_lifetime_pro';
  static const String _prefKeyActiveProTier = 'active_pro_tier_id';
  static const String _prefKeyProExpiry = 'pro_expiry_ms';
  static const String _prefKeyActiveDonation = 'active_donation_id';
  static const String _prefKeyDonationExpiry = 'donation_expiry_ms';
  static const String _prefKeyLastVerified = 'last_verified_timestamp_ms';

  // Legacy keys for migration
  static const String _legacyPrefKeyActiveSub = 'active_subscription_id';
  static const String _legacyPrefKeySubExpiry = 'subscription_expiry_ms';

  final PurchaseService _service;
  final PurchaseVerificationService _verificationService;

  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isSyncing = false;
  bool _isLoaded = false;
  String? _lastError;
  Map<String, ProductDetails> _products = {};

  bool _hasLifetimePro = false;
  String? _activeProTierId;
  DateTime? _proExpiry;
  String? _activeDonationId;
  DateTime? _donationExpiry;
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

  /// Returns true if user has an active, unexpired Pro subscription (1m, 6m, 1y).
  bool get hasActiveProSubscription {
    if (_activeProTierId == null) return false;
    if (_proExpiry != null && DateTime.now().isAfter(_proExpiry!)) {
      return false;
    }
    return true;
  }

  /// Returns active Pro subscription tier ID if not expired (e.g. adhkar365_pro_1m, 6m, 1y).
  String? get activeProTierId {
    if (!hasActiveProSubscription) return null;
    return _activeProTierId;
  }

  /// Expiration date of the Pro subscription.
  DateTime? get proExpiry => _proExpiry;

  /// Returns true if user has an active, unexpired Sadaqah Jariyah donation.
  bool get hasActiveDonation {
    if (_activeDonationId == null) return false;
    if (_donationExpiry != null && DateTime.now().isAfter(_donationExpiry!)) {
      return false;
    }
    return true;
  }

  /// Returns active donation subscription ID if not expired (e.g. donation_supporter_monthly).
  String? get activeDonationId {
    if (!hasActiveDonation) return null;
    return _activeDonationId;
  }

  /// Expiration / next renewal estimation date of donation subscription.
  DateTime? get donationExpiry => _donationExpiry;

  /// Pro status is granted ONLY if user owns Lifetime Pro OR holds an active Pro plan (1m, 6m, 1y).
  /// Pure donation does NOT grant or interfere with Pro status.
  bool get isPro => _hasLifetimePro || hasActiveProSubscription;

  /// Backward-compatibility getters
  bool get hasActiveSubscription => hasActiveProSubscription || hasActiveDonation;
  String? get activeSubscriptionId => activeProTierId ?? activeDonationId;
  DateTime? get subscriptionExpiry => _proExpiry ?? _donationExpiry;
  DateTime? get lastVerified => _lastVerified;

  // ── Initialization ─────────────────────────────────────────────────────────

  PurchaseProvider({
    PurchaseService? service,
    PurchaseVerificationService? verificationService,
    bool autoInit = true,
  })  : _service = service ?? PurchaseService(),
        _verificationService =
            verificationService ?? PurchaseVerificationService() {
    if (autoInit) {
      _init();
    }
  }

  /// Loads cached entitlements from SharedPreferences. Offline users retain access.
  /// Automatically checks and purges expired subscriptions.
  Future<void> loadCachedEntitlements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasLifetimePro = prefs.getBool(_prefKeyHasLifetimePro) ?? false;
      _activeProTierId = prefs.getString(_prefKeyActiveProTier);
      final proExpiryMs = prefs.getInt(_prefKeyProExpiry);
      if (proExpiryMs != null) {
        _proExpiry = DateTime.fromMillisecondsSinceEpoch(proExpiryMs);
      } else {
        _proExpiry = null;
      }

      _activeDonationId = prefs.getString(_prefKeyActiveDonation);
      final donationExpiryMs = prefs.getInt(_prefKeyDonationExpiry);
      if (donationExpiryMs != null) {
        _donationExpiry = DateTime.fromMillisecondsSinceEpoch(donationExpiryMs);
      } else {
        _donationExpiry = null;
      }

      // Legacy migration check:
      final legacySubId = prefs.getString(_legacyPrefKeyActiveSub);
      final legacyExpiryMs = prefs.getInt(_legacyPrefKeySubExpiry);
      if (legacySubId != null) {
        if (DonationProductIds.isProSubscription(legacySubId)) {
          _activeProTierId ??= legacySubId;
          if (legacyExpiryMs != null) {
            _proExpiry ??= DateTime.fromMillisecondsSinceEpoch(legacyExpiryMs);
          }
        } else if (DonationProductIds.isDonationProduct(legacySubId)) {
          _activeDonationId ??= legacySubId;
          if (legacyExpiryMs != null) {
            _donationExpiry ??= DateTime.fromMillisecondsSinceEpoch(legacyExpiryMs);
          }
        }
        await prefs.remove(_legacyPrefKeyActiveSub);
        await prefs.remove(_legacyPrefKeySubExpiry);
      }

      // Check if cached Pro subscription has already passed its expiry timestamp
      if (_proExpiry != null && DateTime.now().isAfter(_proExpiry!)) {
        debugPrint('[PurchaseProvider] Cached Pro subscription has expired.');
        _activeProTierId = null;
        await prefs.remove(_prefKeyActiveProTier);
        await prefs.remove(_prefKeyProExpiry);
      }

      // Check if cached Donation has already passed its expiry timestamp
      if (_donationExpiry != null && DateTime.now().isAfter(_donationExpiry!)) {
        debugPrint('[PurchaseProvider] Cached donation has expired.');
        _activeDonationId = null;
        await prefs.remove(_prefKeyActiveDonation);
        await prefs.remove(_prefKeyDonationExpiry);
      }

      final verifiedMs = prefs.getInt(_prefKeyLastVerified);
      if (verifiedMs != null) {
        _lastVerified = DateTime.fromMillisecondsSinceEpoch(verifiedMs);
      } else {
        _lastVerified = null;
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[PurchaseProvider] load cached state error: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _init() async {
    // 1. Load cached entitlement so offline users retain access while traveling
    await loadCachedEntitlements();

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

      // ── Pro Subscription Verification ──────────────────────────────────────
      final activeProSub = _restoredProductIds.firstWhere(
        (id) => DonationProductIds.isProSubscription(id),
        orElse: () => '',
      );

      if (activeProSub.isNotEmpty) {
        _activeProTierId = activeProSub;
        await prefs.setString(_prefKeyActiveProTier, activeProSub);
      } else if (_activeProTierId != null) {
        debugPrint('[PurchaseProvider] Authoritative Google Play response: Pro subscription expired or canceled. Clearing.');
        _activeProTierId = null;
        _proExpiry = null;
        await prefs.remove(_prefKeyActiveProTier);
        await prefs.remove(_prefKeyProExpiry);
      }

      // ── Donation Subscription Verification ──────────────────────────────────
      final activeDonationSub = _restoredProductIds.firstWhere(
        (id) => DonationProductIds.isDonationProduct(id),
        orElse: () => '',
      );

      if (activeDonationSub.isNotEmpty) {
        _activeDonationId = activeDonationSub;
        await prefs.setString(_prefKeyActiveDonation, activeDonationSub);
      } else if (_activeDonationId != null) {
        debugPrint('[PurchaseProvider] Authoritative Google Play response: Donation expired or canceled. Clearing.');
        _activeDonationId = null;
        _donationExpiry = null;
        await prefs.remove(_prefKeyActiveDonation);
        await prefs.remove(_prefKeyDonationExpiry);
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

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
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
              final now = DateTime.now();
              if (DonationProductIds.isLifetimePro(purchase.productID)) {
                _hasLifetimePro = true;
                await prefs.setBool(_prefKeyHasLifetimePro, true);
              } else if (DonationProductIds.isProSubscription(purchase.productID)) {
                _activeProTierId = purchase.productID;
                if (purchase.productID == DonationProductIds.pro1Year) {
                  _proExpiry = now.add(const Duration(days: 370));
                } else if (purchase.productID == DonationProductIds.pro6Months) {
                  _proExpiry = now.add(const Duration(days: 185));
                } else {
                  // pro1Month
                  _proExpiry = now.add(const Duration(days: 33));
                }
                await prefs.setString(_prefKeyActiveProTier, _activeProTierId!);
                await prefs.setInt(_prefKeyProExpiry,
                    _proExpiry!.millisecondsSinceEpoch);
              } else if (DonationProductIds.isDonationProduct(purchase.productID)) {
                // Independent Sadaqah Jariyah donation — does NOT grant Pro
                _activeDonationId = purchase.productID;
                if (purchase.productID == DonationProductIds.annual) {
                  _donationExpiry = now.add(const Duration(days: 370));
                } else {
                  _donationExpiry = now.add(const Duration(days: 33));
                }
                await prefs.setString(_prefKeyActiveDonation, _activeDonationId!);
                await prefs.setInt(_prefKeyDonationExpiry,
                    _donationExpiry!.millisecondsSinceEpoch);
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
    _hasLifetimePro = false;
    _activeProTierId = null;
    _proExpiry = null;
    _activeDonationId = null;
    _donationExpiry = null;
    _lastVerified = null;
    _restoredProductIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyHasLifetimePro);
      await prefs.remove(_prefKeyActiveProTier);
      await prefs.remove(_prefKeyProExpiry);
      await prefs.remove(_prefKeyActiveDonation);
      await prefs.remove(_prefKeyDonationExpiry);
      await prefs.remove(_prefKeyLastVerified);
      // Clean legacy keys
      await prefs.remove(_legacyPrefKeyActiveSub);
      await prefs.remove(_legacyPrefKeySubExpiry);
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
      _activeProTierId = null;
      _proExpiry = null;
      await prefs.remove(_prefKeyHasLifetimePro);
      await prefs.remove(_prefKeyActiveProTier);
      await prefs.remove(_prefKeyProExpiry);
    } else {
      _hasLifetimePro = true;
      await prefs.setBool(_prefKeyHasLifetimePro, true);
    }
    notifyListeners();
  }

  /// Test helper to feed simulated purchase events to PurchaseProvider.
  @visibleForTesting
  Future<void> handlePurchaseUpdatesForTesting(List<PurchaseDetails> purchases) =>
      _onPurchaseUpdate(purchases);

  /// Test helper to execute authoritative sync with a given set of restored product IDs.
  @visibleForTesting
  Future<void> executeSyncWithRestoredIdsForTesting(Set<String> restoredIds) async {
    _restoredProductIds.clear();
    _restoredProductIds.addAll(restoredIds);

    final prefs = await SharedPreferences.getInstance();

    if (_restoredProductIds.contains(DonationProductIds.proLifetime)) {
      _hasLifetimePro = true;
      await prefs.setBool(_prefKeyHasLifetimePro, true);
    } else if (_hasLifetimePro) {
      debugPrint('[PurchaseProvider] Authoritative Google Play response: Lifetime Pro revoked/refunded. Clearing.');
      _hasLifetimePro = false;
      await prefs.remove(_prefKeyHasLifetimePro);
    }

    final activeProSub = _restoredProductIds.firstWhere(
      (id) => DonationProductIds.isProSubscription(id),
      orElse: () => '',
    );

    if (activeProSub.isNotEmpty) {
      _activeProTierId = activeProSub;
      await prefs.setString(_prefKeyActiveProTier, activeProSub);
    } else if (_activeProTierId != null) {
      debugPrint('[PurchaseProvider] Authoritative Google Play response: Pro subscription expired or canceled. Clearing.');
      _activeProTierId = null;
      _proExpiry = null;
      await prefs.remove(_prefKeyActiveProTier);
      await prefs.remove(_prefKeyProExpiry);
    }

    final activeDonationSub = _restoredProductIds.firstWhere(
      (id) => DonationProductIds.isDonationProduct(id),
      orElse: () => '',
    );

    if (activeDonationSub.isNotEmpty) {
      _activeDonationId = activeDonationSub;
      await prefs.setString(_prefKeyActiveDonation, activeDonationSub);
    } else if (_activeDonationId != null) {
      debugPrint('[PurchaseProvider] Authoritative Google Play response: Donation expired or canceled. Clearing.');
      _activeDonationId = null;
      _donationExpiry = null;
      await prefs.remove(_prefKeyActiveDonation);
      await prefs.remove(_prefKeyDonationExpiry);
    }

    _lastVerified = DateTime.now();
    await prefs.setInt(
        _prefKeyLastVerified, _lastVerified!.millisecondsSinceEpoch);

    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
