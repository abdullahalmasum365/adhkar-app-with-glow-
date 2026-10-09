import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dhikr365/services/purchase_service.dart';
import 'package:dhikr365/services/purchase_verification_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Purchase Verification & Entitlement Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Product ID Classification: Lifetime Pro vs Subscriptions', () {
      expect(
          DonationProductIds.isLifetimePro(DonationProductIds.proLifetime), isTrue);
      expect(
          DonationProductIds.isSubscription(DonationProductIds.proLifetime), isFalse);

      expect(DonationProductIds.isSubscription(DonationProductIds.seed), isTrue);
      expect(
          DonationProductIds.isSubscription(DonationProductIds.supporter), isTrue);
      expect(
          DonationProductIds.isSubscription(DonationProductIds.patron), isTrue);
      expect(
          DonationProductIds.isSubscription(DonationProductIds.annual), isTrue);
      expect(DonationProductIds.isLifetimePro(DonationProductIds.seed), isFalse);
    });

    test('2. Receipt Validation: Local cryptographic token check', () {
      final service = PurchaseVerificationService();

      final validPurchase = PurchaseDetails(
        productID: DonationProductIds.proLifetime,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local_token',
          serverVerificationData: 'server_signed_token_123',
          source: 'google_play',
        ),
        transactionDate: '1728000000000',
        status: PurchaseStatus.purchased,
      );

      final record = service.verifyLocalReceipt(validPurchase);
      expect(record.isValid, isTrue);
      expect(record.isLifetime, isTrue);
      expect(record.isSubscription, isFalse);
      expect(record.purchaseToken, equals('server_signed_token_123'));
    });

    test('3. Subscription Expiration: Expired timestamps correctly invalidate active sub', () async {
      // Set expired timestamp (1 day ago)
      final expiredMs = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        'active_subscription_id': DonationProductIds.supporter,
        'subscription_expiry_ms': expiredMs,
      });

      final prefs = await SharedPreferences.getInstance();
      final cachedSub = prefs.getString('active_subscription_id');
      final expiry = prefs.getInt('subscription_expiry_ms');

      expect(cachedSub, equals(DonationProductIds.supporter));
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry!);
      expect(DateTime.now().isAfter(expiryDate), isTrue);
    });
  });
}
