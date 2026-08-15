import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import '../providers/user_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/language_provider.dart';
import '../services/location_service.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/prayer_calculation_helper.dart';
import 'location_setup_screen.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  List<_Prayer> _prayers = [];

  // Stores either a resolved location string (e.g. "London, UK")
  // or a translation key when the location is still being determined.
  // _resolveLocation() converts keys to translated text at display time.
  String _locationName = 'locating';

  double? _lastLat;
  double? _lastLng;
  String? _lastCity;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final up = Provider.of<UserProvider>(context);
    if (_lastLat != up.lat || _lastLng != up.lng || _lastCity != up.city) {
      _lastLat = up.lat;
      _lastLng = up.lng;
      _lastCity = up.city;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchPrayerTimes();
      });
    }
  }

  // ── GPS + adhan ───────────────────────────────────────────────────────────

  Future<void> _fetchPrayerTimes({bool forceGPS = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final lp           = Provider.of<LanguageProvider>(context, listen: false);
      double? lat;
      double? lng;

      // 1. Use saved coordinates directly (fastest, no network needed)
      if (!forceGPS && userProvider.hasSavedCoordinates) {
        lat = userProvider.lat;
        lng = userProvider.lng;
        final city    = userProvider.city ?? '';
        final country = userProvider.country ?? '';
        setState(() => _locationName =
            city.isNotEmpty ? '$city, $country' : 'saved_location');
      }

      // 2. Fallback: saved city name → geocode to coords.
      //    Uses LocationService.coordsFromCity() which swallows all exceptions
      //    silently (no PlatformException pause in the VS Code debugger).
      //    A 5-second Dart timeout is added as a belt-and-suspenders guard so
      //    the app never hangs waiting for a slow/unavailable geocoder.
      else if (!forceGPS && userProvider.city?.isNotEmpty == true) {
        final query  = '${userProvider.city}, ${userProvider.country}';
        final coords = await LocationService()
            .coordsFromCity(query)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => null, // null = timed out, no exception thrown
            );
        if (coords != null) {
          lat = coords.lat;
          lng = coords.lng;
          await userProvider.setCoordinates(lat, lng);
          setState(() => _locationName = query);
        }
        // coords == null → fall through to GPS below
      }

      // 3. GPS — used when no saved data or user taps refresh
      if (lat == null || lng == null) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.deniedForever) {
          throw Exception(lp.getText('location_perm_denied_forever'));
        }
        if (perm == LocationPermission.denied) {
          throw Exception(lp.getText('location_perm_denied'));
        }

        Position? pos = await Geolocator.getLastKnownPosition();
        if (pos == null) {
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
              ),
            );
          } catch (e) {
            throw Exception(lp.getText('location_city_not_found'));
          }
        }
        lat = pos.latitude;
        lng = pos.longitude;

        await userProvider.setCoordinates(lat, lng);
        _reverseGeocode(lat, lng, userProvider);
      }

      // 4. Build adhan coordinates & params
      final coords = Coordinates(lat, lng);
      final params = userProvider.calculationMethod.getParameters()
        ..madhab = userProvider.madhab.toLowerCase() == 'hanafi'
            ? Madhab.hanafi
            : Madhab.shafi;

      final date  = DateComponents.from(DateTime.now());
      final times = PrayerTimes(coords, date, params);

      setState(() {
        // CRITICAL: keep English internal names — used by NotificationProvider
        // as lookup keys (isPrayerEnabled / toggleSpecificPrayer).
        // Translated display names are resolved in build() via the prayerLabels map.
        _prayers = [
          _Prayer('Fajr',    times.fajr,    Icons.nights_stay),
          _Prayer('Sunrise', times.sunrise,  Icons.wb_sunny, isSunrise: true),
          _Prayer('Dhuhr',   times.dhuhr,   Icons.light_mode),
          _Prayer('Asr',     times.asr,     Icons.wb_twilight),
          _Prayer('Maghrib', times.maghrib, Icons.dark_mode),
          _Prayer('Isha',    times.isha,    Icons.bedtime),
        ];
        _sunriseTime = times.sunrise;
        _sunsetTime  = times.maghrib;
        _loading     = false;
      });

      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false)
            .refreshAllSchedules(userProvider);
      }
    } catch (e) {
      setState(() {
        _error   = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  DateTime? _sunriseTime;
  DateTime? _sunsetTime;

  void _reverseGeocode(
      double lat, double lng, UserProvider userProvider) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p       = placemarks.first;
        final city    = p.locality?.isNotEmpty == true
            ? p.locality!
            : p.administrativeArea ?? 'Unknown';
        final country = p.country ?? '';
        await userProvider.setLocation(city, country);
        if (mounted) setState(() => _locationName = '$city, $country');
      }
    } catch (_) {
      // Use translation key so it gets resolved properly in build()
      if (mounted) setState(() => _locationName = 'gps_location');
    }
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  int get _curIdx {
    if (_prayers.isEmpty) return 0;
    final now = DateTime.now();
    for (int i = _prayers.length - 1; i >= 0; i--) {
      final t = _prayers[i].time;
      if (t != null && now.isAfter(t)) return i;
    }
    return _prayers.length - 1;
  }

  int get _nextIdx => (_curIdx + 1) % _prayers.length;

  String _getCountdown(String langCode) {
    if (_prayers.isEmpty) return '--';
    final now  = DateTime.now();
    var next   = _prayers[_nextIdx].time;
    if (next == null) return '--';
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    final diff = next.difference(now);
    final h    = diff.inHours;
    final m    = diff.inMinutes % 60;
    final str  = h > 0 ? '${h}h ${m}m' : '${m}m';
    return R.localizeDigits(str, langCode);
  }

  double get _sunProgress {
    final rise = _sunriseTime;
    final set  = _sunsetTime;
    if (rise == null || set == null) return 0.5;
    final now  = DateTime.now();
    if (now.isBefore(rise)) return 0.0;
    if (now.isAfter(set))   return 1.0;
    return now.difference(rise).inMinutes / set.difference(rise).inMinutes;
  }

  /// Resolves `_locationName` to translated text.
  /// Known translation keys are looked up via lp; real city strings pass through.
  String _resolveLocation(LanguageProvider lp) {
    switch (_locationName) {
      case 'locating':
        return lp.getText('locating');
      case 'saved_location':
        return lp.getText('saved_location');
      case 'gps_location':
        return lp.getText('gps_location');
      default:
        return _locationName; // actual "City, Country" string
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  // ── No-location empty state ───────────────────────────────────────────────

  Widget _buildNoLocation(BuildContext context) {
    final lp        = Provider.of<LanguageProvider>(context, listen: false);
    final titleSize = R.adaptive(18.0, 20.0, 24.0);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: AppDeco.radialBg(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Minimal AppBar — title only, no refresh button needed
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(lp.getText('prayer_times'),
                    style: AppText.heading(titleSize)),
              ),
              // Centred empty state
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.mosque,
                              color: AppColors.primary, size: 34),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Location Not Set',
                          style: AppText.manrope(
                              fontSize: 22, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your location is needed to calculate accurate prayer times for your area.',
                          style: AppText.body(color: AppColors.textSlate400),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LocationSetupScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 12),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on,
                                    color: AppColors.textPrimary, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Set Location',
                                  style: AppText.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    R.init(context);

    // Guard: if coordinates are missing, show empty state with a Set Location
    // button — do not attempt to load prayer times.
    final userProvider = Provider.of<UserProvider>(context);
    if (!userProvider.hasSavedCoordinates) {
      return _buildNoLocation(context);
    }

    final lp        = Provider.of<LanguageProvider>(context);
    final langCode  = lp.locale.languageCode;
    final today     = R.localizeDigits(
        DateFormat('EEEE, d MMM').format(DateTime.now()), langCode);
    final titleSize = R.adaptive(18.0, 20.0, 24.0);

    // Build translated prayer name map — English keys stay internal,
    // display labels come from the JSON for the current language.
    final prayerLabels = {
      'Fajr':    lp.getText('fajr'),
      'Sunrise': lp.getText('sunrise'),
      'Dhuhr':   lp.getText('dhuhr'),
      'Asr':     lp.getText('asr'),
      'Maghrib': lp.getText('maghrib'),
      'Isha':    lp.getText('isha'),
    };

    // Display-only copies of prayers with translated names and
    // digit-localized time strings (Arabic ٣:٤٥ م, Hindi ३:४५, etc.).
    final displayPrayers = _prayers
        .map((p) => _Prayer(
              p.name, // internal key — unchanged
              p.time,
              p.icon,
              isSunrise: p.isSunrise,
              displayName: prayerLabels[p.name] ?? p.name,
              timeOverride: p.time == null
                  ? '--:--'
                  : R.localizeDigits(
                      DateFormat('h:mm a').format(p.time!.toLocal()), langCode),
            ))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: AppDeco.radialBg(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── AppBar ──
            SliverAppBar(
              backgroundColor: AppColors.bgDark.withOpacity(0.85),
              pinned: true,
              elevation: 0,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lp.getText('prayer_times'),
                      style: AppText.heading(titleSize)),
                  Row(children: [
                    Icon(Icons.location_on,
                        size: 13, color: AppColors.textSlate400),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_resolveLocation(lp)} · $today',
                        style: AppText.manrope(
                            fontSize: 12, color: AppColors.textSlate400),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    icon: _loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : Icon(Icons.refresh, color: AppColors.primary),
                    onPressed: _loading
                        ? null
                        : () => _fetchPrayerTimes(forceGPS: true),
                  ),
                ),
              ],
            ),

            // ── Body ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: _loading
                    ? _buildLoading(lp)
                    : _error != null
                        ? _buildError(lp)
                        : _buildContent(lp, langCode, displayPrayers),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading state ─────────────────────────────────────────────────────────

  Widget _buildLoading(LanguageProvider lp) {
    return SizedBox(
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(lp.getText('getting_location'),
              style:
                  AppText.manrope(fontSize: 14, color: AppColors.textSlate400)),
          const SizedBox(height: 8),
          Text(lp.getText('calculating_prayers'),
              style:
                  AppText.manrope(fontSize: 12, color: AppColors.textSlate500)),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError(LanguageProvider lp) {
    return SizedBox(
      height: 400,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Icon(Icons.location_off,
                  color: Colors.redAccent, size: 28),
            ),
            const SizedBox(height: 20),
            Text(lp.getText('location_error'),
                style:
                    AppText.manrope(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style:
                  AppText.manrope(fontSize: 13, color: AppColors.textSlate400),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _fetchPrayerTimes,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(lp.getText('try_again'),
                    style: AppText.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: Text(lp.getText('open_app_settings'),
                  style:
                      AppText.manrope(fontSize: 12, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────

  Widget _buildContent(LanguageProvider lp, String langCode, List<_Prayer> displayPrayers) {
    if (displayPrayers.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      const SizedBox(height: 24),
      _SunPath(
        progress: _sunProgress,
        sunriseLabel: _sunriseTime != null
            ? R.localizeDigits(DateFormat('h:mm a').format(_sunriseTime!.toLocal()), langCode)
            : '—',
        sunsetLabel: _sunsetTime != null
            ? R.localizeDigits(DateFormat('h:mm a').format(_sunsetTime!.toLocal()), langCode)
            : '—',
        morningLabel: lp.getText('sun_morning'),
        noonLabel:    lp.getText('sun_noon'),
        eveningLabel: lp.getText('sun_evening'),
      ),
      const SizedBox(height: 28),
      _HeroCard(
        prayer:              displayPrayers[_curIdx],
        next:                displayPrayers[_nextIdx],
        countdown:           _getCountdown(langCode),
        currentPrayerLabel:  lp.getText('current_prayer').toUpperCase(),
        inLabel:             lp.getText('in_label'),
      ),
      const SizedBox(height: 28),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(lp.getText('daily_schedule').toUpperCase(),
            style: AppText.label()),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: List.generate(
            displayPrayers.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PrayerRow(
                // displayPrayers carry translated name; internal _prayers keep English key
                prayer:   displayPrayers[i],
                internalName: _prayers[i].name, // English key for notification API
                isNow:    i == _curIdx && !_prayers[i].isSunrise,
                isNext:   i == _nextIdx && !_prayers[i].isSunrise,
                nowLabel:  lp.getText('now_badge'),
                nextLabel: lp.getText('next_badge'),
              ),
            ),
          ),
        ),
      ),

      // Method note
      Consumer<UserProvider>(builder: (context, up, _) {
        final methodName = getMethodName(up.calculationMethod);
        final madhabName =
            up.madhab.toLowerCase() == 'hanafi' ? 'Hanafi' : 'Shafi';
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(children: [
            Icon(Icons.info_outline,
                size: 12, color: AppColors.textSlate500),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${lp.getText('prayer_calculation')}: $methodName · $madhabName',
                style: AppText.manrope(
                    fontSize: 10, color: AppColors.textSlate500),
              ),
            ),
          ]),
        );
      }),
    ]);
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _Prayer {
  /// Internal English key — used by NotificationProvider (isPrayerEnabled /
  /// toggleSpecificPrayer). Never translate this field.
  final String name;

  /// Translated display label resolved in build(). Falls back to [name].
  final String? displayName;

  /// Pre-formatted, digit-localized time string produced in build().
  /// When null, timeStr falls back to a plain DateFormat call.
  final String? timeOverride;

  final DateTime? time;
  final IconData  icon;
  final bool      isSunrise;

  const _Prayer(this.name, this.time, this.icon,
      {this.isSunrise = false, this.displayName, this.timeOverride});

  /// The label shown in the UI — translated when available.
  String get label => displayName ?? name;

  String get timeStr =>
      timeOverride ??
      (time == null ? '--:--' : DateFormat('h:mm a').format(time!.toLocal()));
}

// ── Sun Path ──────────────────────────────────────────────────────────────────

class _SunPath extends StatelessWidget {
  final double progress;
  final String sunriseLabel;
  final String sunsetLabel;
  final String morningLabel;
  final String noonLabel;
  final String eveningLabel;

  const _SunPath({
    required this.progress,
    required this.sunriseLabel,
    required this.sunsetLabel,
    required this.morningLabel,
    required this.noonLabel,
    required this.eveningLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth;
        const h = 80.0;
        final p = progress.clamp(0.0, 1.0);
        final x = (w / 2) - (w / 2) * math.cos(p * math.pi);
        final y = h - h * math.sin(p * math.pi);
        return SizedBox(
          height: h + 28,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(height: 1, color: AppColors.ink(0.08)),
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: h,
                  child: CustomPaint(painter: _ArcPainter())),
              Positioned(
                left: x - 18,
                top: y - 14,
                child: Column(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.2),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12)
                      ],
                    ),
                    child: Icon(Icons.light_mode,
                        color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p < 0.33
                        ? morningLabel
                        : p > 0.67
                            ? eveningLabel
                            : noonLabel,
                    style: AppText.label(color: AppColors.primary)
                        .copyWith(fontSize: 8),
                  ),
                ]),
              ),
              Positioned(
                  bottom: 4,
                  left: 0,
                  child: Text(sunriseLabel,
                      style: AppText.manrope(
                          fontSize: 9, color: AppColors.textSlate500))),
              Positioned(
                  bottom: 4,
                  right: 0,
                  child: Text(sunsetLabel,
                      style: AppText.manrope(
                          fontSize: 9, color: AppColors.textSlate500))),
            ],
          ),
        );
      }),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = AppColors.ink(0.08)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final path = Path();
    path.addArc(
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height),
          width: size.width,
          height: size.height * 2),
      math.pi,
      math.pi,
    );
    const d = 4.0, g = 4.0;
    double dist = 0;
    for (final m in path.computeMetrics()) {
      while (dist < m.length) {
        canvas.drawPath(m.extractPath(dist, dist + d), paint);
        dist += d + g;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final _Prayer prayer;
  final _Prayer next;
  final String  countdown;
  final String  currentPrayerLabel; // translated "CURRENT PRAYER"
  final String  inLabel;            // translated "in"

  const _HeroCard({
    required this.prayer,
    required this.next,
    required this.countdown,
    required this.currentPrayerLabel,
    required this.inLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.15), blurRadius: 20)
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8)),
            child: Text(currentPrayerLabel,
                style: AppText.label(color: AppColors.bgDark)),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(prayer.label, // translated display label
                  style: AppText.manrope(
                      fontSize: 44, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Text(prayer.timeStr,
                  style: AppText.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.schedule, color: AppColors.primary, size: 15),
            const SizedBox(width: 6),
            Text(
              '${next.label} $inLabel $countdown', // "Dhuhr in 2h 30m"
              style: AppText.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Prayer Row ────────────────────────────────────────────────────────────────

class _PrayerRow extends StatefulWidget {
  final _Prayer prayer;
  final String  internalName; // English key for NotificationProvider — never translate
  final bool    isNow;
  final bool    isNext;
  final String  nowLabel;    // translated "NOW"
  final String  nextLabel;   // translated "NEXT"

  const _PrayerRow({
    required this.prayer,
    required this.internalName,
    required this.isNow,
    required this.isNext,
    required this.nowLabel,
    required this.nextLabel,
  });

  @override
  State<_PrayerRow> createState() => _PrayerRowState();
}

class _PrayerRowState extends State<_PrayerRow> {
  @override
  Widget build(BuildContext context) {
    final p = widget.prayer;
    return Opacity(
      opacity: p.isSunrise ? 0.55 : 1.0,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isNow
                ? AppColors.primary.withOpacity(0.14)
                : AppColors.ink(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isNow
                  ? AppColors.primary.withOpacity(0.6)
                  : AppColors.ink(0.07),
              width: widget.isNow ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Icon(p.icon,
                color: widget.isNow
                    ? AppColors.primary
                    : AppColors.textSlate500,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(p.label, // translated display label
                        style: AppText.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: widget.isNow
                                ? AppColors.primary
                                : AppColors.textSlate300)),
                    if (widget.isNext) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.ink(0.08),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(widget.nextLabel, // translated "NEXT"
                            style: AppText.label(color: AppColors.primary)
                                .copyWith(fontSize: 8)),
                      ),
                    ],
                  ]),
                  Text(p.timeStr,
                      style: AppText.manrope(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ])),
            Consumer<NotificationProvider>(
              builder: (context, np, _) {
                // CRITICAL: use internalName (English) as the lookup key —
                // NotificationProvider stores/reads alerts by English name.
                final isEnabled = np.isPrayerEnabled(widget.internalName);
                final up =
                    Provider.of<UserProvider>(context, listen: false);

                return GestureDetector(
                  onTap: () => np.toggleSpecificPrayer(
                      widget.internalName, !isEnabled, up),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isNow
                          ? AppColors.primary
                          : (isEnabled
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent),
                      border: Border.all(
                        color: widget.isNow
                            ? AppColors.primary
                            : (isEnabled
                                ? AppColors.primary.withOpacity(0.4)
                                : AppColors.ink(0.1)),
                      ),
                    ),
                    child: Icon(
                      isEnabled || widget.isNow
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      color: widget.isNow
                          ? AppColors.bgDark
                          : (isEnabled
                              ? AppColors.primary
                              : AppColors.textSlate500),
                      size: 17,
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
        if (widget.isNow)
          Positioned(
            top: -8,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6)),
              child: Text(widget.nowLabel, // translated "NOW"
                  style: AppText.label(color: AppColors.bgDark)
                      .copyWith(fontSize: 9)),
            ),
          ),
      ]),
    );
  }
}
