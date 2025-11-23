// lib/services/pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'surveycto_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

class PdfService {
  static bool _containsNonAscii(String text) {
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 127) {
        return true;
      }
    }
    return false;
  }

  static Future<Uint8List?> textToImage(String text) async {
    if (!_containsNonAscii(text)) {
      return null; // Return null for English text
    }
    // Create a ParagraphBuilder
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: 14,
              fontFamily: 'NotoSansDevanagari',
            ),
          )
          ..pushStyle(ui.TextStyle(color: const Color(0xFF000000)))
          ..addText(text);

    // Build the paragraph
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 300));

    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Paint white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 300, paragraph.height),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Draw the text
    canvas.drawParagraph(paragraph, Offset.zero);

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(300.ceil(), paragraph.height.ceil());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  /// Generates the “Checklist for Beneficiary Audit” PDF in A4 portrait.
  /// Embeds Roboto (Regular + Bold) for full Unicode support.
  static Future<Uint8List> generateAuditReport(
    Map<String, dynamic> data,
  ) async {
    final team1Text = decodeUnicode(data['team_mem_1'] as String?);
    final team2Text = decodeUnicode(data['team_mem_2'] as String?);

    final team1Image = _containsNonAscii(team1Text)
        ? await textToImage(team1Text)
        : null;
    final team2Image = _containsNonAscii(team2Text)
        ? await textToImage(team2Text)
        : null;
    // ─────────────────────────────────────────────────────────────
    // 1) Load TTF font files from assets
    // ─────────────────────────────────────────────────────────────
    final ttfRegularData = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final ttfBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final ttfRegular = pw.Font.ttf(ttfRegularData);
    final ttfBold = pw.Font.ttf(ttfBoldData);
    final notoRegularData = await rootBundle.load(
      'assets/fonts/NotoSansDevanagari-Regular.ttf',
    );
    final notoRegular = pw.Font.ttf(notoRegularData);

    // Create a ThemeData that uses Roboto as the base and bold fonts
    final theme = pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold);

    // ─────────────────────────────────────────────────────────────
    // 2) Create the PDF Document using that theme
    // ─────────────────────────────────────────────────────────────
    final pdf = pw.Document(theme: theme);

    // Helper for IST time
    String _extractTimeIst(dynamic dateField) {
      if (dateField is String) {
        // Try parsing with DateFormat for "Jul 3, 2025 6:24:00 AM"
        try {
          final dt = DateFormat('MMM d, yyyy h:mm:ss a').parseUtc(dateField);
          final ist = dt.add(const Duration(hours: 5, minutes: 30));
          return '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} IST';
        } catch (_) {
          // fallback: try default parsing
          final utc = DateTime.tryParse(dateField)?.toUtc();
          if (utc != null) {
            final ist = utc.add(const Duration(hours: 5, minutes: 30));
            return '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} IST';
          }
        }
      }
      return '';
    }

    String _formatDateTimeIst(String? dateField) {
      if (dateField == null || dateField.trim().isEmpty) return '';
      try {
        final dt = DateFormat('MMM d, yyyy h:mm:ss a').parseUtc(dateField);
        final ist = dt.add(const Duration(hours: 5, minutes: 30));
        return DateFormat('dd MMM yyyy, HH:mm').format(ist) + ' IST';
      } catch (_) {
        final utc = DateTime.tryParse(dateField)?.toUtc();
        if (utc != null) {
          final ist = utc.add(const Duration(hours: 5, minutes: 30));
          return DateFormat('dd MMM yyyy, HH:mm').format(ist) + ' IST';
        }
      }
      return dateField;
    }

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
                    if (team1Image != null)
                      pw.Image(pw.MemoryImage(team1Image), height: 20)
                    else
                      pw.Text(
                        '1. $team1Text',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    if (team2Image != null)
                      pw.Image(pw.MemoryImage(team2Image), height: 20)
                    else
                      pw.Text(
                        '2. $team2Text',
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
                            'Time: ${_extractTimeIst(data['date'])}',
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
              (() {
                final hasPackage = (data['package_name'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty;
                final yesText = hasPackage ? 'Yes' : '';
                final noText = hasPackage ? '' : 'No';
                final remarks = hasPackage
                    ? (data['package_name'] ?? '')
                    : (data['package_name_re'] ?? '');
                return pw.TableRow(
                  children: [
                    _buildChecklistCell('1'),
                    _buildChecklistCell(
                      'PACKAGE BOOKED (Mention the name of Package Booked)',
                      wrap: true,
                    ),
                    _buildChecklistCell(yesText),
                    _buildChecklistCell(noText),
                    _buildChecklistCell(remarks.toString(), wrap: true),
                  ],
                );
              })(),

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
                value: _formatDateTimeIst(data['admis_date_time'] as String?),
                remark: data['admis_date_time_re'] as String?,
                isBoolean: false,
              ),

              // 5. Date and time of discharge as per the hospital file
              _buildChecklistRow(
                5,
                'Date and time of discharge as per the hospital file',
                value: _formatDateTimeIst(data['dis_date_time'] as String?),
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
              (() {
                final othRemarks = (data['oth_remarks_re'] ?? '')
                    .toString()
                    .trim();
                final hasRemark = othRemarks.isNotEmpty;
                return pw.TableRow(
                  children: [
                    _buildChecklistCell('23'),
                    _buildChecklistCell(
                      'Any other remark or observation',
                      wrap: true,
                    ),
                    _buildChecklistCell(hasRemark ? 'Yes' : ''),
                    _buildChecklistCell(hasRemark ? '' : 'No'),
                    _buildChecklistCell(
                      hasRemark ? othRemarks : '',
                      wrap: true,
                    ),
                  ],
                );
              })(),
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
              (() {
                final tick = (data['patient_photo'] ?? '').toString().isNotEmpty
                    ? 'Yes'
                    : 'No';
                return pw.TableRow(
                  children: [
                    _buildChecklistCell('1'),
                    _buildChecklistCell(
                      'Patient photo with PMJAY card',
                      wrap: true,
                    ),
                    _buildChecklistCell(tick),
                    _buildChecklistCell(
                      data['patient_photo_re'] ?? '',
                      wrap: true,
                    ),
                  ],
                );
              })(),

              // 2. Patient PMJAY card
              (() {
                final tick = (data['pmjay_card'] ?? '').toString().isNotEmpty
                    ? 'Yes'
                    : 'No';
                return pw.TableRow(
                  children: [
                    _buildChecklistCell('2'),
                    _buildChecklistCell('Patient PMJAY card', wrap: true),
                    _buildChecklistCell(tick),
                    _buildChecklistCell(
                      data['pmjay_card_re'] ?? '',
                      wrap: true,
                    ),
                  ],
                );
              })(),

              // 3. Admission slip / Discharge summary sheet (if any)
              _buildAttachedDocRow(
                3,
                'Admission slip / Discharge summary sheet (if any)',
                data['admission_slip'] as String?,
                data['discharge_summary'] as String?,
                documentType: 'admission',
                remark: (data['admission_slip_re'] ?? '').toString().isNotEmpty
                    ? data['admission_slip_re'] as String?
                    : (data['discharge_summary_re'] ?? '').toString().isNotEmpty
                    ? data['discharge_summary_re'] as String?
                    : null,
              ),

              // 4. In case of out-of-pocket expenses:\n If any money taken, a) attached receipt proof, b) Written and signed…
              (() {
                // Check if any out-of-pocket expense index exists
                bool hasOutPocketExpense = false;
                int index = 1;
                while (true) {
                  final indexKey = 'out_pocket_ex_index_$index';
                  if (!data.containsKey(indexKey)) break;
                  if ((data[indexKey] ?? '').toString().isNotEmpty) {
                    hasOutPocketExpense = true;
                    break;
                  }
                  index++;
                }
                final outPocket = hasOutPocketExpense ? 'Yes' : 'No';

                // Check for receipt proofs (indexed)
                bool hasReceiptProof = false;
                index = 1;
                while (true) {
                  final receiptKey = 'receipt_oope_$index';
                  if (!data.containsKey(receiptKey)) break;
                  if ((data[receiptKey] ?? '').toString().isNotEmpty) {
                    hasReceiptProof = true;
                    break;
                  }
                  index++;
                }
                final receiptOope = hasReceiptProof ? 'a) Yes' : 'a) No';
                final receiptRemarkText = (data['oope_receipts_re'] ?? '')
                    .toString()
                    .trim();
                final receiptRemark = receiptRemarkText.isNotEmpty
                    ? 'a) $receiptRemarkText'
                    : '';

                // Check for written complaint or video recording
                final hasWrittenComplaint =
                    (data['written_complaint_oope'] ?? '')
                        .toString()
                        .isNotEmpty;
                final hasVideoComplaint = (data['video_complaint_oope'] ?? '')
                    .toString()
                    .isNotEmpty;
                final complaintStatus =
                    (hasWrittenComplaint || hasVideoComplaint)
                    ? 'b) Yes'
                    : 'b) No';

                final complaintRemarkText = (data['add_proof_oope_re'] ?? '')
                    .toString()
                    .trim();
                final complaintRemark = complaintRemarkText.isNotEmpty
                    ? 'b) $complaintRemarkText'
                    : '';

                final tickCell = '$outPocket\n$receiptOope\n$complaintStatus';
                final remarksCell =
                    '$receiptRemark${receiptRemark.isNotEmpty && complaintRemark.isNotEmpty ? '\n' : ''}$complaintRemark';

                return pw.TableRow(
                  children: [
                    _buildChecklistCell('4'),
                    _buildChecklistCell(
                      'In case of out-of-pocket expenses:\n'
                      'If any money taken,\n'
                      'a) attached receipt proof,\n'
                      'b) Written and signed (or thumb impression)/video recording in cases of complaints of the beneficiary/attendant along with a witness (Contact numbers are also required)',
                      wrap: true,
                    ),
                    _buildChecklistCell(tickCell, wrap: true),
                    _buildChecklistCell(
                      remarksCell,
                      wrap: true,
                      isRemark: true,
                    ),
                  ],
                );
              })(),
              // 5. Pharmacy register
              (() {
                bool hasPharmReg = false;
                int idx = 1;
                while (true) {
                  final key = 'pharm_reg_$idx';
                  if (!data.containsKey(key)) break;
                  if ((data[key] ?? '').toString().isNotEmpty) {
                    hasPharmReg = true;
                    break;
                  }
                  idx++;
                }
                final tick = hasPharmReg ? 'Yes' : 'No';
                final remark = (data['pharm_reg_re'] ?? '').toString();
                return pw.TableRow(
                  children: [
                    _buildChecklistCell('5'),
                    _buildChecklistCell(
                      'Visit the pharmacy and check the registers for the medicines dispensed',
                      wrap: true,
                    ),
                    _buildChecklistCell(tick),
                    _buildChecklistCell(remark, wrap: true, isRemark: true),
                  ],
                );
              })(),
              // 6. Lab register/X ray/USG
              (() {
                bool hasLabReg = false;
                int idx = 1;
                while (true) {
                  final key = 'lab_reg_$idx';
                  if (!data.containsKey(key)) break;
                  if ((data[key] ?? '').toString().isNotEmpty) {
                    hasLabReg = true;
                    break;
                  }
                  idx++;
                }
                final tick = hasLabReg ? 'Yes' : 'No';
                final remark = (data['lab_reg_re'] ?? '').toString();
                return pw.TableRow(
                  children: [
                    _buildChecklistCell('6'),
                    _buildChecklistCell(
                      'Check the lab registers/X ray, USG for the sample collected and reports of the beneficiaries',
                      wrap: true,
                    ),
                    _buildChecklistCell(tick),
                    _buildChecklistCell(remark, wrap: true, isRemark: true),
                  ],
                );
              })(),
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

          // SIGNIFICANT FINDINGS
          pw.Text(
            'Significant Findings:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 10),
          pw.Text(data['sig_find'] ?? '', style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 20),

          // RECOMMENDATIONS
          pw.Text(
            'Recommendations:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 10),
          pw.Text(data['recomm'] ?? '', style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 20),

          // Signature line
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
    final List<Map<String, dynamic>> imageFields = [
      {
        'heading': 'Patient photo with PMJAY card',
        'baseKey': 'patient_photo',
        'hasMultiple': false,
      },
      {
        'heading': 'Patient PMJAY card',
        'baseKey': 'pmjay_card',
        'hasMultiple': false,
      },
      {
        'heading': 'Admission slip',
        'baseKey': 'admission_slip_yes',
        'hasMultiple': true,
      },
      {
        'heading': 'Discharge Summary Sheet',
        'baseKey': 'discharge_summary_yes',
        'hasMultiple': true,
      },
      {
        'heading': 'Receipt proof (out-of-pocket expenses)',
        'baseKey': 'receipt_oope',
        'hasMultiple': true,
      },
      {
        'heading': 'Complaint proof (out-of-pocket expenses)',
        'baseKeys': ['written_complaint_oope', 'video_complaint_oope'],
        'hasMultiple': false,
        'type': 'complaint',
      },
      {
        'heading': 'Pharmacy register',
        'baseKey': 'pharm_reg',
        'hasMultiple': true,
      },
      {
        'heading': 'Lab register/X ray/USG',
        'baseKey': 'lab_reg',
        'hasMultiple': true,
      },
    ];

    // final List<Map<String, dynamic>> fetchedImages = [];
    final List<String> missingImages = [];
    for (final field in imageFields) {
      final heading = field['heading'] as String;
      final baseKey = field['baseKeys'] ?? field['baseKey'];
      final hasMultiple = field['hasMultiple'] as bool;
      final type = field['type'] as String?;

      final urls = getImageUrls(data, baseKey, hasMultiple, type: type);

      if (urls.isEmpty) {
        missingImages.add(heading);
        continue;
      }

      // Add index to heading for multiple images
      for (int i = 0; i < urls.length; i++) {
        final url = urls[i];
        final indexedHeading = hasMultiple ? '$heading (${i + 1})' : heading;

        final Uint8List? imgBytes = await SurveyCTOService.fetchImageBytes(url);

        if (imgBytes != null && _isSupportedImage(imgBytes)) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 20,
              ),
              build: (context) {
                final availableWidth = PdfPageFormat.a4.availableWidth - 40;
                final availableHeight = PdfPageFormat.a4.availableHeight - 80;

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      indexedHeading, // Use the indexed heading here
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(imgBytes),
                        width: availableWidth,
                        height: availableHeight,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }
      }
    }

    // Add a final page for missing images
    if (missingImages.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Missing Attachments',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(),
                children: missingImages
                    .map(
                      (heading) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(heading),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('No image provided'),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  static List<String> getImageUrls(
    Map<String, dynamic> data,
    dynamic baseKey,
    bool hasMultiple, {
    String? type,
  }) {
    // Handle complaint proof special case
    if (type == 'complaint') {
      final urls = <String>[];
      final baseKeys = baseKey as List<String>;

      for (final key in baseKeys) {
        final url = data[key]?.toString() ?? '';
        if (url.isNotEmpty) {
          urls.add(url);
        }
      }
      return urls;
    }

    // Original logic for other fields
    if (!hasMultiple) {
      final url = data[baseKey as String]?.toString() ?? '';
      return url.isNotEmpty ? [url] : [];
    }

    final urls = <String>[];
    var index = 1;
    while (true) {
      final imageKey = '${baseKey as String}_$index';
      final imageUrl = data[imageKey]?.toString() ?? '';
      if (imageUrl.isEmpty) break;
      urls.add(imageUrl);
      index++;
    }
    return urls;
  }

  static Future<Uint8List> generateHospitalAuditReport(
    Map<String, dynamic> data,
  ) async {
    final team1Text = decodeUnicode(data['team_mem_1'] as String?);
    final team2Text = decodeUnicode(data['team_mem_2'] as String?);

    final team1Image = _containsNonAscii(team1Text)
        ? await textToImage(team1Text)
        : null;
    final team2Image = _containsNonAscii(team2Text)
        ? await textToImage(team2Text)
        : null;
    // Load fonts
    final ttfRegularData = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final ttfBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final ttfRegular = pw.Font.ttf(ttfRegularData);
    final ttfBold = pw.Font.ttf(ttfBoldData);
    final notoRegularData = await rootBundle.load(
      'assets/fonts/NotoSansDevanagari-Regular.ttf',
    );
    final notoRegular = pw.Font.ttf(notoRegularData);
    final theme = pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold);

    // Helper for IST time
    String _extractTimeIst(dynamic dateField) {
      if (dateField is String) {
        try {
          final dt = DateFormat('MMM d, yyyy h:mm:ss a').parseUtc(dateField);
          final ist = dt.add(const Duration(hours: 5, minutes: 30));
          return '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} IST';
        } catch (_) {
          final utc = DateTime.tryParse(dateField)?.toUtc();
          if (utc != null) {
            final ist = utc.add(const Duration(hours: 5, minutes: 30));
            return '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} IST';
          }
        }
      }
      return '';
    }

    String _extractDatePart(dynamic dateField) {
      if (dateField is String) {
        final parts = dateField.split(' ');
        if (parts.length >= 4) {
          return parts.sublist(0, parts.length - 2).join(' ');
        }
      }
      return dateField?.toString() ?? '';
    }

    String na() => 'N/A';

    // Checklist questions
    final checklistQuestions = [
      'PACKAGE BOOKED (Mention the name of Package Booked)',
      'Name of the treating Doctor',
      'Specialization of the treating doctor',
      'Date and time of admission as per the hospital file',
      'Date and time of discharge as per the hospital file',
      'Type of treatment (Medical/Surgical)',
      'Expected length of stay',
      'Patient Ids collected',
      'Patient photograph collected',
      'What were the complaints presented at the time of admission?',
      'Since when is he/she suffering from the symptoms',
      'Was he/she referring from another hospital/clinic/doctor?',
      'If yes, please name the hospital/clinic/doctor',
      'When did the patient get admitted?',
      'Is the patient admitted since then?',
      'What diagnostic tests (if any) were performed on the patient?',
      'Was any surgery conducted for the patient?',
      'If yes, is there a scar on the body?',
      'Has any money been charged so far?',
      'If yes, how much?',
      'Do they have receipts of the same',
      'Is there any previous hospitalization of same patient at the same hospital?',
      'Any other remark or observation',
    ];

    // Additional details questions
    final additionalDetailsQuestions = [
      'Is patients name/age in-door records, E card and investigation reports same',
      'Are presenting symptoms matching the diagnosis',
      'Is the package booked matching the diagnosis',
      'Are investigation reports matching the diagnosis?',
      'Are investigation reports signed by doctor/pathologist with registration no.',
    ];

    // Attached documents
    final attachedDocuments = [
      'Patient photo with PMJAY card',
      'Patient PMJAY card',
      'Admission slip / Discharge summary sheet (if any)',
      'In case of out-of-pocket expenses:\nIf any money taken,\na) attached receipt proof,\nb) Written and signed (or thumb impression)/video recording in cases of complaints of the beneficiary/attendant along with a witness (Contact numbers are also required)',
      'Visit the pharmacy and check the registers for the medicines dispensed',
      'Check the lab registers/X ray, USG for the sample collected and reports of the beneficiaries',
    ];

    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        build: (context) => [
          // HEADER
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Checklist for Beneficiary Audit\n(Live Audit–During Hospitalization)',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),

          // TEAM INFORMATION
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                    if (team1Image != null)
                      pw.Image(pw.MemoryImage(team1Image), height: 20)
                    else
                      pw.Text(
                        '1. $team1Text',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    if (team2Image != null)
                      pw.Image(pw.MemoryImage(team2Image), height: 20)
                    else
                      pw.Text(
                        '2. $team2Text',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
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
                            'Time: ${_extractTimeIst(data['date'])}',
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

          // HOSPITAL & PATIENT INFORMATION (4 columns)
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
              _buildLabelValueRow('CASE NO', na(), 'CARD NO', na()),
              _buildLabelValueRow(
                'HOSPITAL CONTACT NO',
                data['hosp_contact'],
                'PATIENT NAME',
                na(),
              ),
              _buildLabelValueRow(
                'PATIENT ADDRESS',
                na(),
                'PATIENT/ATTENDANT CONTACT NO',
                na(),
              ),
              _buildLabelValueRow('DIAGNOSIS', na(), 'TREATMENT PLAN', na()),
            ],
          ),
          pw.SizedBox(height: 12),

          // CHECKLIST TABLE (5 columns)
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(2.5),
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
              for (int i = 0; i < checklistQuestions.length; i++)
                pw.TableRow(
                  children: [
                    _buildChecklistCell((i + 1).toString()),
                    _buildChecklistCell(checklistQuestions[i], wrap: true),
                    _buildChecklistCell('N/A'),
                    _buildChecklistCell('N/A'),
                    _buildChecklistCell('', wrap: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ADDITIONAL DETAILS (4 columns)
          pw.Text(
            'ADDITIONAL DETAILS:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
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
              for (int i = 0; i < additionalDetailsQuestions.length; i++)
                pw.TableRow(
                  children: [
                    _buildChecklistCell((i + 1).toString()),
                    _buildChecklistCell(
                      additionalDetailsQuestions[i],
                      wrap: true,
                    ),
                    _buildChecklistCell('N/A'),
                    _buildChecklistCell('N/A'),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ATTACHED DOCUMENTS (4 columns)
          pw.Text(
            'Attached following documents along with audit report:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.5),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(2),
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
              for (int i = 0; i < attachedDocuments.length; i++)
                pw.TableRow(
                  children: [
                    _buildChecklistCell((i + 1).toString()),
                    _buildChecklistCell(attachedDocuments[i], wrap: true),
                    _buildChecklistCell('N/A'),
                    _buildChecklistCell('', wrap: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),

          // “Whether Case is Genuine (YES/NO)” + Signature
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
                '', // Leave empty
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // SIGNIFICANT FINDINGS
          // SIGNIFICANT FINDINGS
          pw.Text(
            'Significant Findings:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 10),
          pw.Text(data['sig_find'] ?? '', style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 20),

          // RECOMMENDATIONS
          pw.Text(
            'Recommendations:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 10),
          pw.Text(data['recomm'] ?? '', style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 20),

          // Signature line
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

    return pdf.save();
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
  // static String _extractTimePart(dynamic dateField) {
  //   if (dateField is String) {
  //     final parts = dateField.split(' ');
  //     if (parts.length >= 2) {
  //       // Join only the last two tokens (time + AM/PM)
  //       return parts.sublist(parts.length - 2).join(' ');
  //     }
  //   }
  //   return '';
  // }

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
    bool isRemark = false, // Add this parameter
  }) {
    // Show dash for empty remarks
    final displayText = (isRemark && text.isEmpty) ? '-' : text;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        displayText,
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
        _buildChecklistCell(remarkText, wrap: true, isRemark: true),
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
    String? firstValue,
    String? secondValue, {
    String? documentType = 'default',
    String? remark, // added
  }) {
    bool hasFirstDoc = false;
    bool hasSecondDoc = false;

    switch (documentType) {
      case 'admission':
        // For Admission slip / Discharge summary
        hasFirstDoc =
            firstValue != null &&
            firstValue.toString().isNotEmpty &&
            firstValue != '0'; // admission_slip
        hasSecondDoc =
            secondValue != null &&
            secondValue.toString().isNotEmpty &&
            secondValue != '0'; // discharge_summary
        break;

      case 'complaint':
        // For Written and signed / video recording
        hasFirstDoc =
            firstValue != null &&
            firstValue.toString().isNotEmpty &&
            firstValue != '0'; // complaint_written
        hasSecondDoc =
            secondValue != null &&
            secondValue.toString().isNotEmpty &&
            secondValue != '0'; // complaint_video
        break;

      default:
        hasFirstDoc =
            firstValue != null &&
            firstValue.toString().isNotEmpty &&
            firstValue != '0';
        hasSecondDoc = false;
    }

    // If either exists, show Yes
    final tickText = (hasFirstDoc || hasSecondDoc) ? 'Yes' : 'No';

    return pw.TableRow(
      children: [
        _buildChecklistCell(srNo.toString()),
        _buildChecklistCell(documentName, wrap: true),
        _buildChecklistCell(tickText),
        // use provided remark (may be null) and mark it as remark cell
        _buildChecklistCell(remark ?? '', wrap: true, isRemark: true),
      ],
    );
  }

  static String decodeUnicode(String? input) {
    if (input == null) return '';
    return input.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (Match m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
  }
}
