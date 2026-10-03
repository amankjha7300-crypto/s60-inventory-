import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';

class StudentImportScreen extends StatefulWidget {
  const StudentImportScreen({super.key});

  @override
  State<StudentImportScreen> createState() => _StudentImportScreenState();
}

class _StudentImportScreenState extends State<StudentImportScreen> {
  final TextEditingController _csvController = TextEditingController(
    text: """Student ID,Name,Roll Number,Email,Phone,Batch,Semester
S60-181,Harshit Mehta,24CSE181,harshit@sviet.ac.in,9876500181,2026,3
S60-182,Kritika Verma,24CSE182,kritika@sviet.ac.in,9876500182,2026,3
S60-183,Devansh Gupta,23CSE183,devansh@sviet.ac.in,9876500183,2025,5"""
  );

  bool _isImporting = false;
  Map<String, dynamic>? _importResult;

  Future<void> _handleImport() async {
    final lines = _csvController.text.trim().split('\n');
    if (lines.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide CSV rows with headers.')));
      return;
    }

    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    List<Map<String, dynamic>> studentsToImport = [];

    // Skip header line
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length >= 3) {
        studentsToImport.add({
          'student_id': parts[0].trim(),
          'name': parts[1].trim(),
          'roll_number': parts[2].trim(),
          'email': parts.length > 3 ? parts[3].trim() : null,
          'phone': parts.length > 4 ? parts[4].trim() : null,
          'batch': parts.length > 5 ? parts[5].trim() : '2025',
          'semester': parts.length > 6 ? int.tryParse(parts[6].trim()) ?? 3 : 3,
        });
      }
    }

    try {
      final res = await ApiService().bulkImportStudents(studentsToImport);
      setState(() {
        _isImporting = false;
        _importResult = res;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusDistributed,
            content: Text("Import complete: ${res['imported_count']} imported, ${res['skipped_count']} skipped."),
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.statusOutOfStock, content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bulk Student Import', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 20),
                      SizedBox(width: 8),
                      Text("CSV Template Format", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryNavy)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Columns: Student ID, Name, Roll Number, Email, Phone, Batch, Semester",
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _csvController,
                    maxLines: 10,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Paste CSV content here...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isImporting ? null : _handleImport,
                    icon: _isImporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.upload),
                    label: Text(_isImporting ? "Processing..." : "Validate & Import Students"),
                  ),
                ],
              ),
            ),
            if (_importResult != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Import Results", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy)),
                    const SizedBox(height: 8),
                    Text("Successfully Imported: ${_importResult!['imported_count']}", style: const TextStyle(color: AppColors.statusDistributed, fontWeight: FontWeight.bold)),
                    Text("Skipped / Duplicates: ${_importResult!['skipped_count']}", style: const TextStyle(color: AppColors.statusPending)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
