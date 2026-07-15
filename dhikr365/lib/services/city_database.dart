// ============================================================================
// lib/services/city_database.dart
//
// OFFLINE CITY DATABASE — instant, no network, no API keys.
//
// This is how the big prayer apps (Muslim Pro, Athan) do manual location:
// a bundled database of world cities searched locally as the user types,
// so results are instant and work with airplane mode on. Each city carries
// its IANA timezone, so picking a city also sets the timezone correctly.
//
// Data: GeoNames cities15000 (all cities with population ≥ 15 000),
// 34 002 cities, licensed CC-BY 4.0 — https://www.geonames.org/
// Bundled as assets/data/cities.json in a compact form:
//   { countries: {ISO: name}, tzs: [IANA...], cities: [[...], ...] }
//   city row: [displayName, searchKey, countryCode, lat, lng,
//              population, tzIndex]   (sorted by population, descending)
// searchKey is '' when identical to displayName lowercased; otherwise it is
// one or more '|'-separated lowercase phrases (ascii form + common English
// exonyms, e.g. Makkah carries "makkah|mecca|makka|mekka") — each phrase is
// an equal-rank prefix-match candidate.
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A single city result from the offline database.
class City {
  final String name;
  final String country;
  final String countryCode;
  final double lat;
  final double lng;
  final int population;
  final String timezone; // IANA, e.g. "Asia/Dhaka"

  const City({
    required this.name,
    required this.country,
    required this.countryCode,
    required this.lat,
    required this.lng,
    required this.population,
    required this.timezone,
  });

  /// "Dhaka, Bangladesh" — what the UI shows.
  String get displayName => country.isEmpty ? name : '$name, $country';
}

/// Parsed in a background isolate — kept top-level for [compute].
class _ParsedDb {
  final Map<String, String> countries;
  final List<String> tzs;
  final List<List<dynamic>> cities;
  final List<String> searchKeys; // precomputed lowercase keys, same order
  _ParsedDb(this.countries, this.tzs, this.cities, this.searchKeys);
}

_ParsedDb _parseDb(String jsonStr) {
  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
  final countries = (map['countries'] as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as String));
  final tzs = (map['tzs'] as List).cast<String>();
  final cities = (map['cities'] as List).cast<List<dynamic>>();
  // Precompute the search key once: ascii variant when present, else the
  // display name lowercased. Saves doing it on every keystroke.
  final searchKeys = List<String>.generate(cities.length, (i) {
    final row = cities[i];
    final ascii = row[1] as String;
    return ascii.isNotEmpty ? ascii : (row[0] as String).toLowerCase();
  }, growable: false);
  return _ParsedDb(countries, tzs, cities, searchKeys);
}

class CityDatabase {
  static final CityDatabase _instance = CityDatabase._internal();
  factory CityDatabase() => _instance;
  CityDatabase._internal();

  _ParsedDb? _db;
  Future<void>? _loading;

  bool get isLoaded => _db != null;

  /// Loads and parses the bundled database off the UI thread.
  /// Idempotent — concurrent callers await the same future.
  Future<void> ensureLoaded() {
    if (_db != null) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/cities.json');
      _db = await compute(_parseDb, jsonStr);
      debugPrint('[CityDb] Loaded ${_db!.cities.length} cities');
    } catch (e) {
      debugPrint('[CityDb] Failed to load: $e');
      _loading = null; // allow retry
      rethrow;
    }
  }

  City _toCity(List<dynamic> row) {
    final db = _db!;
    final cc = row[2] as String;
    return City(
      name: row[0] as String,
      country: db.countries[cc] ?? cc,
      countryCode: cc,
      lat: (row[3] as num).toDouble(),
      lng: (row[4] as num).toDouble(),
      population: (row[5] as num).toInt(),
      timezone: db.tzs[(row[6] as num).toInt()],
    );
  }

  /// Instant prefix search, diacritic-insensitive, biggest cities first.
  ///
  /// A hit on any '|'-separated alias phrase ranks the same as a hit on the
  /// name itself ("mecca" finds Makkah first). Word-prefix matches count
  /// too, ranked below ("york" finds "New York"). Because the rows are
  /// pre-sorted by population, the first [limit] hits per bucket are already
  /// the most relevant — no scoring pass needed.
  List<City> search(String query, {int limit = 8}) {
    final db = _db;
    if (db == null) return const [];
    final q = _normalize(query.trim().toLowerCase());
    if (q.length < 2) return const [];

    final exactPrefix = <List<dynamic>>[];
    final wordPrefix = <List<dynamic>>[];

    final keys = db.searchKeys;
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      // Prefix of the name or of any alias phrase → top bucket.
      if (key.startsWith(q) || key.contains('|$q')) {
        exactPrefix.add(db.cities[i]);
        if (exactPrefix.length >= limit) break;
      } else if (wordPrefix.length < limit && key.contains(' $q')) {
        wordPrefix.add(db.cities[i]);
      }
    }

    return [...exactPrefix, ...wordPrefix]
        .take(limit)
        .map(_toCity)
        .toList(growable: false);
  }

  /// Timezone of the database city closest to ([lat], [lng]).
  /// Used for results that come from the online fallback (which has no
  /// timezone data). Linear scan over ~34k rows — sub-millisecond.
  String? nearestTimezone(double lat, double lng) {
    final db = _db;
    if (db == null || db.cities.isEmpty) return null;
    var bestDist = double.infinity;
    List<dynamic>? best;
    for (final row in db.cities) {
      final dLat = (row[3] as num).toDouble() - lat;
      final dLng = (row[4] as num).toDouble() - lng;
      final d = dLat * dLat + dLng * dLng;
      if (d < bestDist) {
        bestDist = d;
        best = row;
      }
    }
    return best == null ? null : db.tzs[(best[6] as num).toInt()];
  }

  /// Strips common diacritics so "sao paulo" matches "São Paulo".
  static String _normalize(String s) {
    const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿšžłđğışćč';
    const to   = 'aaaaaaceeeeiiiinooooouuuuyyszldgiscc';
    final sb = StringBuffer();
    for (final code in s.runes) {
      final ch = String.fromCharCode(code);
      final idx = from.indexOf(ch);
      sb.write(idx >= 0 ? to[idx] : ch);
    }
    return sb.toString();
  }
}
