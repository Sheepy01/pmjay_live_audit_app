// lib/services/pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'dart:convert';

class PdfService {
  /// Generates the “Checklist for Beneficiary Audit” PDF in A4 portrait.
  /// Embeds Roboto (Regular + Bold) for full Unicode support.
  static Future<Uint8List> generateAuditReport(
    Map<String, dynamic> data,
  ) async {
    // ─────────────────────────────────────────────────────────────
    // 1) Load TTF font files from assets
    // ─────────────────────────────────────────────────────────────
    final ttfRegularData = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final ttfBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final ttfRegular = pw.Font.ttf(ttfRegularData);
    final ttfBold = pw.Font.ttf(ttfBoldData);

    // Create a ThemeData that uses Roboto as the base and bold fonts
    final theme = pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold);

    // ─────────────────────────────────────────────────────────────
    // 2) Create the PDF Document using that theme
    // ─────────────────────────────────────────────────────────────
    final pdf = pw.Document(theme: theme);

    // ─────────────────────────────────────────────────────────────
    // 3) Build the PDF page(s)
    // ─────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        build: (context) => [
          // ──────────────────────────────────────────────────────────
          // HEADER: Title only (no logo)
          // ──────────────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Checklist for Beneficiary Audit\n(Live Audit–During Hospitalization)',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          // ──────────────────────────────────────────────────────────
          // TEAM INFORMATION: “Name of the Team Members” (left)  +  “Team No/Date/Time” (right bordered)
          // ──────────────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Name of Team Members (no border)
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Name of the Team Members:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '1. ${data['team_mem_1'] ?? ''}',
                      style: pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      '2. ${data['team_mem_2'] ?? ''}',
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              // Right: Bordered table for Team No, Date, Time
              pw.Expanded(
                flex: 1,
                child: pw.Table(
                  border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Team No.: ${data['team_no'] ?? ''}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Date: ${_extractDatePart(data['date'])}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Time: ${_extractTimePart(data['date'])}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ──────────────────────────────────────────────────────────
          // HOSPITAL & PATIENT INFORMATION (4 columns)
          // ──────────────────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              _buildLabelValueRow(
                'HOSPITAL NAME',
                data['hospital_name'],
                'HOSPITAL ID',
                data['hospital_id'],
              ),
              _buildLabelValueRow(
                'CASE NO',
                data['case_no'],
                'CARD NO',
                data['card_no'],
              ),
              _buildLabelValueRow(
                'HOSPITAL CONTACT NO',
                data['hosp_contact_no'],
                'PATIENT NAME',
                data['patient_name'],
              ),
              _buildLabelValueRow(
                'PATIENT ADDRESS',
                data['patient_add'],
                'PATIENT/ATTENDANT CONTACT NO',
                data['patient_contact'],
              ),
              _buildLabelValueRow(
                'DIAGNOSIS',
                data['diagnosis'],
                'TREATMENT PLAN',
                data['treatment_plan'],
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ──────────────────────────────────────────────────────────
          // CHECKLIST TABLE (5 columns) – no separate heading
          // ──────────────────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6), // Sr. No.
              1: pw.FlexColumnWidth(3), // Particulars
              2: pw.FlexColumnWidth(1), // YES
              3: pw.FlexColumnWidth(1), // NO
              4: pw.FlexColumnWidth(2.5), // REMARKS
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildChecklistCell('Sr. No.', bold: true),
                  _buildChecklistCell('Particulars', bold: true),
                  _buildChecklistCell('YES', bold: true),
                  _buildChecklistCell('NO', bold: true),
                  _buildChecklistCell('REMARKS', bold: true),
                ],
              ),

              // 1. PACKAGE BOOKED
              _buildChecklistRow(
                1,
                'PACKAGE BOOKED (Mention the name of Package Booked)',
                value: data['package_name'] as String?,
                remark: data['package_name_re'] as String?,
                isBoolean: false,
              ),

              // 2. Name of the treating Doctor
              _buildChecklistRow(
                2,
                'Name of the treating Doctor',
                value: data['treat_doc_name'] as String?,
                remark: data['treat_doc_name_re'] as String?,
                isBoolean: false,
              ),

              // 3. Specialization of the treating doctor
              _buildChecklistRow(
                3,
                'Specialization of the treating doctor',
                value: data['treat_doc_spec'] as String?,
                remark: data['treat_doc_spec_re'] as String?,
                isBoolean: false,
              ),

              // 4. Date and time of admission as per the hospital file
              _buildChecklistRow(
                4,
                'Date and time of admission as per the hospital file',
                value: data['admis_date_time'] as String?,
                remark: data['admis_date_time_re'] as String?,
                isBoolean: false,
              ),

              // 5. Date and time of discharge as per the hospital file
              _buildChecklistRow(
                5,
                'Date and time of discharge as per the hospital file',
                value: data['dis_date_time'] as String?,
                remark: data['dis_date_time_re'] as String?,
                isBoolean: false,
              ),

              // 6. Type of treatment (Medical/Surgical)
              _buildChecklistRow(
                6,
                'Type of treatment (Medical/Surgical)',
                value: _mapTreatmentType(data['treatment_type'] as String?),
                remark: data['treatment_type_re'] as String?,
                isBoolean: false,
              ),

              // 7. Expected length of stay
              _buildChecklistRow(
                7,
                'Expected length of stay',
                value: data['length_stay'] as String?,
                remark: data['length_stay_re'] as String?,
                isBoolean: false,
              ),

              // 8. Patient Ids collected (0/1)
              _buildChecklistRow(
                8,
                'Patient Ids collected',
                value: data['patient_id'] as String?,
                remark: data['patient_id_re'] as String?,
                isBoolean: true,
              ),

              // 9. Patient photograph collected (0/1)
              _buildChecklistRow(
                9,
                'Patient photograph collected',
                value: data['patient_pho'] as String?,
                remark: data['patient_pho_re'] as String?,
                isBoolean: true,
              ),

              // 10. What were the complaints presented at the time of admission?
              _buildChecklistRow(
                10,
                'What were the complaints presented at the time of admission?',
                value: data['admission_comp'] as String?,
                remark: data['admission_comp_re'] as String?,
                isBoolean: false,
              ),

              // 11. Since when is he/she suffering from the symptoms
              _buildChecklistRow(
                11,
                'Since when is he/she suffering from the symptoms',
                value: data['symp_time'] as String?,
                remark: data['symp_time_re'] as String?,
                isBoolean: false,
              ),

              // 12. Was he/she referring from another hospital/clinic/doctor? (0/1)
              _buildChecklistRow(
                12,
                'Was he/she referring from another hospital/clinic/doctor?',
                value: data['refer_hosp'] as String?,
                remark: data['refer_hosp_re'] as String?,
                isBoolean: true,
              ),

              // 13. If yes, please name the hospital/clinic/doctor
              _buildChecklistRow(
                13,
                'If yes, please name the hospital/clinic/doctor',
                value: data['refer_doc_name'] as String?,
                remark: data['refer_doc_name_re'] as String?,
                isBoolean: false,
              ),

              // 14. When did the patient get admitted?
              _buildChecklistRow(
                14,
                'When did the patient get admitted?',
                value: data['patient_add_date'] as String?,
                remark: data['patient_add_date_re'] as String?,
                isBoolean: false,
              ),

              // 15. Is the patient admitted since then? (0/1)
              _buildChecklistRow(
                15,
                'Is the patient admitted since then?',
                value: data['patient_admit_now'] as String?,
                remark: data['patient_admit_now_re'] as String?,
                isBoolean: true,
              ),

              // 16. What diagnostic tests (if any) were performed on the patient?
              _buildChecklistRow(
                16,
                'What diagnostic tests (if any) were performed on the patient?',
                value: data['diag_test'] as String?,
                remark: data['diag_test_re'] as String?,
                isBoolean: false,
              ),

              // 17. Was any surgery conducted for the patient? (0/1)
              _buildChecklistRow(
                17,
                'Was any surgery conducted for the patient?',
                value: data['surgery_con'] as String?,
                remark: data['surgery_con_re'] as String?,
                isBoolean: true,
              ),

              // 18. If yes, is there a scar on the body? (0/1)
              _buildChecklistRow(
                18,
                'If yes, is there a scar on the body?',
                value: data['surgery_scar'] as String?,
                remark: data['surgery_scar_re'] as String?,
                isBoolean: true,
              ),

              // 19. Has any money been charged so far? (0/1)
              _buildChecklistRow(
                19,
                'Has any money been charged so far?',
                value: data['money_charge'] as String?,
                remark: data['money_charge_re'] as String?,
                isBoolean: true,
              ),

              // 20. If yes, how much?
              _buildChecklistRow(
                20,
                'If yes, how much?',
                value: data['money_charge_yes'] as String?,
                remark: data['money_charge_yes_re'] as String?,
                isBoolean: false,
              ),

              // 21. Do they have receipts of the same (0/1)
              _buildChecklistRow(
                21,
                'Do they have receipts of the same',
                value: data['receipts'] as String?,
                remark: data['receipts_re'] as String?,
                isBoolean: true,
              ),

              // 22. Is there any previous hospitalization of same patient at the same hospital? (0/1)
              _buildChecklistRow(
                22,
                'Is there any previous hospitalization of same patient at the same hospital?',
                value: data['prev_hospitalization'] as String?,
                remark: data['prev_hospitalization_re'] as String?,
                isBoolean: true,
              ),

              // 23. Any other remark or observation
              _buildChecklistRow(
                23,
                'Any other remark or observation',
                value: data['oth_remarks'] as String?,
                remark: '',
                isBoolean: false,
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ──────────────────────────────────────────────────────────
          // ADDITIONAL DETAILS (4 columns)
          // ──────────────────────────────────────────────────────────
          pw.Text(
            'ADDITIONAL DETAILS:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6), // Sr. No.
              1: pw.FlexColumnWidth(4), // Particulars
              2: pw.FlexColumnWidth(1), // YES
              3: pw.FlexColumnWidth(1), // NO
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildChecklistCell('Sr. No.', bold: true),
                  _buildChecklistCell('Particulars', bold: true),
                  _buildChecklistCell('YES', bold: true),
                  _buildChecklistCell('NO', bold: true),
                ],
              ),

              // 1. Is patients name/age in-door records, E card and investigation reports same
              _buildAdditionalDetailsRow(
                1,
                'Is patients name/age in-door records, E card and investigation reports same',
                data['name_age_check'] as String?,
              ),

              // 2. Are presenting symptoms matching the diagnosis
              _buildAdditionalDetailsRow(
                2,
                'Are presenting symptoms matching the diagnosis',
                data['symp_diag'] as String?,
              ),

              // 3. Is the package booked matching the diagnosis
              _buildAdditionalDetailsRow(
                3,
                'Is the package booked matching the diagnosis',
                data['pack_diag'] as String?,
              ),

              // 4. Are investigation reports matching the diagnosis?
              _buildAdditionalDetailsRow(
                4,
                'Are investigation reports matching the diagnosis?',
                data['investigation_diag'] as String?,
              ),

              // 5. Are investigation reports signed by doctor/pathologist with registration no.
              _buildAdditionalDetailsRow(
                5,
                'Are investigation reports signed by doctor/pathologist with registration no.',
                data['Investi_repo_sign'] as String?,
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ──────────────────────────────────────────────────────────
          // ATTACHED DOCUMENTS (4 columns)
          // ──────────────────────────────────────────────────────────
          pw.Text(
            'Attached following documents along with audit report:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.5), // S. No.
              1: pw.FlexColumnWidth(3.5), // Document name
              2: pw.FlexColumnWidth(1), // Tick
              3: pw.FlexColumnWidth(2), // Remarks
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildChecklistCell('S. No.', bold: true),
                  _buildChecklistCell('Document name', bold: true),
                  _buildChecklistCell('Tick', bold: true),
                  _buildChecklistCell('Remarks', bold: true),
                ],
              ),

              // 1. Patient photo with PMJAY card
              _buildAttachedDocRow(
                1,
                'Patient photo with PMJAY card',
                data['patient_photo'] as String?,
                remark: data['patient_photo_re'] as String?,
              ),

              // 2. Patient PMJAY card
              _buildAttachedDocRow(
                2,
                'Patient PMJAY card',
                data['pmjay_card'] as String?,
                remark: data['pmjay_card_re'] as String?,
              ),

              // 3. Admission slip / Discharge summary sheet (if any)
              _buildAttachedDocRow(
                3,
                'Admission slip / Discharge summary sheet (if any)',
                data['admission_slip'] as String?,
                remark: data['admission_slip_yes'] as String?,
              ),

              // 4. In case of out-of-pocket expenses:\n If any money taken, a) attached receipt proof, b) Written and signed…
              pw.TableRow(
                children: [
                  _buildChecklistCell('4'),
                  _buildChecklistCell(
                    'In case of out-of-pocket expenses:\n'
                    'If any money taken,\n'
                    'a) attached receipt proof,\n'
                    'b) Written and signed (or thumb impression)/video recording in cases of complaints of the beneficiary/attendant along with a witness (Contact numbers are also required)',
                    wrap: true,
                  ),
                  _buildChecklistCell(
                    (data['out_pocket_ex'] as String? ?? '') == '1'
                        ? 'Yes'
                        : 'No',
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'a) ${(data['receipt_oope'] as String? ?? '') == '1' ? 'Yes' : 'No'}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'b) ${(data['complaint_oope'] as String? ?? '') == '1' ? 'Yes' : 'No'}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 5. Visit the pharmacy and check the registers for the medicines dispensed
              _buildAttachedDocRow(
                5,
                'Visit the pharmacy and check the registers for the medicines dispensed',
                data['pharm_reg'] as String?,
                remark: data['pharm_reg_re'] as String?,
              ),

              // 6. Check the lab registers/X ray, USG for the sample collected and reports of the beneficiaries
              _buildAttachedDocRow(
                6,
                'Check the lab registers/X ray, USG for the sample collected and reports of the beneficiaries',
                data['lab_reg'] as String?,
                remark: data['lab_reg_re'] as String?,
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ──────────────────────────────────────────────────────────
          // “Whether Case is Genuine (YES/NO)” + White‐space for text + Signature
          // ──────────────────────────────────────────────────────────
          pw.Row(
            children: [
              pw.Text(
                'Whether Case is Genuine (YES/NO): ',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.Text(
                (data['case_genuine'] as String? ?? '') == '1' ? 'Yes' : 'No',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // White space area for “Significant Findings”
          pw.Text(
            'Significant Findings:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(
            height: 40,
          ), // leave blank white space (about 40 points high)

          pw.Text(
            'Recommendations:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(
            height: 40,
          ), // leave blank white space (about 40 points high)
          // Signature line (blank)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Signature of Team members: ______________________',
                style: pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );

    // Define which JSON fields map to which headings:
    final List<Map<String, String>> imageFields = [
      {'heading': 'Patient photo with PMJAY card', 'key': 'patient_photo'},
      {'heading': 'Patient PMJAY card', 'key': 'pmjay_card'},
      {'heading': 'Admission slip', 'key': 'admission_slip_yes'},
      {
        'heading': 'Receipt proof (out-of-pocket expenses)',
        'key': 'receipt_oope',
      },
      {
        'heading': 'Complaint proof (out-of-pocket expenses)',
        'key': 'complaint_oope',
      },
      {'heading': 'Pharmacy register', 'key': 'pharm_reg'},
      {'heading': 'Lab register/X ray/USG', 'key': 'lab_reg'},
    ];

    // (4) PRE-FETCH all image bytes
    final List<Map<String, dynamic>> fetchedImages = [];
    for (final field in imageFields) {
      final heading = field['heading']!;
      final keyName = field['key']!;
      final rawUrl = data[keyName] as String?;
      final Uint8List? imgBytes = await _fetchImageBytes(rawUrl);
      fetchedImages.add({'heading': heading, 'bytes': imgBytes});
    }

    // (5) Build page 3 if we have at least one valid image
    final bool hasAnyImage = fetchedImages.any((row) => row['bytes'] != null);
    if (hasAnyImage) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          build: (context) {
            final List<pw.TableRow> rows = [];
            for (final row in fetchedImages) {
              final heading = row['heading'] as String;
              final bytes = row['bytes'] as Uint8List?;

              // ←⎯⎯⎯ Add this guard: only insert valid PNG/JPEG
              if (bytes != null && _isSupportedImage(bytes)) {
                rows.add(
                  pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          heading,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(
                          pw.MemoryImage(bytes),
                          width: 90,
                          height: 90,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // even if bytes is null OR not a valid image, still add a row with “No image provided”
                rows.add(
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          heading,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          '(No image provided)',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                rows.add(
                  pw.TableRow(
                    children: [
                      pw.SizedBox(height: 12),
                      pw.SizedBox(height: 12),
                    ],
                  ),
                );
              }
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Attached Images',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                if (rows.isEmpty)
                  pw.Text('(No images to display)')
                else
                  pw.Table(
                    border: pw.TableBorder.all(
                      width: 0.5,
                      color: PdfColors.grey,
                    ),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(2),
                      1: pw.FlexColumnWidth(5),
                    },
                    children: rows,
                  ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static final String _basicAuthCredentials =
      'Basic ${base64Encode(utf8.encode('adri.project@adriindia.org:Adri@2025'))}';

  static Future<Uint8List?> _fetchImageBytes(String? url) async {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == '0') return null;

    try {
      final response = await http.get(
        Uri.parse(trimmed),
        headers: {'Authorization': _basicAuthCredentials},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {
      // ignore errors
    }
    return null;
  }

  /// Returns true if [bytes] begin with a known PNG or JPEG signature.
  static bool _isSupportedImage(Uint8List bytes) {
    // PNG: 0x89 0x50 0x4E 0x47
    if (bytes.length > 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // JPEG: 0xFF 0xD8 … 0xFF 0xD9
    if (bytes.length > 2 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[bytes.length - 1] == 0xD9) {
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // Helper: Extract only the “YYYY-MM-DD” part from “YYYY-MM-DD HH:MM:SS”
  static String _extractDatePart(dynamic dateField) {
    if (dateField is String) {
      final parts = dateField.split(' ');
      if (parts.length >= 4) {
        // Join everything except the last two tokens (time + AM/PM)
        return parts.sublist(0, parts.length - 2).join(' ');
      }
    }
    return dateField?.toString() ?? '';
  }

  // ─────────────────────────────────────────────────────────────
  // Helper: Extract the “HH:MM:SS” (or “HH:MM”) part from “YYYY-MM-DD HH:MM:SS”
  static String _extractTimePart(dynamic dateField) {
    if (dateField is String) {
      final parts = dateField.split(' ');
      if (parts.length >= 2) {
        // Join only the last two tokens (time + AM/PM)
        return parts.sublist(parts.length - 2).join(' ');
      }
    }
    return '';
  }

  // ─────────────────────────────────────────────────────────────
  // Map '0' → 'Medical', '1' → 'Surgical'
  static String? _mapTreatmentType(String? raw) {
    if (raw == '0') return 'Medical';
    if (raw == '1') return 'Surgical';
    return raw;
  }

  // ─────────────────────────────────────────────────────────────
  // Builds one row of the 4‐column Label/Value table
  static pw.TableRow _buildLabelValueRow(
    String label1,
    String? value1,
    String label2,
    String? value2,
  ) {
    return pw.TableRow(
      children: [
        _buildLabelCell(label1),
        _buildValueCell(value1),
        _buildLabelCell(label2),
        _buildValueCell(value2),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Label cells (bold, size 11)
  static pw.Widget _buildLabelCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Value cells (regular, size 11)
  static pw.Widget _buildValueCell(String? text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text ?? '', style: const pw.TextStyle(fontSize: 11)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Builds a single cell in a checklist/additional/attachment table.
  // If [bold] is true, text is bold. If [wrap] is true, allow multi‐line wrap.
  static pw.Widget _buildChecklistCell(
    String text, {
    bool bold = false,
    bool wrap = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: wrap ? null : 1,
        softWrap: wrap,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHECKLIST row: SrNo | Particulars | YES/NO | REMARKS
  // If isBoolean=true, we interpret value='0'/'1' and put “Yes” or “No” in the correct column.
  // If isBoolean=false, we put the value text directly into REMARKS.
  static pw.TableRow _buildChecklistRow(
    int srNo,
    String particular, {
    required String? value,
    required String? remark,
    required bool isBoolean,
  }) {
    String yesText = '';
    String noText = '';
    String remarkText = (remark ?? '').trim();

    if (isBoolean) {
      if (value == '1')
        yesText = 'Yes';
      else if (value == '0')
        noText = 'No';
    } else {
      // Non-boolean → entire “value” goes into REMARKS
      remarkText = (value ?? '').trim();
    }

    return pw.TableRow(
      children: [
        _buildChecklistCell(srNo.toString()),
        _buildChecklistCell(particular, wrap: true),
        _buildChecklistCell(yesText),
        _buildChecklistCell(noText),
        _buildChecklistCell(remarkText),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ADDITIONAL DETAILS row: SrNo | Particulars | YES | NO
  static pw.TableRow _buildAdditionalDetailsRow(
    int srNo,
    String particular,
    String? boolValue,
  ) {
    String yesText = '';
    String noText = '';
    if (boolValue == '1')
      yesText = 'Yes';
    else if (boolValue == '0')
      noText = 'No';

    return pw.TableRow(
      children: [
        _buildChecklistCell(srNo.toString()),
        _buildChecklistCell(particular, wrap: true),
        _buildChecklistCell(yesText),
        _buildChecklistCell(noText),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ATTACHED DOCUMENT row: S.No. | Document name | Tick (Yes/No) | Remarks
  static pw.TableRow _buildAttachedDocRow(
    int srNo,
    String documentName,
    String? tickValue, {
    String? remark = '',
  }) {
    String tickText = '';
    if (tickValue == '1')
      tickText = 'Yes';
    else if (tickValue == '0')
      tickText = 'No';

    return pw.TableRow(
      children: [
        _buildChecklistCell(srNo.toString()),
        _buildChecklistCell(documentName, wrap: true),
        _buildChecklistCell(tickText),
        _buildChecklistCell(remark ?? ''),
      ],
    );
  }
}
