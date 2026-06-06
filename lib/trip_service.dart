import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

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
      if (startDate.isEmpty || endDate.isEmpty) return 0;
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
      if (filterWords.contains(p.toLowerCase())) return false;
      return true;
    }).map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase()).toList();
    if (filtered.isEmpty) return raw.replaceAll('_', ' ');
    return filtered.join(' ');
  }

  String get displayName => _cleanTripName(name);
}

class TripService {
  static Future<List<TripMeta>> fetchIndex({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cached = prefs.getString('index_cache');
      if (cached != null) return _parseIndex(cached);
    }

    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/whoeverb/Trip_Companion/main/trips/index.json'));
      if (response.statusCode == 200) {
        await prefs.setString('index_cache', response.body);
        return _parseIndex(response.body);
      }
    } catch (e) {
      // Fallback to cache
    }

    final cached = prefs.getString('index_cache');
    if (cached != null) return _parseIndex(cached);
    
    throw Exception('Failed to fetch index and no cache available');
  }

  static Future<Trip> fetchTrip(TripMeta meta, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'trip_${meta.file}';

    if (!forceRefresh) {
      final cached = prefs.getString(key);
      if (cached != null) return _parseTrip(cached, meta.name, meta.file);
    }

    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/whoeverb/Trip_Companion/main/trips/${meta.file}'));
      if (response.statusCode == 200) {
        await prefs.setString(key, response.body);
        return _parseTrip(response.body, meta.name, meta.file);
      }
    } catch (e) {
      // Fallback to cache
    }

    final cached = prefs.getString(key);
    if (cached != null) return _parseTrip(cached, meta.name, meta.file);

    throw Exception('Failed to fetch trip and no cache available');
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
      String day = row['Day']?.toString() ?? '';
      String date = row['Date']?.toString() ?? '';
      String time = row['Time']?.toString() ?? '';
      String title = row['Title']?.toString() ?? '';
      String type = row['Type']?.toString() ?? '';
      String loc = row['Location']?.toString() ?? "";
      String addr = row['Address']?.toString() ?? "";
      String note = row['Note']?.toString() ?? "";

      String dayKey = "$day|$date";
      daysOrder.add(dayKey);

      if (loc.isNotEmpty) {
        locationMap.putIfAbsent(dayKey, () => {}).add(loc);
      }

      if (type.toLowerCase() == 'lodging') {
        lodgingMap[dayKey] = [title, addr];
      }
      dayEventsMap
          .putIfAbsent(dayKey, () => [])
          .add(Event(time, title, type, loc, addr, note));
    }

    List<String> sortedDays = daysOrder.toList()..sort();
    List<TripDay> tripDays = sortedDays.map((key) {
      var parts = key.split('|');
      var lodgingData = lodgingMap[key] ?? ['', ''];

      return TripDay(
        date: parts[1],
        lodgingTitle: lodgingData[0],
        lodgingAddress: lodgingData[1],
        locations: locationMap[key] ?? {},
        events: dayEventsMap[key] ?? [],
      );
    }).toList();

    return Trip(id: id, name: name, days: tripDays);
  }
}
