import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dhikr365/constants/app_theme.dart';
import 'package:dhikr365/providers/purchase_provider.dart';
import 'package:dhikr365/providers/theme_provider.dart';
import 'package:dhikr365/services/purchase_service.dart';
import 'package:dhikr365/services/purchase_verification_service.dart';

class FakePurchaseService extends Fake implements PurchaseService {
  @override
  Future<bool> get isAvailable async => true;

  @override
  void listen(void Function(List<PurchaseDetails>) onData) {}

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  void dispose() {}
}

class FakeInAppPurchase extends Fake implements InAppPurchase {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async => true,
    );
    PurchaseService.setMock(FakePurchaseService());
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      null,
    );
    PurchaseService.setMock(null);
  });

  group('Purchase Verification & Entitlement Provider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PurchaseService.setMock(FakePurchaseService());
    });

    test('1. Product ID Classification: Pro Plans vs Donations', () {
      expect(
          DonationProductIds.isLifetimePro(DonationProductIds.proLifetime), isTrue);
      expect(
          DonationProductIds.isProSubscription(DonationProductIds.pro1Month), isTrue);
      expect(
          DonationProductIds.isProSubscription(DonationProductIds.pro6Months), isTrue);
      expect(
          DonationProductIds.isProSubscription(DonationProductIds.pro1Year), isTrue);
      expect(
          DonationProductIds.isProProduct(DonationProductIds.pro1Year), isTrue);

      expect(DonationProductIds.isDonationProduct(DonationProductIds.seed), isTrue);
      expect(
          DonationProductIds.isDonationProduct(DonationProductIds.supporter), isTrue);
      expect(
          DonationProductIds.isDonationProduct(DonationProductIds.patron), isTrue);
      expect(
          DonationProductIds.isDonationProduct(DonationProductIds.annual), isTrue);

      expect(DonationProductIds.isProProduct(DonationProductIds.seed), isFalse);
      expect(DonationProductIds.isDonationProduct(DonationProductIds.pro1Month), isFalse);
    });

    test('2. Receipt Token Inspection: Local token analysis', () {
      final service = PurchaseVerificationService();

      final validPurchase = PurchaseDetails(
        productID: DonationProductIds.pro1Year,
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
      expect(record.isLifetime, isFalse);
      expect(record.isSubscription, isTrue);
      expect(record.purchaseToken, equals('server_signed_token_123'));
    });

    test('3. PurchaseProvider Initial Free State: Defaults to no active donation and isPro is true', () async {
      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      expect(provider.isPro, isTrue);
      expect(provider.hasLifetimePro, isFalse);
      expect(provider.hasActiveProSubscription, isFalse);
      expect(provider.activeProTierId, isNull);
      expect(provider.hasActiveDonation, isFalse);
      expect(provider.activeDonationId, isNull);
    });

    test('4. Pro 1 Month, 6 Months, and 1 Year Subscriptions: Grant Pro with proper expiry', () async {
      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      // Test 1 Year purchase
      final pro1YPurchase = PurchaseDetails(
        productID: DonationProductIds.pro1Year,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local_token_1y',
          serverVerificationData: 'server_token_1y',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
      );

      await provider.handlePurchaseUpdatesForTesting([pro1YPurchase]);

      expect(provider.isPro, isTrue);
      expect(provider.hasActiveProSubscription, isTrue);
      expect(provider.activeProTierId, equals(DonationProductIds.pro1Year));
      expect(provider.proExpiry, isNotNull);
      expect(provider.proExpiry!.isAfter(DateTime.now().add(const Duration(days: 350))), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_pro_tier_id'), equals(DonationProductIds.pro1Year));
      expect(prefs.getInt('pro_expiry_ms'), isNotNull);
    });

    test('5. Sadaqah Jariyah Donation activates donation state independently', () async {
      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      final donationPurchase = PurchaseDetails(
        productID: DonationProductIds.supporter,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local_token_sub',
          serverVerificationData: 'server_token_sub',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
      );

      await provider.handlePurchaseUpdatesForTesting([donationPurchase]);

      expect(provider.hasActiveDonation, isTrue);
      expect(provider.activeDonationId, equals(DonationProductIds.supporter));
      expect(provider.isPro, isTrue);
      expect(provider.hasActiveProSubscription, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_donation_id'), equals(DonationProductIds.supporter));
      expect(prefs.getString('active_pro_tier_id'), isNull);
    });

    test('6. Pro User Can Also Donate: Maintains BOTH Pro status and active donation', () async {
      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      // First, user subscribes to Pro (1 Month)
      final proPurchase = PurchaseDetails(
        productID: DonationProductIds.pro1Month,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'token_pro',
          serverVerificationData: 'token_pro',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
      );
      await provider.handlePurchaseUpdatesForTesting([proPurchase]);
      expect(provider.isPro, isTrue);

      // Second, Pro user also donates (Patron tier)
      final donationPurchase = PurchaseDetails(
        productID: DonationProductIds.patron,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'token_patron',
          serverVerificationData: 'token_patron',
          source: 'google_play',
        ),
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
      );
      await provider.handlePurchaseUpdatesForTesting([donationPurchase]);

      // Both must remain active simultaneously!
      expect(provider.isPro, isTrue);
      expect(provider.hasActiveProSubscription, isTrue);
      expect(provider.activeProTierId, equals(DonationProductIds.pro1Month));
      expect(provider.hasActiveDonation, isTrue);
      expect(provider.activeDonationId, equals(DonationProductIds.patron));
    });

    test('7. Expiration of Pro subscription revokes tier while maintaining active donation', () async {
      final expiredMs = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;
      final futureExpiry = DateTime.now()
          .add(const Duration(days: 20))
          .millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        'active_pro_tier_id': DonationProductIds.pro1Month,
        'pro_expiry_ms': expiredMs,
        'active_donation_id': DonationProductIds.seed,
        'donation_expiry_ms': futureExpiry,
      });

      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      expect(provider.isPro, isTrue);
      expect(provider.hasActiveProSubscription, isFalse);
      expect(provider.activeProTierId, isNull);

      // Donation still active
      expect(provider.hasActiveDonation, isTrue);
      expect(provider.activeDonationId, equals(DonationProductIds.seed));
    });

    test('8. Explicit Revocation (clearSubscription): Purges all stored entitlements', () async {
      SharedPreferences.setMockInitialValues({
        'has_lifetime_pro': true,
        'active_pro_tier_id': DonationProductIds.pro1Year,
        'pro_expiry_ms': DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch,
        'active_donation_id': DonationProductIds.annual,
        'donation_expiry_ms': DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch,
      });

      final provider = PurchaseProvider(autoInit: false);
      await provider.loadCachedEntitlements();

      expect(provider.isPro, isTrue);
      expect(provider.hasActiveDonation, isTrue);

      // Trigger revocation
      await provider.clearSubscription();

      expect(provider.hasLifetimePro, isFalse);
      expect(provider.isPro, isTrue);
      expect(provider.hasActiveDonation, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_lifetime_pro'), isNull);
      expect(prefs.getString('active_pro_tier_id'), isNull);
      expect(prefs.getString('active_donation_id'), isNull);
    });

    test('9. ThemeProvider: All palettes selectable and retained for everyone', () async {
      SharedPreferences.setMockInitialValues({});
      final themeProvider = ThemeProvider();
      await themeProvider.initialized;

      // User chooses midnightAmoled palette
      await themeProvider.updateAuthAndPro('test_user', false, isPurchaseLoaded: true);
      await themeProvider.setPalette(AppPalettes.midnightAmoled.id);
      expect(themeProvider.palette.id, equals(AppPalettes.midnightAmoled.id));
      expect(themeProvider.palette.isPro, isFalse);
    });

    test('10. Authoritative Play Store Sync: Correctly revokes canceled products', () async {
      final provider = PurchaseProvider(autoInit: false);

      final proPurchase = PurchaseDetails(
        productID: DonationProductIds.pro6Months,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'token',
          serverVerificationData: 'token',
          source: 'google_play',
        ),
        transactionDate: '123',
        status: PurchaseStatus.purchased,
      );
      await provider.handlePurchaseUpdatesForTesting([proPurchase]);
      expect(provider.hasActiveProSubscription, isTrue);

      // Authoritative Google Play sync returns empty (product was refunded or cancelled)
      await provider.executeSyncWithRestoredIdsForTesting({});

      expect(provider.isPro, isTrue);
      expect(provider.hasActiveProSubscription, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_pro_tier_id'), isNull);
    });
  });
}
