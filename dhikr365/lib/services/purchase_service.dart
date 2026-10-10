// ============================================================================
// lib/services/purchase_service.dart
//
// Wraps Google Play Billing (via in_app_purchase) for the donation
// subscriptions. Product IDs here MUST exist as subscription base plans in
// Play Console — this file only talks to whatever Google returns; it never
// invents a price or charges anything itself. Until the app is uploaded to
// Play Console with these products configured, queryProductDetails() simply
// returns an empty list (notFoundIDs contains everything) — DonationScreen
// handles that gracefully rather than crashing.
// ============================================================================

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Subscription product IDs — must be created as subscription base plans
/// with these exact IDs in Play Console → Monetize → Products → Subscriptions.
class DonationProductIds {
  // Pro Subscription Plans (1 Month, 6 Months, 1 Year)
  static const pro1Month = 'adhkar365_pro_1m';
  static const pro6Months = 'adhkar365_pro_6m';
  static const pro1Year = 'adhkar365_pro_1y';
  // Legacy Lifetime Pro (supported for past purchasers)
  static const proLifetime = 'adhkar365_pro_lifetime';

  // Sadaqah Jariyah products (Monthly & Annual Auto-Renewing Subscriptions)
  static const seed = 'donation_seed_monthly';
  static const supporter = 'donation_supporter_monthly';
  static const patron = 'donation_patron_monthly';
  static const annual = 'donation_annual_sponsor';

  static const proSubscriptionTiers = {pro1Month, pro6Months, pro1Year};
  static const proProducts = {pro1Month, pro6Months, pro1Year, proLifetime};
  static const donationTiers = {seed, supporter, patron, annual};

  static const subscriptionTiers = {
    pro1Month,
    pro6Months,
    pro1Year,
    seed,
    supporter,
    patron,
    annual,
  };

  static const all = {
    pro1Month,
    pro6Months,
    pro1Year,
    proLifetime,
    seed,
    supporter,
    patron,
    annual,
  };

  static bool isLifetimePro(String id) => id == proLifetime;
  static bool isProSubscription(String id) => proSubscriptionTiers.contains(id);
  static bool isProProduct(String id) => proProducts.contains(id);
  static bool isDonationProduct(String id) => donationTiers.contains(id);
  static bool isSubscription(String id) => subscriptionTiers.contains(id);
}

class PurchaseService {
  static PurchaseService? _mockInstance;
  static PurchaseService? _instance;

  static void setMock(PurchaseService? mock) => _mockInstance = mock;

  factory PurchaseService({InAppPurchase? iap}) {
    if (_mockInstance != null) {
      return _mockInstance!;
    }
    if (iap != null) {
      return PurchaseService._internal(iap: iap);
    }
    return _instance ??= PurchaseService._internal();
  }
  PurchaseService._internal({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<bool> get isAvailable => _iap.isAvailable();

  /// Starts listening for purchase updates. Call once at app startup.
  /// [onUpdate] is invoked with each purchase update batch — the caller
  /// (PurchaseProvider) is responsible for completing pending purchases.
  void listen(void Function(List<PurchaseDetails>) onUpdate) {
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      onUpdate,
      onError: (_) {},
    );
  }

  Future<ProductDetailsResponse> queryProducts(Set<String> ids) {
    return _iap.queryProductDetails(ids);
  }

  Future<bool> buyProduct(ProductDetails product, {bool isConsumable = false}) {
    final purchaseParam = PurchaseParam(productDetails: product);
    if (isConsumable) {
      return _iap.buyConsumable(purchaseParam: purchaseParam);
    }
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<bool> buySubscription(ProductDetails product) {
    return buyProduct(product, isConsumable: false);
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _iap.completePurchase(purchase);
  }

  Future<void> restorePurchases() {
    return _iap.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
