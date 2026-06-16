// ============================================================================
// lib/services/location_service.dart
// Handles the full location setup flow without requiring GPS.
// ============================================================================

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// ── Result types ─────────────────────────────────────────────────────────────

/// Coordinates returned by any lookup method.
class LocationCoords {
  final double lat;
  final double lng;
  const LocationCoords(this.lat, this.lng);
}

/// Result of the GPS attempt — includes a flag so callers know whether to
/// prompt the user for manual city entry.
class GpsResult {
  /// Non-null when GPS succeeded.
  final LocationCoords? coords;

  /// True when the user has tapped "Deny" or "Deny & don't ask again".
  /// The caller should show the manual-entry UI in this case.
  final bool needsManualEntry;

  /// Human-readable reason for failure, or null on success.
  final String? failureReason;

  const GpsResult._({
    this.coords,
    required this.needsManualEntry,
    this.failureReason,
  });

  bool get succeeded => coords != null;

  // Convenience constructors
  factory GpsResult.success(double lat, double lng) => GpsResult._(
        coords:           LocationCoords(lat, lng),
        needsManualEntry: false,
      );

  factory GpsResult.permissionDenied({bool forever = false}) => GpsResult._(
        needsManualEntry: true,
        failureReason: forever
            ? 'Location permission permanently denied. '
              'Enable it in device Settings to use GPS.'
            : 'Location permission denied.',
      );

  factory GpsResult.gpsFailed(String reason) => GpsResult._(
        needsManualEntry: true,
        failureReason:    reason,
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class LocationService {
  // Singleton so callers don't need to manage instances.
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // ── Mecca default ──────────────────────────────────────────────────────────

  static const double meccaLat     = 21.3891;
  static const double meccaLng     = 39.8579;
  static const String meccaCity    = 'Mecca';
  static const String meccaCountry = 'Saudi Arabia';

  /// Returns the hardcoded Mecca coordinates — always succeeds, used as the
  /// last-resort fallback when neither GPS nor city lookup is available.
  LocationCoords meccaDefault() => const LocationCoords(meccaLat, meccaLng);

  // ── GPS attempt ────────────────────────────────────────────────────────────

  /// Requests GPS permission and, if granted, fetches the current position.
  ///
  /// Never throws — all error paths are captured inside [GpsResult].
  /// Check [GpsResult.needsManualEntry] to decide whether to show the
  /// city-name input UI.
  Future<GpsResult> tryGps() async {
    try {
      // 1. Check current permission state.
      LocationPermission perm = await Geolocator.checkPermission();

      // 2. Request if not yet determined.
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      // 3. Handle denied cases — do NOT crash.
      if (perm == LocationPermission.deniedForever) {
        return GpsResult.permissionDenied(forever: true);
      }
      if (perm == LocationPermission.denied) {
        return GpsResult.permissionDenied();
      }

      // 4. Permission granted — try last-known position first (fast, offline).
      Position? pos = await Geolocator.getLastKnownPosition();

      // 5. Fall back to a fresh GPS fix if no cached position.
      //    We use .timeout(onTimeout: () => null) instead of the timeLimit
      //    field in LocationSettings.  This makes the future complete with
      //    null on timeout rather than *throwing* TimeoutException, so the
      //    VS Code debugger never pauses here — even with "break on caught
      //    exceptions" enabled.
      if (pos == null) {
        final fetched = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
          ),
        ).then<Position?>((p) => p).timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,   // null = timed out, no exception thrown
        );

        if (fetched == null) {
          return GpsResult.gpsFailed(
            'GPS timed out. Please enter your city manually.',
          );
        }
        pos = fetched;
      }

      return GpsResult.success(pos.latitude, pos.longitude);
    } on LocationServiceDisabledException {
      return GpsResult.gpsFailed(
        'Location services are turned off on your device. '
        'Enable them in Settings, or enter your city manually.',
      );
    } catch (e) {
      return GpsResult.gpsFailed('GPS unavailable: ${e.toString()}');
    }
  }

  // ── Reverse geocoding ─────────────────────────────────────────────────────

  /// Converts GPS coordinates to a human-readable city + country.
  /// Returns empty strings if the lookup fails or returns no results.
  /// Never throws.
  Future<({String city, String country})> reverseGeocode(
      double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return (city: '', country: '');
      final p = placemarks.first;
      final city = p.locality?.isNotEmpty == true
          ? p.locality!
          : (p.subAdministrativeArea?.isNotEmpty == true
              ? p.subAdministrativeArea!
              : (p.administrativeArea ?? ''));
      final country = p.country ?? '';
      return (city: city, country: country);
    } catch (_) {
      return (city: '', country: '');
    }
  }

  // ── City-name geocoding ────────────────────────────────────────────────────

  /// Converts [cityName] to coordinates using the device geocoding provider.
  ///
  /// Returns [LocationCoords] if the city is found, or null if it is not.
  /// Never throws — exceptions are swallowed and null is returned instead.
  Future<LocationCoords?> coordsFromCity(String cityName) async {
    final query = cityName.trim();
    if (query.isEmpty) return null;

    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) return null;
      return LocationCoords(results.first.latitude, results.first.longitude);
    } catch (_) {
      // geocoding throws PlatformException when the query yields no results
      // or when the network is unavailable — return null in both cases.
      return null;
    }
  }
}
