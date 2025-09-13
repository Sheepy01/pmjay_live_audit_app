import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

class SurveyCTOService {
  static String? _server;
  static String? _formId;
  static String? _username;
  static String? _password;

  /// Load credentials from Firestore once
  static Future<void> loadCredentials() async {
    if (_server != null) return; // already loaded

    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('surveycto')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      _server = data['server'];
      _formId = data['formId'];
      _username = data['username'];
      _password = data['password'];
    } else {
      throw Exception("SurveyCTO config not found in Firestore");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchFormData() async {
    await loadCredentials();
    final url = Uri.https(_server!, '/api/v1/forms/data/wide/json/$_formId');
    final response = await http.get(
      url,
      headers: {
        'Authorization':
            'Basic ' + base64Encode(utf8.encode('$_username:$_password')),
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch data: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>?> findRecord(
    String hospitalId,
    String caseNo,
  ) async {
    final data = await fetchFormData();
    for (final entry in data) {
      if ((entry['hospital_id'] ?? '').toString().trim() == hospitalId.trim() &&
          (entry['case_no'] ?? '').toString().trim() == caseNo.trim()) {
        return entry;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> findRecordByHospitalAndDate(
    String hospitalId,
    String date,
  ) async {
    final data = await fetchFormData();
    for (final entry in data) {
      final entryHospitalId = (entry['hospital_id'] ?? '').toString().trim();
      final entryDateRaw = (entry['date'] ?? '').toString().trim();

      String entryDate = '';
      if (entryDateRaw.isNotEmpty) {
        try {
          // Parse SurveyCTO date string like "Jul 10, 2025 5:26:00 AM"
          final dt = DateFormat(
            'MMM d, yyyy h:mm:ss a',
          ).parse(entryDateRaw, true).toLocal();
          entryDate = DateFormat('yyyy-MM-dd').format(dt);
        } catch (_) {
          // fallback: try default parsing
          final dt = DateTime.tryParse(entryDateRaw);
          if (dt != null) {
            entryDate = DateFormat('yyyy-MM-dd').format(dt);
          }
        }
      }

      if (entryHospitalId == hospitalId.trim() && entryDate == date.trim()) {
        return entry;
      }
    }
    return null;
  }

  static Future<Uint8List?> fetchImageBytes(String? url) async {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == '0') return null;

    await loadCredentials(); // ensures server/username/password are loaded
    if (_username == null || _password == null) {
      throw Exception("SurveyCTO credentials not loaded");
    }

    final authHeader =
        'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

    try {
      final response = await http.get(
        Uri.parse(trimmed),
        headers: {'Authorization': authHeader},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print(
          "Image fetch failed: ${response.statusCode} ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      print("Error fetching image: $e");
    }

    return null;
  }
}
