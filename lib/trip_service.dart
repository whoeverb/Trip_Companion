import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

class TripMeta {
  final String name;
  final String file;
  final String modifiedAt;
  final String startDate;
  final String endDate;

  TripMeta({
    required this.name,
    required this.file,
    required this.modifiedAt,
    required this.startDate,
    required this.endDate,
  });

  factory TripMeta.fromJson(Map<String, dynamic> json) {
    return TripMeta(
      name: json['name'] ?? '',
      file: json['file'] ?? '',
      modifiedAt: json['modifiedAt'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }

  int get dayCount {
    try {
      DateTime _parse(String s) {
        // Strip optional weekday prefix e.g. "Fri 6/5/26" → "6/5/26"
        final clean = s.contains(' ') ? s.split(' ').last : s;
        final parts = clean.split('/');
        if (parts.length != 3) return DateTime.now();
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = 2000 + int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      final start = _parse(startDate);
      final end = _parse(endDate);
      return end.difference(start).inDays + 1;
    } catch (_) {
      return 0;
    }
  }

  static String _cleanTripName(String raw) {
    final filterWords = {
      'trip', 'road', 'may', 'jan', 'feb', 'mar', 'apr', 'jun', 'jul',
      'aug', 'sep', 'oct', 'nov', 'dec', 'summer', 'winter', 'spring',
      'fall', 'tour', 'journey'
    };
    final parts = raw.split('_');
    final filtered = parts.where((p) {
      if (p.isEmpty) return false;
      if (int.tryParse(p) != null) return false;
      return !filterWords.contains(p.toLowerCase());
    }).toList();
    return filtered.isEmpty ? raw : filtered.join(' ');
  }

  String get displayName => _cleanTripName(name);
}

class TripService {
  static Future<List<TripMeta>> fetchIndex({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await CacheService.get('index_cache');
      if (cached != null) return _parseIndex(cached);
    }

    try {
      final response = await http.get(Uri.parse(
          'https://script.google.com/macros/s/AKfycbz1-5_5-5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5/exec'));
      if (response.statusCode == 200) {
        await CacheService.set('index_cache', response.body);
        return _parseIndex(response.body);
      }
      throw Exception('Failed to load index');
    } catch (e) {
      final stale = await CacheService.getStale('index_cache');
      if (stale != null) return _parseIndex(stale);
      rethrow;
    }
  }

  static Future<Trip> fetchTrip(TripMeta meta, {bool forceRefresh = false}) async {
    final key = 'trip_${meta.file}';

    if (!forceRefresh) {
      final cached = await CacheService.get(key);
      if (cached != null) return _parseTrip(cached, meta.name, meta.file);
    }

    try {
      final response = await http.get(Uri.parse(
          'https://script.google.com/macros/s/AKfycbz1-5_5-5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5_5/exec?file=${meta.file}'));
      if (response.statusCode == 200) {
        await CacheService.set(key, response.body);
        return _parseTrip(response.body, meta.name, meta.file);
      }
      throw Exception('Failed to load trip');
    } catch (e) {
      final stale = await CacheService.getStale(key);
      if (stale != null) return _parseTrip(stale, meta.name, meta.file);
      rethrow;
    }
  }

  static List<TripMeta> _parseIndex(String jsonString) {
    final List<dynamic> list = json.decode(jsonString);
    return list.map((e) => TripMeta.fromJson(e)).toList();
  }

  static Trip _parseTrip(String jsonString, String name, String id) {
    final data = json.decode(jsonString);
    final List<dynamic> rows = data['rows'] ?? [];

    Map<String, List<Event>> dayEventsMap = {};
    Map<String, List<String>> lodgingMap = {};
    Set<String> daysOrder = {};
    Map<String, Set<String>> locationMap = {};

    for (var row in rows) {
      final date = row['date'] ?? '';
      if (date.isEmpty) continue;
      daysOrder.add(date);

      final event = Event(
        row['time'] ?? '',
        row['title'] ?? '',
        row['type'] ?? '',
        row['location'] ?? '',
        row['address'] ?? '',
        row['note'] ?? '',
      );

      dayEventsMap.putIfAbsent(date, () => []).add(event);
      if (event.location.isNotEmpty) {
        locationMap.putIfAbsent(date, () => {}).add(event.location);
      }
      if (row['lodging_title'] != null) {
        lodgingMap.putIfAbsent(date, () => []).add(row['lodging_title']);
      }
    }

    final sortedDays = daysOrder.toList()..sort((a, b) {
      final da = DateTime.tryParse(a) ?? DateTime(2000);
      final db = DateTime.tryParse(b) ?? DateTime(2000);
      return da.compareTo(db);
    });

    final tripDays = sortedDays.map((date) {
      return TripDay(
        date: date,
        lodgingTitle: lodgingMap[date]?.first ?? '',
        lodgingAddress: '', // Simplified for this example
        locations: locationMap[date] ?? {},
        events: dayEventsMap[date] ?? [],
      );
    }).toList();

    return Trip(id: id, name: name, days: tripDays);
  }
}
