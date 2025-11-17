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

  // Fetch hospitals for a given date
  static Future<List<Map<String, dynamic>>> fetchHospitalsByDate(
    String date,
  ) async {
    final data = await fetchFormData();
    final hospitals = <String, Map<String, dynamic>>{};
    for (final entry in data) {
      // Parse date to yyyy-MM-dd
      final entryDateRaw = (entry['date'] ?? '').toString().trim();
      String entryDate = '';
      if (entryDateRaw.isNotEmpty) {
        try {
          final dt = DateFormat(
            'MMM d, yyyy h:mm:ss a',
          ).parse(entryDateRaw, true).toLocal();
          entryDate = DateFormat('yyyy-MM-dd').format(dt);
        } catch (_) {
          final dt = DateTime.tryParse(entryDateRaw);
          if (dt != null) {
            entryDate = DateFormat('yyyy-MM-dd').format(dt);
          }
        }
      }
      if (entryDate == date.trim()) {
        final hospitalId = (entry['hospital_id'] ?? '').toString().trim();
        final hospitalName = (entry['hospital_name'] ?? '').toString().trim();
        if (hospitalId.isNotEmpty && hospitalName.isNotEmpty) {
          hospitals[hospitalId] = {
            'hospital_id': hospitalId,
            'hospital_name': hospitalName,
          };
        }
      }
    }
    return hospitals.values.toList();
  }

  // Fetch patient IDs and audit type for a hospital and date
  static Future<List<Map<String, String>>> fetchPatientIdsOrAuditType(
    String hospitalId,
    String date,
  ) async {
    final data = await fetchFormData();
    final patientMap = <String, Map<String, String>>{};
    bool hasHospitalAuditOnly = false;

    for (final entry in data) {
      final entryHospitalId = (entry['hospital_id'] ?? '').toString().trim();
      final entryCaseNo = (entry['case_no'] ?? '').toString().trim();
      final entryPatientName = (entry['patient_name'] ?? '').toString().trim();
      final entryDateRaw = (entry['date'] ?? '').toString().trim();

      String entryDate = '';
      if (entryDateRaw.isNotEmpty) {
        try {
          final dt = DateFormat(
            'MMM d, yyyy h:mm:ss a',
          ).parse(entryDateRaw, true).toLocal();
          entryDate = DateFormat('yyyy-MM-dd').format(dt);
        } catch (_) {
          final dt = DateTime.tryParse(entryDateRaw);
          if (dt != null) {
            entryDate = DateFormat('yyyy-MM-dd').format(dt);
          }
        }
      }

      if (entryHospitalId == hospitalId.trim() && entryDate == date.trim()) {
        if (entryCaseNo.isNotEmpty) {
          // Create a unique key combining case_no and patient_name
          final displayText = entryPatientName.isNotEmpty
              ? '$entryCaseNo - $entryPatientName'
              : entryCaseNo;
          patientMap[displayText] = {
            'case_no': entryCaseNo,
            'patient_name': entryPatientName,
            'display': displayText,
          };
        } else {
          hasHospitalAuditOnly = true;
        }
      }
    }

    final result = patientMap.values.toList();

    if (hasHospitalAuditOnly) {
      result.add({
        'case_no': '',
        'patient_name': '',
        'display': 'Hospital Audit Only',
      });
    }

    return result;
  }

  // Fetch record for Hospital Audit Only
  static Future<Map<String, dynamic>?> findHospitalAudit(
    String hospitalId,
    String date,
  ) async {
    final data = await fetchFormData();
    for (final entry in data) {
      final entryHospitalId = (entry['hospital_id'] ?? '').toString().trim();
      final entryPatientId = (entry['patient_id'] ?? '').toString().trim();
      final entryCaseNo = (entry['case_no'] ?? '').toString().trim();
      final entryDateRaw = (entry['date'] ?? '').toString().trim();
      String entryDate = '';
      if (entryDateRaw.isNotEmpty) {
        try {
          final dt = DateFormat(
            'MMM d, yyyy h:mm:ss a',
          ).parse(entryDateRaw, true).toLocal();
          entryDate = DateFormat('yyyy-MM-dd').format(dt);
        } catch (_) {
          final dt = DateTime.tryParse(entryDateRaw);
          if (dt != null) {
            entryDate = DateFormat('yyyy-MM-dd').format(dt);
          }
        }
      }
      if (entryHospitalId == hospitalId.trim() &&
          entryDate == date.trim() &&
          entryPatientId.isEmpty &&
          entryCaseNo.isEmpty) {
        return _normalizeRecord(entry);
      }
    }
    return null;
  }

  // Fetch record for Hospital and Patient Audit
  static Future<Map<String, dynamic>?> findHospitalPatientAudit(
    String hospitalId,
    String patientId,
    String date,
  ) async {
    final data = await fetchFormData();
    for (final entry in data) {
      final entryHospitalId = (entry['hospital_id'] ?? '').toString().trim();
      final entryCaseNo = (entry['case_no'] ?? '').toString().trim();
      final entryDateRaw = (entry['date'] ?? '').toString().trim();
      String entryDate = '';
      if (entryDateRaw.isNotEmpty) {
        try {
          final dt = DateFormat(
            'MMM d, yyyy h:mm:ss a',
          ).parse(entryDateRaw, true).toLocal();
          entryDate = DateFormat('yyyy-MM-dd').format(dt);
        } catch (_) {
          final dt = DateTime.tryParse(entryDateRaw);
          if (dt != null) {
            entryDate = DateFormat('yyyy-MM-dd').format(dt);
          }
        }
      }
      if (entryHospitalId == hospitalId.trim() &&
          entryDate == date.trim() &&
          entryCaseNo == patientId.trim()) {
        return _normalizeRecord(entry);
      }
    }
    return null;
  }

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

  static String _convertToIST(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return "";

    try {
      // Example SurveyCTO date format: "Jul 10, 2025 5:26:00 AM"
      final dt = DateFormat("MMM d, yyyy h:mm:ss a").parse(rawDate, true);
      final istTime = dt.add(const Duration(hours: 5, minutes: 30));
      return DateFormat("yyyy-MM-dd HH:mm").format(istTime);
    } catch (_) {
      // fallback: try default parsing
      final dt = DateTime.tryParse(rawDate);
      if (dt != null) {
        final istTime = dt.add(const Duration(hours: 5, minutes: 30));
        return DateFormat("yyyy-MM-dd HH:mm").format(istTime);
      }
    }

    return rawDate; // return as-is if parsing failed
  }

  static Map<String, dynamic> _normalizeRecord(Map<String, dynamic> record) {
    final normalized = <String, dynamic>{};
    record.forEach((key, value) {
      if (value is String &&
          (key.toLowerCase().contains("date") ||
              key.toLowerCase().contains("time"))) {
        normalized[key] = _convertToIST(value);
      } else {
        normalized[key] = value;
      }
    });
    return normalized;
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
        return _normalizeRecord(entry);
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
        return _normalizeRecord(entry);
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
