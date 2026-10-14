// ============================================================================
// lib/providers/purchase_provider.dart
//
// Manages Google Play In-App Purchases for voluntary Sadaqah Jariyah
// subscriptions with active synchronization, receipt verification, and
// cancellation/expiration enforcement.
//
// All app features are 100% free and unlocked for everyone.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/purchase_service.dart';
import '../services/purchase_verification_service.dart';

class PurchaseProvider extends ChangeNotifier {
  static const String _prefKeyActiveDonation = 'active_donation_id';
  static const String _prefKeyDonationExpiry = 'donation_expiry_ms';
  static const String _prefKeyLastVerified = 'last_verified_timestamp_ms';

  // Legacy keys for migration / cleanup
  static const String _legacyPrefKeyHasLifetimePro = 'has_lifetime_pro';
  static const String _legacyPrefKeyActiveProTier = 'active_pro_tier_id';
  static const String _legacyPrefKeyProExpiry = 'pro_expiry_ms';
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

  String? _activeDonationId;
  DateTime? _donationExpiry;
  DateTime? _lastVerified;

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

  /// Backward-compatibility getters
  bool get hasActiveSubscription => hasActiveDonation;
  String? get activeSubscriptionId => activeDonationId;
  DateTime? get subscriptionExpiry => _donationExpiry;
  DateTime? get lastVerified => _lastVerified;

  final Duration _syncTimeout;

  PurchaseProvider({
    PurchaseService? service,
    PurchaseVerificationService? verificationService,
    Duration syncTimeout = const Duration(milliseconds: 3500),
    bool autoInit = true,
  })  : _service = service ?? PurchaseService(),
        _verificationService =
            verificationService ?? PurchaseVerificationService(),
        _syncTimeout = syncTimeout {
    _service.listen(_onPurchaseUpdate);
    if (autoInit) {
      _init();
    }
  }

  /// Loads cached entitlements from SharedPreferences. Offline users retain access.
  /// Automatically checks and purges expired subscriptions.
  Future<void> loadCachedEntitlements() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clean up legacy Pro keys from earlier versions
      await prefs.remove(_legacyPrefKeyHasLifetimePro);
      await prefs.remove(_legacyPrefKeyActiveProTier);
      await prefs.remove(_legacyPrefKeyProExpiry);

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
        if (DonationProductIds.isDonationProduct(legacySubId)) {
          _activeDonationId ??= legacySubId;
          if (legacyExpiryMs != null) {
            _donationExpiry ??= DateTime.fromMillisecondsSinceEpoch(legacyExpiryMs);
          }
        }
        await prefs.remove(_legacyPrefKeyActiveSub);
        await prefs.remove(_legacyPrefKeySubExpiry);
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

    // 2. Check Play Billing availability
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
      _lastError = 'Could not load sponsorship options right now.';
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
    _isAvailable = await _service.isAvailable;
    if (!_isAvailable) {
      debugPrint('[PurchaseProvider] Cannot sync: Play Billing unavailable or offline.');
      return;
    }

    _isSyncing = true;
    _restoredProductIds.clear();
    _syncCompleter = Completer<void>();
    bool streamResponded = false;

    try {
      await _service.restorePurchases();

      // Wait for stream callback or healthy timeout
      await _syncCompleter!.future.timeout(
        _syncTimeout,
        onTimeout: () {
          debugPrint('[PurchaseProvider] syncPurchases stream wait completed/timed out.');
        },
      );
      streamResponded = _syncCompleter!.isCompleted;
    } catch (e) {
      debugPrint('[PurchaseProvider] syncPurchases restore exception: $e');
    }

    // Offline-First & Network Latency Guard:
    if (!streamResponded) {
      debugPrint('[PurchaseProvider] Preserving cached entitlement state due to network/stream timeout.');
      _isSyncing = false;
      _syncCompleter = null;
      notifyListeners();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

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
              if (DonationProductIds.isDonationProduct(purchase.productID)) {
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
    _activeDonationId = null;
    _donationExpiry = null;
    _lastVerified = null;
    _restoredProductIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyPrefKeyHasLifetimePro);
      await prefs.remove(_legacyPrefKeyActiveProTier);
      await prefs.remove(_legacyPrefKeyProExpiry);
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


  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
