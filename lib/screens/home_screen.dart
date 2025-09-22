import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/surveycto_service.dart';
import '../services/pdf_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _hospitalIdController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _dateController = TextEditingController();
  bool _downloading = false;
  bool _previewing = false;

  Map<String, dynamic>? _record;
  bool _loading = false;
  String? _error;

  String _auditType = 'Hospital and Patient Audit';

  // Error state variables
  String? _hospitalIdError;
  String? _patientIdError;
  String? _dateError;

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _runSearch() async {
    setState(() {
      _hospitalIdError = null;
      _patientIdError = null;
      _dateError = null;
    });

    bool hasError = false;
    if (_hospitalIdController.text.trim().isEmpty) {
      setState(() => _hospitalIdError = "Hospital ID cannot be empty");
      hasError = true;
    }
    if (_auditType == 'Hospital and Patient Audit') {
      if (_patientIdController.text.trim().isEmpty) {
        setState(() => _patientIdError = "Case No cannot be empty");
        hasError = true;
      }
    } else {
      if (_dateController.text.trim().isEmpty) {
        setState(() => _dateError = "Date cannot be empty");
        hasError = true;
      }
    }

    if (hasError) return;

    setState(() {
      _loading = true;
      _error = null;
      _record = null;
    });

    try {
      Map<String, dynamic>? record;
      if (_auditType == 'Hospital and Patient Audit') {
        record = await SurveyCTOService.findRecord(
          _hospitalIdController.text,
          _patientIdController.text,
        );
      } else {
        record = await SurveyCTOService.findRecordByHospitalAndDate(
          _hospitalIdController.text,
          _dateController.text,
        );
      }

      if (record != null) {
        setState(() {
          _record = record;
        });
      } else {
        setState(() {
          _error = "No matching record found.";
        });
      }
    } catch (e, stack) {
      print('Error: $e\n$stack');
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Preview PDF without saving
  Future<void> _previewPdf() async {
    if (_record == null) return;

    Uint8List pdfData;
    if (_auditType == 'Hospital Audit') {
      pdfData = await PdfService.generateHospitalAuditReport(_record!);
    } else {
      pdfData = await PdfService.generateAuditReport(_record!);
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/preview.pdf');
    await file.writeAsBytes(pdfData);
    await OpenFile.open(file.path, type: "application/pdf");
  }

  // Download PDF and save with hospitalId + date
  Future<void> _downloadPdf() async {
    if (_record == null) return;

    setState(() => _downloading = true);

    try {
      Uint8List pdfData;
      if (_auditType == 'Hospital Audit') {
        pdfData = await PdfService.generateHospitalAuditReport(_record!);
      } else {
        pdfData = await PdfService.generateAuditReport(_record!);
      }

      // Ask for storage permission
      if (!await Permission.storage.request().isGranted) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Permission Denied"),
            content: const Text(
              "Storage permission is required to save the PDF.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      final hospitalId = _record!['hospitalId'] ?? 'hospital';
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      final fileName = '${hospitalId}_$date.pdf';

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${downloadsDir!.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Success"),
          content: Text("PDF saved successfully!\n\nPath:\n$filePath"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(filePath, type: "application/pdf");
              },
              child: const Text("Open"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content: Text("Failed to save PDF.\n\nError: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 36, width: 36),
            const SizedBox(width: 12),
            const Text(
              'PMJAY Live Audit',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Confirm Logout"),
                  content: const Text("Are you sure you want to sign out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        "Sign Out",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Dropdown
                            DropdownButtonFormField<String>(
                              value: _auditType,
                              decoration: const InputDecoration(
                                labelText: 'Audit Type',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Hospital and Patient Audit',
                                  child: Text('Hospital and Patient Audit'),
                                ),
                                DropdownMenuItem(
                                  value: 'Hospital Audit',
                                  child: Text('Hospital Audit'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _auditType = value!;
                                  _hospitalIdController.clear();
                                  _patientIdController.clear();
                                  _dateController.clear();
                                  _record = null;
                                  _error = null;
                                  _hospitalIdError = null;
                                  _patientIdError = null;
                                  _dateError = null;
                                });
                              },
                            ),
                            const SizedBox(height: 24),

                            // Dynamic fields with errors
                            if (_auditType == 'Hospital and Patient Audit') ...[
                              TextField(
                                controller: _hospitalIdController,
                                decoration: InputDecoration(
                                  labelText: 'Hospital ID',
                                  border: const OutlineInputBorder(),
                                  errorText: _hospitalIdError,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _patientIdController,
                                decoration: InputDecoration(
                                  labelText: 'Case NO',
                                  border: const OutlineInputBorder(),
                                  errorText: _patientIdError,
                                ),
                              ),
                            ] else ...[
                              TextField(
                                controller: _hospitalIdController,
                                decoration: InputDecoration(
                                  labelText: 'Hospital ID',
                                  border: const OutlineInputBorder(),
                                  errorText: _hospitalIdError,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _dateController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Date',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                  errorText: _dateError,
                                ),
                                onTap: () => _pickDate(context),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Run button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Run'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _loading ? null : _runSearch,
                              ),
                            ),

                            if (_loading) ...[
                              const SizedBox(height: 16),
                              const CircularProgressIndicator(),
                            ],

                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],

                            if (_record != null) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Fetched Data:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 250,
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: _record!.entries
                                      .map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${e.key}: ",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text("${e.value ?? ''}"),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // PDF Buttons: Preview and Download
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.picture_as_pdf,
                                        color: Colors.white,
                                      ),
                                      label: const Text("Preview PDF"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: _previewing
                                          ? null
                                          : () async {
                                              setState(
                                                () => _previewing = true,
                                              );
                                              try {
                                                await _previewPdf(); // your existing preview function
                                              } finally {
                                                setState(
                                                  () => _previewing = false,
                                                );
                                              }
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.download,
                                        color: Colors.white,
                                      ),
                                      label: const Text("Download PDF"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: _downloading
                                          ? null
                                          : _downloadPdf,
                                    ),
                                  ),
                                ],
                              ),
                              if (_downloading || _previewing)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: LinearProgressIndicator(),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
