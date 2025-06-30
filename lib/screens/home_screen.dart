import 'package:flutter/material.dart';
import '../services/surveycto_service.dart';
import 'package:printing/printing.dart';
import '../services/pdf_service.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _hospitalIdController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _dateController = TextEditingController();

  Map<String, dynamic>? _record;
  bool _loading = false;
  String? _error;

  String _auditType = 'Hospital and Patient Audit';

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
        // Hospital Audit: use hospital ID and date
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
                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Dropdown menu
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
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            // Dynamic form fields
                            if (_auditType == 'Hospital and Patient Audit') ...[
                              TextField(
                                controller: _hospitalIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Hospital ID',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _patientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Case NO',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ] else ...[
                              TextField(
                                controller: _hospitalIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Hospital ID',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _dateController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                onTap: () => _pickDate(context),
                              ),
                            ],
                            const SizedBox(height: 24),
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
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Fixed Download PDF button at the bottom of the card
                    if (_record != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.white,
                          ),
                          label: const Text('Download PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 15,
                            ),
                          ),
                          onPressed: () async {
                            final pdfData =
                                await PdfService.generateAuditReport(_record!);
                            await Printing.layoutPdf(
                              onLayout: (format) async => pdfData,
                            );
                          },
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
