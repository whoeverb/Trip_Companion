import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const int _ttlHours = 24;

  static String _tsKey(String key) => '${key}__ts';

  static Future<void> set(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    await prefs.setString(_tsKey(key), DateTime.now().toIso8601String());
  }

  static Future<String?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_tsKey(key));
    if (ts == null) return null;
    final saved = DateTime.tryParse(ts);
    if (saved == null) return null;
    if (DateTime.now().difference(saved).inHours >= _ttlHours) return null;
    return prefs.getString(key);
  }

  static Future<String?> getStale(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<bool> isValid(String key) async {
    return (await get(key)) != null;
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(_tsKey(key));
  }
}
