import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dhikr365/services/purchase_service.dart';
import 'package:dhikr365/services/purchase_verification_service.dart';
import 'package:dhikr365/providers/purchase_provider.dart';
import 'package:dhikr365/providers/theme_provider.dart';
import 'package:dhikr365/constants/app_theme.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class FakePurchaseService implements PurchaseService {
  @override
  Future<bool> get isAvailable async => true;

  @override
  void listen(void Function(List<PurchaseDetails>) onUpdate) {}

  @override
  Future<ProductDetailsResponse> queryProducts(Set<String> ids) async {
    return ProductDetailsResponse(productDetails: [], notFoundIDs: []);
  }

  @override
  Future<bool> buyProduct(ProductDetails product, {bool isConsumable = false}) async => true;

  @override
  Future<bool> buySubscription(ProductDetails product) async => true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'),
            (MethodCall methodCall) async {
      return true;
    });
  });

  tearDownAll(() {
    PurchaseService.setMock(null);
  });

  group('Purchase Verification & Entitlement Provider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PurchaseService.setMock(FakePurchaseService());
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

    test('2. Receipt Token Inspection: Local token analysis', () {
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

    test('3. PurchaseProvider Initial Free State: Defaults to non-Pro', () async {
      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      expect(provider.isPro, isFalse);
      expect(provider.hasLifetimePro, isFalse);
      expect(provider.hasActiveSubscription, isFalse);
      expect(provider.activeSubscriptionId, isNull);
    });

    test('4. Lifetime Pro Entitlement: Granted and persisted to storage', () async {
      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      final proPurchase = PurchaseDetails(
        productID: DonationProductIds.proLifetime,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local_token_pro',
          serverVerificationData: 'server_token_pro',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
      );

      await provider.handlePurchaseUpdatesForTesting([proPurchase]);

      expect(provider.hasLifetimePro, isTrue);
      expect(provider.isPro, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_lifetime_pro'), isTrue);
    });

    test('5. Subscription Entitlement & Duration Calculation', () async {
      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      final subPurchase = PurchaseDetails(
        productID: DonationProductIds.supporter,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local_token_sub',
          serverVerificationData: 'server_token_sub',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
      );

      await provider.handlePurchaseUpdatesForTesting([subPurchase]);

      expect(provider.hasActiveSubscription, isTrue);
      expect(provider.activeSubscriptionId, equals(DonationProductIds.supporter));
      expect(provider.isPro, isTrue);
      expect(provider.subscriptionExpiry, isNotNull);
      expect(provider.subscriptionExpiry!.isAfter(DateTime.now()), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_subscription_id'),
          equals(DonationProductIds.supporter));
      expect(prefs.getInt('subscription_expiry_ms'), isNotNull);
    });

    test('6. Subscription Expiration: Expired sub is automatically revoked', () async {
      // Setup expired subscription timestamp (1 day in the past)
      final expiredMs = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        'active_subscription_id': DonationProductIds.supporter,
        'subscription_expiry_ms': expiredMs,
      });

      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      // Expired subscription should NOT grant active status or Pro
      expect(provider.hasActiveSubscription, isFalse);
      expect(provider.activeSubscriptionId, isNull);
      expect(provider.isPro, isFalse);

      // Verify that expired keys were purged from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_subscription_id'), isNull);
      expect(prefs.getInt('subscription_expiry_ms'), isNull);
    });

    test('7. Explicit Revocation (clearSubscription): Purges all entitlements', () async {
      SharedPreferences.setMockInitialValues({
        'has_lifetime_pro': true,
        'active_subscription_id': DonationProductIds.annual,
        'subscription_expiry_ms': DateTime.now()
            .add(const Duration(days: 365))
            .millisecondsSinceEpoch,
      });

      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      expect(provider.isPro, isTrue);

      // Trigger revocation
      await provider.clearSubscription();

      expect(provider.hasLifetimePro, isFalse);
      expect(provider.hasActiveSubscription, isFalse);
      expect(provider.isPro, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_lifetime_pro'), isNull);
      expect(prefs.getString('active_subscription_id'), isNull);
      expect(prefs.getInt('subscription_expiry_ms'), isNull);
    });

    test('8. Authoritative Play Store Sync: Revokes on refund or cancellation', () async {
      final provider = PurchaseProvider(autoInit: false);

      // Simulate previously owned Lifetime Pro
      final proPurchase = PurchaseDetails(
        productID: DonationProductIds.proLifetime,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'token',
          serverVerificationData: 'token',
          source: 'google_play',
        ),
        transactionDate: '123',
        status: PurchaseStatus.purchased,
      );
      await provider.handlePurchaseUpdatesForTesting([proPurchase]);
      expect(provider.isPro, isTrue);

      // Authoritative Google Play sync returns empty (product was refunded or cancelled)
      await provider.executeSyncWithRestoredIdsForTesting({});

      expect(provider.hasLifetimePro, isFalse);
      expect(provider.isPro, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_lifetime_pro'), isNull);
    });

    test('9. ThemeProvider Revocation Reaction: Pro theme auto-reverts to default', () async {
      SharedPreferences.setMockInitialValues({});
      final themeProvider = ThemeProvider();
      await themeProvider.initialized;

      // Pro user chooses a Pro palette
      await themeProvider.updateAuthAndPro('test_user', true, isPurchaseLoaded: true);
      await themeProvider.setPalette(AppPalettes.midnightAmoled.id);
      expect(themeProvider.palette.id, equals(AppPalettes.midnightAmoled.id));

      // Entitlement is revoked: isPro becomes false
      await themeProvider.updateAuthAndPro('test_user', false, isPurchaseLoaded: true);

      // ThemeProvider must immediately auto-revert to the free default emeraldNight palette
      expect(themeProvider.palette.id, equals(AppPalettes.emeraldNight.id));
      expect(themeProvider.palette.isPro, isFalse);
    });

    test('10. Offline Entitlement Retention: Valid unexpired access is preserved', () async {
      final validFutureExpiry = DateTime.now()
          .add(const Duration(days: 20))
          .millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        'active_subscription_id': DonationProductIds.patron,
        'subscription_expiry_ms': validFutureExpiry,
      });

      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      expect(provider.hasActiveSubscription, isTrue);
      expect(provider.activeSubscriptionId, equals(DonationProductIds.patron));
      expect(provider.isPro, isTrue);
    });
  });
}
