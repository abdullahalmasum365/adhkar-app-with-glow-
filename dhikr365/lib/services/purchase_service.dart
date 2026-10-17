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

/// Subscription product IDs for voluntary app maintenance support.
/// Must exist as subscription base plans in Play Console.
class DonationProductIds {
  // Monthly & Annual App Maintenance Subscriptions (Starting at $2.99/mo)
  static const maintenanceMonthly = 'app_maintenance_monthly'; // $2.99 / month (Base)
  static const maintenancePatronMonthly = 'app_maintenance_patron_monthly'; // $5.99 / month (Generous)
  static const maintenanceAnnual = 'app_maintenance_annual'; // $29.99 / year (Best value)

  // Legacy / alternative product IDs (for Play Console compatibility)
  static const seed = 'donation_seed_monthly';
  static const supporter = 'donation_supporter_monthly';
  static const patron = 'donation_patron_monthly';
  static const annual = 'donation_annual_sponsor';

  static const maintenanceTiers = {
    maintenanceMonthly,
    maintenancePatronMonthly,
    maintenanceAnnual,
  };

  static const legacyTiers = {
    seed,
    supporter,
    patron,
    annual,
  };

  static const donationTiers = {
    ...maintenanceTiers,
    ...legacyTiers,
  };

  static const subscriptionTiers = donationTiers;
  static const all = donationTiers;

  static bool isDonationProduct(String id) => donationTiers.contains(id);
  static bool isSubscription(String id) => subscriptionTiers.contains(id);
}

class PurchaseService {
  final InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  PurchaseService({InAppPurchase? iap}) : _iap = iap;

  InAppPurchase get _instance => _iap ?? InAppPurchase.instance;

  Future<bool> get isAvailable => _instance.isAvailable();

  /// Starts listening for purchase updates. Call once at app startup.
  /// [onUpdate] is invoked with each purchase update batch — the caller
  /// (PurchaseProvider) is responsible for completing pending purchases.
  void listen(void Function(List<PurchaseDetails>) onUpdate) {
    _subscription?.cancel();
    _subscription = _instance.purchaseStream.listen(
      onUpdate,
      onError: (_) {},
    );
  }

  Future<ProductDetailsResponse> queryProducts(Set<String> ids) {
    return _instance.queryProductDetails(ids);
  }

  Future<bool> buyProduct(ProductDetails product, {bool isConsumable = false}) {
    final purchaseParam = PurchaseParam(productDetails: product);
    if (isConsumable) {
      return _instance.buyConsumable(purchaseParam: purchaseParam);
    }
    return _instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<bool> buySubscription(ProductDetails product) {
    return buyProduct(product, isConsumable: false);
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _instance.completePurchase(purchase);
  }

  Future<void> restorePurchases() {
    return _instance.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
