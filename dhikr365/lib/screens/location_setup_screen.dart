// ============================================================================
// lib/screens/location_setup_screen.dart
//
// Flow:
//   1. Screen opens → auto-attempts GPS + reverse geocode.
//   2. GPS succeeds → saves coords + city → navigates to Dashboard silently.
//   3. GPS fails → shows manual city-search form with live autocomplete.
//   4. Autocomplete calls Nominatim (OpenStreetMap, no API key) debounced 400 ms.
//   5. Tapping a suggestion instantly saves + navigates.
//   6. "Use Mecca" button is always a last resort.
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';

// ── Data class for a single autocomplete result ──────────────────────────────

class _CityResult {
  final String displayName; // "Dhaka, Dhaka Division, Bangladesh"
  final String city;
  final String country;
  final double lat;
  final double lng;

  const _CityResult({
    required this.displayName,
    required this.city,
    required this.country,
    required this.lat,
    required this.lng,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  final _cityController = TextEditingController();
  final _focusNode      = FocusNode();

  // 'gps'    = auto-detecting via GPS (initial state)
  // 'manual' = GPS failed, show city input
  // 'saving' = confirmed, saving + navigating
  String _phase = 'gps';
  String? _error;

  // ── Autocomplete state ────────────────────────────────────────────────────
  List<_CityResult> _suggestions     = [];
  bool              _loadingSugg     = false;
  Timer?            _debounce;

  @override
  void initState() {
    super.initState();
    _tryGpsAutoDetect();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Autocomplete ──────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().length < 2) {
      setState(() { _suggestions = []; _loadingSugg = false; });
      return;
    }
    setState(() => _loadingSugg = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(query.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q'             : query,
        'format'        : 'json',
        'limit'         : '6',
        'addressdetails': '1',
        'featuretype'   : 'city',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Adhkaar365App/1.0 (adhkaar365@example.com)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 6));

      if (!mounted) return;
      if (resp.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(resp.body);
        final results = raw.map((item) {
          final addr    = (item['address'] as Map<String, dynamic>?) ?? {};
          final city    = (addr['city']         as String?)
                       ?? (addr['town']         as String?)
                       ?? (addr['village']      as String?)
                       ?? (addr['municipality'] as String?)
                       ?? (addr['county']       as String?)
                       ?? query;
          final state   = (addr['state']   as String?) ?? '';
          final country = (addr['country'] as String?) ?? '';

          final parts = <String>[city];
          if (state.isNotEmpty && state != city) parts.add(state);
          if (country.isNotEmpty)                parts.add(country);

          return _CityResult(
            displayName: parts.join(', '),
            city       : city,
            country    : country,
            lat        : double.tryParse(item['lat'].toString()) ?? 0,
            lng        : double.tryParse(item['lon'].toString()) ?? 0,
          );
        }).toList();

        // Deduplicate by display name
        final seen = <String>{};
        final unique = results.where((r) => seen.add(r.displayName)).toList();

        setState(() { _suggestions = unique; _loadingSugg = false; });
      } else {
        setState(() { _suggestions = []; _loadingSugg = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _suggestions = []; _loadingSugg = false; });
    }
  }

  void _pickSuggestion(_CityResult result) {
    _focusNode.unfocus();
    _debounce?.cancel();
    setState(() { _suggestions = []; _loadingSugg = false; });
    _cityController.text = result.displayName;
    _saveAndProceed(
      lat:     result.lat,
      lng:     result.lng,
      city:    result.city,
      country: result.country,
    );
  }

  // ── Auto GPS detect ───────────────────────────────────────────────────────

  Future<void> _tryGpsAutoDetect() async {
    final svc       = LocationService();
    final gpsResult = await svc.tryGps();
    if (!mounted) return;

    if (gpsResult.succeeded) {
      final place = await svc.reverseGeocode(
        gpsResult.coords!.lat,
        gpsResult.coords!.lng,
      );
      if (!mounted) return;
      await _saveAndProceed(
        lat:     gpsResult.coords!.lat,
        lng:     gpsResult.coords!.lng,
        city:    place.city,
        country: place.country,
      );
    } else {
      if (mounted) setState(() { _phase = 'manual'; _error = gpsResult.failureReason; });
    }
  }

  // ── Manual city search (fallback — no autocomplete result matched) ─────────

  Future<void> _searchCity() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'Please enter a city name.');
      return;
    }
    setState(() { _phase = 'saving'; _error = null; });
    try {
      final locations = await locationFromAddress(city);
      if (!mounted) return;
      if (locations.isEmpty) {
        setState(() { _phase = 'manual'; _error = 'City not found. Try a different name.'; });
        return;
      }
      final first = locations.first;
      await _saveAndProceed(
        lat: first.latitude, lng: first.longitude,
        city: city, country: '',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() { _phase = 'manual'; _error = 'City not found. Try a different name.'; });
    }
  }

  Future<void> _retryGps() async {
    setState(() { _phase = 'gps'; _error = null; });
    await _tryGpsAutoDetect();
  }

  Future<void> _useMecca() async {
    setState(() { _phase = 'saving'; _error = null; });
    await _saveAndProceed(
      lat:     LocationService.meccaLat,
      lng:     LocationService.meccaLng,
      city:    LocationService.meccaCity,
      country: LocationService.meccaCountry,
    );
  }

  Future<void> _saveAndProceed({
    required double lat, required double lng,
    required String city, required String country,
  }) async {
    if (!mounted) return;
    setState(() => _phase = 'saving');
    final up = Provider.of<UserProvider>(context, listen: false);
    final np = Provider.of<NotificationProvider>(context, listen: false);

    await up.setCoordinates(lat, lng);
    await up.setLocation(city, country);
    await NotificationService().requestPermissions();
    await np.refreshAllSchedules(up);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (_) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          child: _phase == 'gps'
              ? _buildDetecting(isSmall)
              : LayoutBuilder(builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: isSmall ? 20 : 32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(isSmall),
                            SizedBox(height: isSmall ? 24 : 36),
                            _buildManualForm(isSmall),
                            SizedBox(height: isSmall ? 20 : 28),
                            _buildDivider(),
                            SizedBox(height: isSmall ? 12 : 16),
                            _buildSecondaryActions(isSmall),
                            const SizedBox(height: 16),
                            _buildFooterNote(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
        ),
      ),
    );
  }

  // ── GPS detecting state ───────────────────────────────────────────────────

  Widget _buildDetecting(bool isSmall) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isSmall ? 72 : 88,
              height: isSmall ? 72 : 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Icon(
                Icons.my_location_rounded,
                color: AppColors.primary,
                size: isSmall ? 32 : 40,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Detecting your location…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Using GPS to set your city\nand prayer times automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 36, height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isSmall) {
    return Column(
      children: [
        Center(
          child: Container(
            width: isSmall ? 64 : 80,
            height: isSmall ? 64 : 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Icon(
              Icons.location_off_rounded,
              color: AppColors.primary,
              size: isSmall ? 30 : 38,
            ),
          ),
        ),
        SizedBox(height: isSmall ? 16 : 24),
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
        SizedBox(height: isSmall ? 8 : 12),
        Text(
          'GPS was unavailable or denied.\nType your city to get accurate prayer times.',
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

  // ── Manual form with autocomplete ─────────────────────────────────────────

  Widget _buildManualForm(bool isSmall) {
    final isSaving = _phase == 'saving';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Input card ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CITY NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller:      _cityController,
                focusNode:       _focusNode,
                textInputAction: TextInputAction.search,
                enabled:         !isSaving,
                onChanged:       _onSearchChanged,
                onSubmitted:     (_) => isSaving ? null : _searchCity(),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'e.g. Dhaka, London, Cairo…',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  filled:      true,
                  fillColor:   Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 20,
                  ),
                  suffixIcon: _loadingSugg
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18, height: 18,
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
                                setState(() { _suggestions = []; _error = null; });
                              },
                            )
                          : null),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.redAccent)),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _searchCity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Confirm Location',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),

        // ── Suggestions dropdown ────────────────────────────────────────────
        if (_suggestions.isNotEmpty)
          Container(
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
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.06),
                    indent: 48,
                    endIndent: 16),
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  final parts = s.displayName.split(', ');
                  final primary   = parts.first;
                  final secondary = parts.length > 1
                      ? parts.skip(1).join(', ')
                      : '';
                  return InkWell(
                    onTap: () => _pickSuggestion(s),
                    splashColor: AppColors.primary.withOpacity(0.1),
                    highlightColor: AppColors.primary.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                color: AppColors.primary, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  primary,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (secondary.isNotEmpty)
                                  Text(
                                    secondary,
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
                              size: 14,
                              color: Colors.white.withOpacity(0.25)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
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

  // ── Secondary actions ─────────────────────────────────────────────────────

  Widget _buildSecondaryActions(bool isSmall) {
    final isSaving = _phase == 'saving';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: isSaving ? null : _retryGps,
          icon: Icon(Icons.gps_fixed_rounded,
              color: Colors.white.withOpacity(0.6), size: 18),
          label: Text(
            'Try GPS again',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.6)),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isSaving ? null : _useMecca,
          icon: Icon(Icons.mosque_rounded,
              color: Colors.white.withOpacity(0.4), size: 18),
          label: Text(
            'Skip — use Mecca as default',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.4)),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // ── Footer note ───────────────────────────────────────────────────────────

  Widget _buildFooterNote() {
    return Text(
      'You can update your location anytime in Settings.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withOpacity(0.3),
        height: 1.5,
      ),
    );
  }
}
