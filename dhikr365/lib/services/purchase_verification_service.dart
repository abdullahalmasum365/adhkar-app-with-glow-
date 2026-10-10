// ============================================================================
// lib/services/purchase_verification_service.dart
//
// Checks purchase status and token presence from Google Play Billing.
//
// Note:
//   The authoritative source of truth is Google Play Billing (via
//   restorePurchases and the live purchase update stream). On device,
//   we inspect that Google Play returned a valid status and non-empty token.
// ============================================================================

import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_service.dart';

class VerifiedPurchaseRecord {
  final String productId;
  final String? orderId;
  final String? purchaseToken;
  final DateTime? transactionDate;
  final bool isLifetime;
  final bool isSubscription;
  final bool isValid;

  const VerifiedPurchaseRecord({
    required this.productId,
    this.orderId,
    this.purchaseToken,
    this.transactionDate,
    required this.isLifetime,
    required this.isSubscription,
    required this.isValid,
  });
}

/// Inspects purchase status and token presence from Google Play receipts on device.
class PurchaseVerificationService {
  static final PurchaseVerificationService _instance =
      PurchaseVerificationService._internal();
  factory PurchaseVerificationService() => _instance;
  PurchaseVerificationService._internal();

  /// Inspects a purchase returned by Google Play Billing to ensure it has
  /// a valid status (purchased/restored) and a non-empty purchase token.
  VerifiedPurchaseRecord verifyLocalReceipt(PurchaseDetails purchase) {
    final productId = purchase.productID;
    final isLifetime = DonationProductIds.isLifetimePro(productId);
    final isSub = DonationProductIds.isSubscription(productId);

    // Verify valid status from Google Play
    final hasValidStatus = purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored;

    // Verify that Google Play returned a non-empty verification token
    final serverData = purchase.verificationData.serverVerificationData;
    final hasValidToken = serverData.isNotEmpty;

    DateTime? txDate;
    if (purchase.transactionDate != null) {
      final millis = int.tryParse(purchase.transactionDate!);
      if (millis != null) {
        txDate = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    final isValid = hasValidStatus && hasValidToken;

    return VerifiedPurchaseRecord(
      productId: productId,
      orderId: purchase.purchaseID,
      purchaseToken: serverData,
      transactionDate: txDate,
      isLifetime: isLifetime,
      isSubscription: isSub,
      isValid: isValid,
    );
  }
}
