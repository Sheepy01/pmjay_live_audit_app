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
  DateTime? _selectedDate;
  String? _selectedHospitalId;
  String? _selectedHospitalName;
  String? _selectedPatientIdOrAuditType;
  String? _hospitalError;
  String? _patientError;

  final TextEditingController _dateController = TextEditingController();

  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, String>> _patientIdsOrAuditTypes = [];

  bool _loadingHospitals = false;
  bool _loadingPatients = false;
  bool _loading = false;
  bool _downloading = false;
  bool _previewing = false;

  Map<String, dynamic>? _record;
  String? _error;

  late final AnimationController _dotsController;
  Animation<int>? _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _dotsAnimation = StepTween(begin: 0, end: 3).animate(_dotsController);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _dotsController.dispose();
    _dotsAnimation = null;
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        _selectedHospitalId = null;
        _selectedHospitalName = null;
        _selectedPatientIdOrAuditType = null;
        _hospitals = [];
        _patientIdsOrAuditTypes = [];
        _record = null;
        _error = null;
        _loadingHospitals = true;
        _hospitalError = null;
        _patientError = null;
      });
      try {
        final hospitals = await SurveyCTOService.fetchHospitalsByDate(
          _dateController.text,
        );
        setState(() {
          _hospitals = hospitals;
          _loadingHospitals = false;
          _hospitalError = hospitals.isEmpty
              ? "No hospitals found for the selected date."
              : null;
        });
      } catch (e) {
        setState(() {
          _hospitalError = "Error fetching hospitals: $e";
          _loadingHospitals = false;
        });
      }
    }
  }

  Future<void> _onHospitalSelected(String? hospitalId) async {
    final hospital = _hospitals.firstWhere(
      (h) => h['hospital_id'] == hospitalId,
      orElse: () => {},
    );
    setState(() {
      _selectedHospitalId = hospitalId;
      _selectedHospitalName = hospital['hospital_name'];
      _selectedPatientIdOrAuditType = null;
      _patientIdsOrAuditTypes = [];
      _record = null;
      _error = null;
      _loadingPatients = true;
      _patientError = null;
    });
    try {
      final patientIdsOrAuditTypes =
          await SurveyCTOService.fetchPatientIdsOrAuditType(
            hospitalId!,
            _dateController.text,
          );
      setState(() {
        _patientIdsOrAuditTypes = patientIdsOrAuditTypes;
        _loadingPatients = false;
        _patientError = patientIdsOrAuditTypes.isEmpty
            ? "No patient IDs or audits found for the selected hospital and date."
            : null;
      });
    } catch (e) {
      setState(() {
        _patientError = "Error fetching patient IDs: $e";
        _loadingPatients = false;
      });
    }
  }

  Future<void> _runSearch() async {
    setState(() {
      _record = null;
      _error = null;
      _loading = true;
    });
    try {
      Map<String, dynamic>? record;

      final selectedItem = _patientIdsOrAuditTypes.firstWhere(
        (item) => item['display'] == _selectedPatientIdOrAuditType,
        orElse: () => {},
      );

      if (_selectedPatientIdOrAuditType == 'Hospital Audit Only') {
        record = await SurveyCTOService.findHospitalAudit(
          _selectedHospitalId!,
          _dateController.text,
        );
      } else {
        record = await SurveyCTOService.findHospitalPatientAudit(
          _selectedHospitalId!,
          selectedItem['case_no']!,
          _dateController.text,
        );
      }
      setState(() {
        _record = record;
        _error = record == null
            ? "No record found for the selected options."
            : null;
      });
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _previewPdf() async {
    if (_record == null) return;
    setState(() => _previewing = true);
    try {
      Uint8List pdfData;
      if (_selectedPatientIdOrAuditType == 'Hospital Audit Only') {
        pdfData = await PdfService.generateHospitalAuditReport(_record!);
      } else {
        pdfData = await PdfService.generateAuditReport(_record!);
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/preview.pdf');
      await file.writeAsBytes(pdfData);
      await OpenFile.open(file.path, type: "application/pdf");
    } finally {
      setState(() => _previewing = false);
    }
  }

  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return false;
    } else {
      return true;
    }
  }

  Future<void> _downloadPdf() async {
    if (_record == null) return;
    final hasPermission = await _checkStoragePermission();
    if (!hasPermission) {
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
    setState(() => _downloading = true);
    try {
      Uint8List pdfData;
      if (_selectedPatientIdOrAuditType == 'Hospital Audit Only') {
        pdfData = await PdfService.generateHospitalAuditReport(_record!);
      } else {
        pdfData = await PdfService.generateAuditReport(_record!);
      }
      final hospitalId =
          (_record!['hospital_id'] ?? '').toString().trim().isNotEmpty
          ? (_record!['hospital_id'] ?? 'hospital').toString()
          : (_record!['hospital_id_manual'] ?? 'hospital').toString();

      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      // Generate unique filename if file already exists
      String fileName = '${hospitalId}_$date.pdf';
      String filePath = '${downloadsDir!.path}/$fileName';
      File file = File(filePath);

      int counter = 1;
      while (file.existsSync()) {
        // If file exists, append timestamp or counter to filename
        final timestamp = DateFormat('HHmmss').format(DateTime.now());
        fileName = '${hospitalId}_${date}_${timestamp}_($counter).pdf';
        filePath = '${downloadsDir.path}/$fileName';
        file = File(filePath);
        counter++;
      }

      await file.writeAsBytes(pdfData);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Success"),
          content: Text(
            "PDF saved successfully!\n\nFilename: $fileName\n\nPath:\n$filePath",
          ),
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
                            // Date Picker
                            TextField(
                              readOnly: true,
                              controller: _dateController,
                              decoration: const InputDecoration(
                                labelText: 'Select Date',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              onTap: () => _pickDate(context),
                            ),
                            const SizedBox(height: 16),
                            // Hospital Dropdown
                            if (_hospitalError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  _hospitalError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            DropdownButtonFormField<String>(
                              value: _hospitals.isEmpty
                                  ? null
                                  : _selectedHospitalId,
                              decoration: const InputDecoration(
                                labelText: 'Select Hospital',
                                border: OutlineInputBorder(),
                              ),
                              items: _hospitals
                                  .map(
                                    (hosp) => DropdownMenuItem<String>(
                                      value: hosp['hospital_id']?.toString(),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width *
                                            0.6, // optional
                                        child: Text(
                                          hosp['hospital_name']?.toString() ??
                                              '',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  (_selectedDate != null && !_loadingHospitals)
                                  ? (value) => _onHospitalSelected(value)
                                  : null,
                            ),
                            if (_loadingHospitals)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: LinearProgressIndicator(),
                              ),
                            const SizedBox(height: 16),
                            // Patient ID / Audit Type Dropdown
                            if (_patientError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  _patientError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            DropdownButtonFormField<String>(
                              value: _patientIdsOrAuditTypes.isEmpty
                                  ? null
                                  : _selectedPatientIdOrAuditType,
                              decoration: const InputDecoration(
                                labelText: 'Select Case No / Audit Type',
                                border: OutlineInputBorder(),
                              ),
                              items: _patientIdsOrAuditTypes
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item['display']!,
                                      child: Text(
                                        item['display']!,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        softWrap: false,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  (_selectedHospitalId != null &&
                                      !_loadingPatients)
                                  ? (value) {
                                      setState(() {
                                        _selectedPatientIdOrAuditType = value;
                                        _record = null;
                                        _error = null;
                                      });
                                    }
                                  : null,
                            ),
                            if (_loadingPatients)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: LinearProgressIndicator(),
                              ),
                            const SizedBox(height: 24),
                            // Run Button
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
                                onPressed:
                                    (_selectedDate != null &&
                                        _selectedHospitalId != null &&
                                        _selectedPatientIdOrAuditType != null &&
                                        !_loading)
                                    ? _runSearch
                                    : null,
                              ),
                            ),
                            if (_loading) ...[
                              const SizedBox(height: 16),
                              const LinearProgressIndicator(),
                              if (_dotsAnimation != null)
                                AnimatedBuilder(
                                  animation: _dotsAnimation!,
                                  builder: (context, child) {
                                    final dots =
                                        '.' * (_dotsAnimation!.value + 1);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'Generating PDF$dots',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
                                          : _previewPdf,
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
