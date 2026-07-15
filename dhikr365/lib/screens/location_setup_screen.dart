// ============================================================================
// lib/screens/location_setup_screen.dart
//
// LOCATION SETUP — the way top prayer apps (Muslim Pro, Athan) do it:
//
//   • NO permission ambush. The screen opens showing BOTH options at once:
//     a "Use my current location" button and a city search field.
//     GPS permission is requested only when the user taps the button
//     (in-context request = far higher grant rate, Play-policy friendly).
//   • City search is OFFLINE-FIRST: 34k bundled cities (GeoNames, CC-BY)
//     searched instantly as you type — works in airplane mode, no rate
//     limits. Each city carries its IANA timezone, saved with the pick.
//   • Online fallback (Nominatim) kicks in only for tiny towns the offline
//     DB doesn't know, merged below the offline results.
//   • Permission permanently denied → inline "Open Settings" action.
//   • Mecca remains the last-resort skip.
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../services/city_database.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

enum _GpsState { idle, detecting, error }

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  final _cityController = TextEditingController();
  final _focusNode = FocusNode();

  _GpsState _gpsState = _GpsState.idle;
  String? _gpsError;
  bool _gpsDeniedForever = false;
  bool _saving = false;

  List<City> _results = [];
  bool _searchingOnline = false;
  Timer? _onlineDebounce;
  int _searchSeq = 0; // guards against out-of-order async results

  @override
  void initState() {
    super.initState();
    // Warm the offline DB so the first keystroke already has results.
    CityDatabase().ensureLoaded().catchError((_) {});
  }

  @override
  void dispose() {
    _cityController.dispose();
    _focusNode.dispose();
    _onlineDebounce?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GPS — user-initiated only
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _useGps() async {
    setState(() {
      _gpsState = _GpsState.detecting;
      _gpsError = null;
      _gpsDeniedForever = false;
    });
    _focusNode.unfocus();

    final svc = LocationService();
    final gps = await svc.tryGps();
    if (!mounted) return;

    if (!gps.succeeded) {
      setState(() {
        _gpsState = _GpsState.error;
        _gpsError = gps.failureReason ?? 'Could not detect your location.';
        _gpsDeniedForever =
            (gps.failureReason ?? '').contains('permanently denied');
      });
      return;
    }

    final lat = gps.coords!.lat, lng = gps.coords!.lng;
    final place = await svc.reverseGeocode(lat, lng);
    if (!mounted) return;

    // GPS pick → the device timezone IS the location's timezone.
    String? tz;
    try {
      tz = await FlutterTimezone.getLocalTimezone();
    } catch (_) {}

    await _saveAndProceed(
      lat: lat,
      lng: lng,
      city: place.city,
      country: place.country,
      timezone: tz,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEARCH — offline-first, online fallback for tiny towns
  // ══════════════════════════════════════════════════════════════════════════

  void _onSearchChanged(String query) {
    final q = query.trim();
    _onlineDebounce?.cancel();
    final seq = ++_searchSeq;

    if (q.length < 2) {
      setState(() {
        _results = [];
        _searchingOnline = false;
      });
      return;
    }

    // 1. Instant offline results — no debounce needed, search is ~1 ms.
    final offline = CityDatabase().search(q);
    setState(() {
      _results = offline;
      _searchingOnline = false;
    });

    // 2. Small towns not in the bundled DB: ask Nominatim, merged below.
    if (offline.length < 3 && q.length >= 3) {
      setState(() => _searchingOnline = true);
      _onlineDebounce = Timer(const Duration(milliseconds: 500), () {
        _fetchOnline(q, seq, offline);
      });
    }
  }

  Future<void> _fetchOnline(String query, int seq, List<City> offline) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Adhkaar365App/1.0 (adhkaar365@example.com)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 6));

      if (!mounted || seq != _searchSeq) return; // stale response
      if (resp.statusCode != 200) {
        setState(() => _searchingOnline = false);
        return;
      }

      final List<dynamic> raw = jsonDecode(resp.body);
      final seen = _results.map((c) => c.displayName.toLowerCase()).toSet();
      final extra = <City>[];
      for (final item in raw) {
        final addr = (item['address'] as Map<String, dynamic>?) ?? {};
        final city = (addr['city'] as String?) ??
            (addr['town'] as String?) ??
            (addr['village'] as String?) ??
            (addr['municipality'] as String?) ??
            (addr['county'] as String?) ??
            query;
        final country = (addr['country'] as String?) ?? '';
        final lat = double.tryParse(item['lat'].toString());
        final lng = double.tryParse(item['lon'].toString());
        if (lat == null || lng == null) continue;

        final result = City(
          name: city,
          country: country,
          countryCode: (addr['country_code'] as String? ?? '').toUpperCase(),
          lat: lat,
          lng: lng,
          population: 0,
          // Nominatim has no timezone — borrow it from the nearest known city.
          timezone: CityDatabase().nearestTimezone(lat, lng) ?? '',
        );
        if (seen.add(result.displayName.toLowerCase())) extra.add(result);
      }

      setState(() {
        _results = [...offline, ...extra];
        _searchingOnline = false;
      });
    } catch (_) {
      if (mounted && seq == _searchSeq) {
        setState(() => _searchingOnline = false);
      }
    }
  }

  Future<void> _pickCity(City c) async {
    _focusNode.unfocus();
    _onlineDebounce?.cancel();
    setState(() => _results = []);
    _cityController.text = c.displayName;
    await _saveAndProceed(
      lat: c.lat,
      lng: c.lng,
      city: c.name,
      country: c.country,
      timezone: c.timezone.isNotEmpty ? c.timezone : null,
    );
  }

  Future<void> _useMecca() async {
    await _saveAndProceed(
      lat: LocationService.meccaLat,
      lng: LocationService.meccaLng,
      city: LocationService.meccaCity,
      country: LocationService.meccaCountry,
      timezone: 'Asia/Riyadh',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _saveAndProceed({
    required double lat,
    required double lng,
    required String city,
    required String country,
    String? timezone,
  }) async {
    if (!mounted || _saving) return;
    setState(() => _saving = true);

    final up = Provider.of<UserProvider>(context, listen: false);
    final np = Provider.of<NotificationProvider>(context, listen: false);

    await up.setCoordinates(lat, lng);
    await up.setLocation(city, country);
    if (timezone != null && timezone.isNotEmpty) {
      await up.setTimezone(timezone);
    }
    await NotificationService().requestPermissions();
    await np.refreshAllSchedules(up);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (_) => false,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.height < 680;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [AppColors.bgTeal, AppColors.bgDark],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isSmall ? 16 : 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(isSmall),
                    SizedBox(height: isSmall ? 20 : 28),
                    _buildGpsButton(),
                    if (_gpsState == _GpsState.error) _buildGpsError(),
                    SizedBox(height: isSmall ? 16 : 22),
                    _buildDivider(),
                    SizedBox(height: isSmall ? 16 : 22),
                    _buildSearchField(),
                    if (_results.isNotEmpty) _buildResultsList(),
                    SizedBox(height: isSmall ? 16 : 24),
                    _buildMeccaLink(),
                    const SizedBox(height: 10),
                    _buildFooterNote(),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmall) {
    return Column(
      children: [
        Container(
          width: isSmall ? 60 : 76,
          height: isSmall ? 60 : 76,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.primary.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.2), blurRadius: 24),
            ],
          ),
          child: Icon(Icons.location_on_rounded,
              color: AppColors.primary, size: isSmall ? 28 : 36),
        ),
        SizedBox(height: isSmall ? 14 : 20),
        Text(
          'Set Your Location',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmall ? 22 : 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: isSmall ? 6 : 10),
        Text(
          'Prayer times and adhkar reminders are\ncalculated for your exact location.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmall ? 13 : 15,
            color: Colors.white.withOpacity(0.5),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildGpsButton() {
    final detecting = _gpsState == _GpsState.detecting;
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: (detecting || _saving) ? null : _useGps,
        icon: detecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Icon(Icons.my_location_rounded, size: 22),
        label: Text(
          detecting ? 'Detecting your location…' : 'Use my current location',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildGpsError() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _gpsError ?? '',
                  style:
                      const TextStyle(fontSize: 13, color: Colors.redAccent),
                ),
              ),
            ]),
            if (_gpsDeniedForever) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Geolocator.openAppSettings(),
                  icon: const Icon(Icons.settings_rounded,
                      size: 16, color: AppColors.primary),
                  label: const Text(
                    'Open Settings',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR SEARCH YOUR CITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _cityController,
      focusNode: _focusNode,
      enabled: !_saving,
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
      style: const TextStyle(
          fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: 'Type your city… e.g. Dhaka, London',
        hintStyle:
            TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        prefixIcon: Icon(Icons.search_rounded,
            color: Colors.white.withOpacity(0.4), size: 20),
        suffixIcon: _searchingOnline
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                ),
              )
            : (_cityController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Colors.white.withOpacity(0.4), size: 18),
                    onPressed: () {
                      _cityController.clear();
                      _onlineDebounce?.cancel();
                      setState(() => _results = []);
                    },
                  )
                : null),
      ),
    );
  }

  Widget _buildResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D3330),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _results.length,
          separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.06),
              indent: 48,
              endIndent: 16),
          itemBuilder: (context, i) {
            final c = _results[i];
            return InkWell(
              onTap: _saving ? null : () => _pickCity(c),
              splashColor: AppColors.primary.withOpacity(0.1),
              highlightColor: AppColors.primary.withOpacity(0.05),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_city_rounded,
                          color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (c.country.isNotEmpty)
                            Text(
                              c.country,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.north_west_rounded,
                        size: 14, color: Colors.white.withOpacity(0.25)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMeccaLink() {
    return TextButton.icon(
      onPressed: _saving ? null : _useMecca,
      icon: Icon(Icons.mosque_rounded,
          color: Colors.white.withOpacity(0.4), size: 17),
      label: Text(
        'Skip — use Mecca as default',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Text(
      _saving
          ? 'Saving your location…'
          : 'Works offline • You can change this anytime in Settings.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withOpacity(0.3),
        height: 1.5,
      ),
    );
  }
}
