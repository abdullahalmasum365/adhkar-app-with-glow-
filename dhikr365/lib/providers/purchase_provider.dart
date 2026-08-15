// ============================================================================
// lib/providers/purchase_provider.dart
//
// Loads the real Play Store subscription products (with each user's local
// currency price, not a hardcoded "$3") and drives the purchase flow for
// DonationScreen. Fully optional-safe: if Play Billing isn't available yet
// (products not configured in Play Console, or running before the app is
// on Play Console at all) `products` stays empty and the screen shows a
// clear "not available yet" state instead of crashing or showing fake prices.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/purchase_service.dart';

class PurchaseProvider extends ChangeNotifier {
  final PurchaseService _service = PurchaseService();

  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _lastError;
  Map<String, ProductDetails> _products = {};
  String? _activeSubscriptionId;

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  String? get lastError => _lastError;
  Map<String, ProductDetails> get products => _products;
  String? get activeSubscriptionId => _activeSubscriptionId;
  bool get hasActiveSubscription => _activeSubscriptionId != null;

  PurchaseProvider() {
    _init();
  }

  Future<void> _init() async {
    _service.listen(_onPurchaseUpdate);

    _isAvailable = await _service.isAvailable;
    if (!_isAvailable) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final response =
          await _service.queryProducts(DonationProductIds.all);
      _products = {for (final p in response.productDetails) p.id: p};
    } catch (e) {
      _lastError = 'Could not load donation options right now.';
      debugPrint('[PurchaseProvider] queryProducts failed: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> buy(String productId) async {
    final product = _products[productId];
    if (product == null) return;
    _isPurchasing = true;
    _lastError = null;
    notifyListeners();
    try {
      await _service.buySubscription(product);
      // Result arrives asynchronously via the purchase stream — see
      // _onPurchaseUpdate, which clears _isPurchasing when it lands.
    } catch (e) {
      _isPurchasing = false;
      _lastError = 'Purchase failed. Please try again.';
      debugPrint('[PurchaseProvider] buy failed: $e');
      notifyListeners();
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _activeSubscriptionId = purchase.productID;
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
  }

  Future<void> restorePurchases() => _service.restorePurchases();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
