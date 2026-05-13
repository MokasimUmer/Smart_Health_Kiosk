import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'language_service.dart';

class ApiService {
  static Future<Map<String, dynamic>> uploadSubscriptionReceipt({
    required Uint8List receiptBytes,
    required String receiptFilename,
    required double amount,
    required String paymentMethod,
  }) async {
    final base = await AuthService.baseUrl;
    final uri = Uri.parse('$base/subscriptions');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll({'Authorization': 'Bearer ${await AuthService.getToken()}'})
      ..fields['amount'] = amount.toString()
      ..fields['paymentMethod'] = paymentMethod
      ..files.add(http.MultipartFile.fromBytes('receipt', receiptBytes, filename: receiptFilename));
    final res = await req.send();
    return jsonDecode(await res.stream.bytesToString());
  }

  static Future<Map<String, dynamic>> getMySubscription() async {
    final base = await AuthService.baseUrl;
    final res = await http.get(
      Uri.parse('$base/subscriptions/mine'),
      headers: AuthService.headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createMeasurement({
    required String kioskId,
    required Map<String, dynamic> vitals,
  }) async {
    final base = await AuthService.baseUrl;
    final res = await http.post(
      Uri.parse('$base/measurements'),
      headers: AuthService.headers,
      body: jsonEncode({'kioskId': kioskId, 'vitals': vitals}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> analyzeAndSuggest({
    required String measurementId,
    required double latitude,
    required double longitude,
  }) async {
    await AuthService.getToken(); // ensure token loaded so headers include Bearer
    final base = await AuthService.baseUrl;

    // Send the current app language so Gemini replies in the same language
    final language = LanguageService.instance.currentCode; // 'en' | 'am' | 'om'

    final res = await http.post(
      Uri.parse('$base/measurements/analyze'),
      headers: AuthService.headers,
      body: jsonEncode({
        'measurementId': measurementId,
        'latitude': latitude,
        'longitude': longitude,
        'language': language,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Analysis failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> uploadAppointmentReceipt({
    required Uint8List receiptBytes,
    required String receiptFilename,
    required String hospitalId,
    required String measurementId,
    String? aiInsightId,
    required double bookingFee,
    required String paymentMethod,
    required String conditionLabel,
  }) async {
    final base = await AuthService.baseUrl;
    final uri = Uri.parse('$base/appointments');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll({'Authorization': 'Bearer ${await AuthService.getToken()}'})
      ..fields['hospitalId'] = hospitalId
      ..fields['measurementId'] = measurementId
      ..fields['bookingFee'] = bookingFee.toString()
      ..fields['paymentMethod'] = paymentMethod
      ..fields['conditionLabel'] = conditionLabel
      ..files.add(http.MultipartFile.fromBytes('receipt', receiptBytes, filename: receiptFilename));
    if (aiInsightId != null) req.fields['aiInsightId'] = aiInsightId;
    final res = await req.send();
    return jsonDecode(await res.stream.bytesToString());
  }

  static Future<Map<String, dynamic>> getMyAppointments() async {
    final base = await AuthService.baseUrl;
    final res = await http.get(
      Uri.parse('$base/appointments/mine'),
      headers: AuthService.headers,
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getMyMeasurements() async {
    final base = await AuthService.baseUrl;
    final res = await http.get(
      Uri.parse('$base/measurements/mine'),
      headers: AuthService.headers,
    );
    return jsonDecode(res.body);
  }
}
