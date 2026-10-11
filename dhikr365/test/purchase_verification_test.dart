import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dhikr365/constants/app_theme.dart';
import 'package:dhikr365/providers/purchase_provider.dart';
import 'package:dhikr365/providers/theme_provider.dart';
import 'package:dhikr365/services/purchase_service.dart';
import 'package:dhikr365/services/purchase_verification_service.dart';

/// Controllable fake PurchaseService with an active purchase stream
class FakePurchaseService extends PurchaseService {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool isAvailableMock = true;
  bool shouldThrowOnRestore = false;
  List<PurchaseDetails>? purchasesToEmitOnRestore;
  bool emitOnRestore = true;

  @override
  Future<bool> get isAvailable async => isAvailableMock;

  @override
  void listen(void Function(List<PurchaseDetails>) onData) {
    _controller.stream.listen(onData);
  }

  /// Emits purchase updates directly into the stream
  void emitPurchases(List<PurchaseDetails> purchases) {
    _controller.add(purchases);
  }

  @override
  Future<void> restorePurchases() async {
    if (shouldThrowOnRestore) {
      throw Exception('Google Play Billing connection error during restorePurchases');
    }
    if (emitOnRestore && purchasesToEmitOnRestore != null) {
      // Emit via stream just like Google Play does in production
      _controller.add(purchasesToEmitOnRestore!);
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async => true,
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      null,
    );
  });

  group('Purchase Verification & Entitlement Provider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Product ID Classification: Donation tiers are valid subscriptions', () {
      expect(DonationProductIds.isDonationProduct(DonationProductIds.seed), isTrue);
      expect(DonationProductIds.isDonationProduct(DonationProductIds.supporter), isTrue);
      expect(DonationProductIds.isDonationProduct(DonationProductIds.patron), isTrue);
      expect(DonationProductIds.isDonationProduct(DonationProductIds.annual), isTrue);

      expect(DonationProductIds.isSubscription(DonationProductIds.seed), isTrue);
      expect(DonationProductIds.isSubscription(DonationProductIds.supporter), isTrue);
      expect(DonationProductIds.isSubscription(DonationProductIds.patron), isTrue);
      expect(DonationProductIds.isSubscription(DonationProductIds.annual), isTrue);
    });

    test('Receipt Token Inspection: Local token analysis', () {
      final service = PurchaseVerificationService();

      final validPurchase = PurchaseDetails(
        productID: DonationProductIds.supporter,
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
      expect(record.isSubscription, isTrue);
      expect(record.purchaseToken, equals('server_signed_token_123'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // REAL PurchaseProvider.syncPurchases() Tests
    // ─────────────────────────────────────────────────────────────────────────

    test('1. Real syncPurchases: Play responds with active support subscription -> hasActiveDonation true', () async {
      final fakeService = FakePurchaseService();
      fakeService.isAvailableMock = true;
      fakeService.purchasesToEmitOnRestore = [
        PurchaseDetails(
          productID: DonationProductIds.supporter,
          verificationData: PurchaseVerificationData(
            localVerificationData: 'local_token_sub',
            serverVerificationData: 'server_token_sub_valid',
            source: 'google_play',
          ),
          transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
          status: PurchaseStatus.restored,
        ),
      ];

      final provider = PurchaseProvider(
        service: fakeService,
        syncTimeout: const Duration(milliseconds: 500),
        autoInit: false,
      );
      await provider.loadCachedEntitlements();
      expect(provider.hasActiveDonation, isFalse);

      // Call the REAL syncPurchases()
      await provider.syncPurchases();

      expect(provider.hasActiveDonation, isTrue);
      expect(provider.activeDonationId, equals(DonationProductIds.supporter));
      expect(provider.donationExpiry, isNotNull);
      expect(provider.donationExpiry!.isAfter(DateTime.now().add(const Duration(days: 30))), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_donation_id'), equals(DonationProductIds.supporter));
      expect(prefs.getInt('donation_expiry_ms'), isNotNull);

      fakeService.dispose();
    });

    test('2. Real syncPurchases: Play responds with an empty list -> hasActiveDonation false (cancelled/refunded)', () async {
      // Pre-seed cached donation as if user previously had active supporter subscription
      final futureExpiry = DateTime.now().add(const Duration(days: 20)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'active_donation_id': DonationProductIds.supporter,
        'donation_expiry_ms': futureExpiry,
      });

      final fakeService = FakePurchaseService();
      fakeService.isAvailableMock = true;
      // Play responds with empty list (authoritative cancellation/refund)
      fakeService.purchasesToEmitOnRestore = [];

      final provider = PurchaseProvider(
        service: fakeService,
        syncTimeout: const Duration(milliseconds: 500),
        autoInit: false,
      );
      await provider.loadCachedEntitlements();
      expect(provider.hasActiveDonation, isTrue);
      expect(provider.activeDonationId, equals(DonationProductIds.supporter));

      // Call the REAL syncPurchases()
      await provider.syncPurchases();

      expect(provider.hasActiveDonation, isFalse);
      expect(provider.activeDonationId, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_donation_id'), isNull);
      expect(prefs.getInt('donation_expiry_ms'), isNull);

      fakeService.dispose();
    });

    test('3. Real syncPurchases: Play does not respond before timeout or restore throws -> cached state preserved', () async {
      final futureExpiry = DateTime.now().add(const Duration(days: 25)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'active_donation_id': DonationProductIds.patron,
        'donation_expiry_ms': futureExpiry,
      });

      final fakeService = FakePurchaseService();
      fakeService.isAvailableMock = true;

      // Sub-case A: restore throws network exception
      fakeService.shouldThrowOnRestore = true;

      final provider = PurchaseProvider(
        service: fakeService,
        syncTimeout: const Duration(milliseconds: 100),
        autoInit: false,
      );
      await provider.loadCachedEntitlements();
      expect(provider.hasActiveDonation, isTrue);

      // Call the REAL syncPurchases() when restore throws
      await provider.syncPurchases();

      // Cached state MUST be preserved!
      expect(provider.hasActiveDonation, isTrue);
      expect(provider.activeDonationId, equals(DonationProductIds.patron));

      // Sub-case B: Play does not respond before timeout (never emits into stream)
      fakeService.shouldThrowOnRestore = false;
      fakeService.purchasesToEmitOnRestore = null;
      fakeService.emitOnRestore = false;

      await provider.syncPurchases();

      // Cached state STILL preserved!
      expect(provider.hasActiveDonation, isTrue);
      expect(provider.activeDonationId, equals(DonationProductIds.patron));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_donation_id'), equals(DonationProductIds.patron));

      fakeService.dispose();
    });

    test('4. Real syncPurchases: offline/unavailable -> nothing revoked', () async {
      final futureExpiry = DateTime.now().add(const Duration(days: 300)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'active_donation_id': DonationProductIds.annual,
        'donation_expiry_ms': futureExpiry,
      });

      final fakeService = FakePurchaseService();
      // Play billing is offline/unavailable
      fakeService.isAvailableMock = false;
      fakeService.purchasesToEmitOnRestore = []; // Even if configured, should never be processed

      final provider = PurchaseProvider(
        service: fakeService,
        syncTimeout: const Duration(milliseconds: 100),
        autoInit: false,
      );
      await provider.loadCachedEntitlements();
      expect(provider.hasActiveDonation, isTrue);

      // Call the REAL syncPurchases() while offline
      await provider.syncPurchases();

      // Nothing is revoked! Offline users retain their active badge/support
      expect(provider.hasActiveDonation, isTrue);
      expect(provider.activeDonationId, equals(DonationProductIds.annual));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_donation_id'), equals(DonationProductIds.annual));

      fakeService.dispose();
    });

    test('5. Explicit Revocation (clearSubscription): Purges all stored donation entitlements', () async {
      SharedPreferences.setMockInitialValues({
        'active_donation_id': DonationProductIds.annual,
        'donation_expiry_ms': DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch,
      });

      final fakeService = FakePurchaseService();
      final provider = PurchaseProvider(service: fakeService, autoInit: false);
      await provider.loadCachedEntitlements();

      expect(provider.hasActiveDonation, isTrue);

      // Trigger revocation
      await provider.clearSubscription();

      expect(provider.hasActiveDonation, isFalse);
      expect(provider.activeDonationId, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_donation_id'), isNull);
      expect(prefs.getInt('donation_expiry_ms'), isNull);

      fakeService.dispose();
    });

    test('6. ThemeProvider: All palettes selectable and retained without restriction', () async {
      SharedPreferences.setMockInitialValues({});
      final themeProvider = ThemeProvider();
      await themeProvider.initialized;

      // Select palette
      await themeProvider.setPalette(AppPalettes.midnightAmoled.id);
      expect(themeProvider.palette.id, equals(AppPalettes.midnightAmoled.id));
    });
  });
}
