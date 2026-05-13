import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Default to current PC IP. Can be overridden in-app via Settings.
  static const String _defaultPcIp = '192.168.137.1';
  static const String _ipPrefKey = 'server_ip';

  static String? _cachedIp;

  static Future<String> getServerIp() async {
    if (_cachedIp != null) return _cachedIp!;
    final prefs = await SharedPreferences.getInstance();
    _cachedIp = prefs.getString(_ipPrefKey) ?? _defaultPcIp;
    return _cachedIp!;
  }

  static Future<void> setServerIp(String ip) async {
    _cachedIp = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipPrefKey, ip);
  }

  static Future<String> get _baseUrl async {
    if (kIsWeb) return 'http://localhost:5000/api';
    final ip = await getServerIp();
    return 'http://$ip:5000/api';
  }

  static String? _token;
  static Map<String, dynamic>? _patient;

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final patientJson = prefs.getString('patient');
    if (patientJson != null) _patient = jsonDecode(patientJson);
    return _token;
  }

  static Map<String, dynamic>? get patient => _patient;

  static Future<String> get baseUrl => _baseUrl;

  /// Base URL for uploads (e.g. hospital photos): same host as API but without /api.
  /// Uses the cached IP synchronously — call getServerIp() at least once before using this.
  static String get uploadsBase {
    final ip = _cachedIp ?? _defaultPcIp;
    if (kIsWeb) return 'http://localhost:5000';
    return 'http://$ip:5000';
  }

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String phone,
    required String password,
    double? latitude,
    double? longitude,
  }) async {
    final base = await _baseUrl;
    final res = await http.post(
      Uri.parse('$base/auth/patient/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
        'latitude': latitude ?? 0,
        'longitude': longitude ?? 0,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      await _saveAuth(data['token'], data['patient']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final base = await _baseUrl;
    final res = await http.post(
      Uri.parse('$base/auth/patient/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      await _saveAuth(data['token'], data['patient']);
    }
    return data;
  }

  static Future<void> _saveAuth(String token, Map<String, dynamic> patient) async {
    _token = token;
    _patient = patient;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('patient', jsonEncode(patient));
  }

  static Future<void> logout() async {
    _token = null;
    _patient = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('patient');
  }

  static Future<Map<String, dynamic>> fetchMe() async {
    await getToken(); // ensure token is loaded
    final base = await _baseUrl;
    final res = await http.get(
      Uri.parse('$base/auth/me'),
      headers: headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      _patient = data['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('patient', jsonEncode(_patient));
    }
    return data;
  }
}
