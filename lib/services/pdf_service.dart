import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfService {
  static Future<Uint8List> generateAuditReport(
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();
    final logoBytes = await rootBundle.load('assets/logo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Image(logo, width: 60, height: 60),
              pw.SizedBox(width: 16),
              pw.Text(
                'PMJAY Live Audit Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Field', 'Value'],
            data: data.entries
                .map((e) => [e.key, (e.value ?? '').toString()])
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    return pdf.save();
  }
}
