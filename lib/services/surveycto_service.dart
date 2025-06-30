import 'dart:convert';
import 'package:http/http.dart' as http;

class SurveyCTOService {
  static const String _server = "adri.surveycto.com";
  static const String _formId = "Live_Audit_During_Hospitalization";
  static const String _username = "adri.project@adriindia.org";
  static const String _password = "Adri@2025";

  static Future<List<Map<String, dynamic>>> fetchFormData() async {
    final url = Uri.https(_server, '/api/v1/forms/data/wide/json/$_formId');
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

      // Extract only the date part (yyyy-MM-dd) for comparison
      String entryDate = '';
      if (entryDateRaw.isNotEmpty) {
        // Try to parse and format to yyyy-MM-dd
        try {
          final parts = entryDateRaw.split(' ');
          if (parts.isNotEmpty) {
            entryDate = parts[0];
          }
        } catch (_) {}
      }

      if (entryHospitalId == hospitalId.trim() && entryDate == date.trim()) {
        return entry;
      }
    }
    return null;
  }
}
