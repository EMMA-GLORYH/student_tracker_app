import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'device_student.dart';

class UploadBulkStudentsPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final String adminId;

  const UploadBulkStudentsPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.adminId,
  });

  @override
  State<UploadBulkStudentsPage> createState() => _UploadBulkStudentsPageState();
}

class _UploadBulkStudentsPageState extends State<UploadBulkStudentsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isParsing = false;
  bool _isUploading = false;
  String? _fileName;
  List<Map<String, dynamic>> _parsedStudents = [];
  List<Map<String, dynamic>> _validStudents = [];
  List<Map<String, dynamic>> _invalidStudents = [];
  List<String> _duplicateIds = [];
  int _uploadedCount = 0;
  int _failedCount = 0;
  bool _uploadComplete = false;

  late AnimationController _dotsController;

  // 🎨 PROFESSIONAL NAVY BLUE COLOR SCHEME
  static const Color navyDark = Color(0xFF0A1929);
  static const Color navyPrimary = Color(0xFF1e3a5f);
  static const Color navyBlue = Color(0xFF2563eb);
  static const Color navyButton = Color(0xFF1e40af);
  static const Color accentGreen = Color(0xFF10b981);
  static const Color accentRed = Color(0xFFef4444);
  static const Color accentOrange = Color(0xFFf59e0b);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color cardWhite = Colors.white;

  final List<String> _requiredColumns = [
    'firstName',
    'lastName',
    'dateOfBirth',
    'gender',
    'class',
    'guardianName',
    'guardianPhone',
    'emergencyContact',
  ];

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: const Text(
          'Bulk Student Upload',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_uploadComplete)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.devices),
                onPressed: _navigateToDeviceAssignment,
                tooltip: 'Assign Devices',
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadTemplate,
              tooltip: 'Download Template',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _parsedStudents.isEmpty ? _buildUploadSection() : _buildPreviewSection(),

          // ✅ PROFESSIONAL 3-DOT LOADING OVERLAY
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.60),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _dotsController,
                      builder: (context, child) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            final delay = index * 0.2;
                            final value = (_dotsController.value + delay) % 1.0;
                            final offset = (value < 0.5
                                ? value * 2
                                : (1 - value) * 2) * 18;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Transform.translate(
                                offset: Offset(0, -offset),
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: index == 1
                                          ? [navyDark, navyBlue]
                                          : [navyBlue, Colors.white],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: navyBlue.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading $_uploadedCount of ${_validStudents.length}...',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 250,
                      child: LinearProgressIndicator(
                        value: _uploadedCount / _validStudents.length,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _uploadComplete
          ? FloatingActionButton.extended(
        onPressed: _navigateToDeviceAssignment,
        backgroundColor: navyButton,
        icon: const Icon(Icons.devices),
        label: const Text('Assign Devices'),
      )
          : null,
    );
  }

  Widget _buildUploadSection() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildInstructionsCard(),
            const SizedBox(height: 32),
            _buildUploadCard(),
            const SizedBox(height: 24),
            _buildSampleFormatCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navyDark.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [navyDark, navyBlue],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: navyDark.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'How to Upload Students',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: navyDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInstructionStep('1', 'Download the template file'),
          _buildInstructionStep('2', 'Fill in student information'),
          _buildInstructionStep('3', 'Save as CSV or Excel file'),
          _buildInstructionStep('4', 'Upload the completed file'),
          _buildInstructionStep('5', 'Review and confirm upload'),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [navyDark, navyBlue],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: navyDark.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: navyDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: navyBlue.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: navyDark.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [navyDark.withOpacity(0.1), navyBlue.withOpacity(0.1)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload,
              size: 64,
              color: navyButton,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Upload Student Data File',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: navyDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'CSV or Excel file (.csv, .xlsx, .xls)',
            style: TextStyle(
              color: navyDark.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [navyDark, navyBlue],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: navyDark.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isParsing ? null : _pickFile,
                icon: _isParsing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.upload_file),
                label: Text(_isParsing ? 'Processing...' : 'Select File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleFormatCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navyDark.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required Columns',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: navyDark,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _requiredColumns.map((col) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: navyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: navyBlue.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  col,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: navyButton,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      children: [
        _buildSummaryCards(),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [navyDark, navyBlue],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: navyDark.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Valid'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_validStudents.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Invalid'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_invalidStudents.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Duplicates'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentOrange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_duplicateIds.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildValidStudentsList(),
                      _buildInvalidStudentsList(),
                      _buildDuplicatesList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_uploadComplete && _validStudents.isNotEmpty)
          _buildUploadButton(),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      color: cardWhite,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total',
                  '${_parsedStudents.length}',
                  Icons.groups,
                  navyBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Valid',
                  '${_validStudents.length}',
                  Icons.check_circle,
                  accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Invalid',
                  '${_invalidStudents.length}',
                  Icons.error,
                  accentRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Duplicates',
                  '${_duplicateIds.length}',
                  Icons.content_copy,
                  accentOrange,
                ),
              ),
            ],
          ),
          if (_uploadComplete) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Uploaded',
                    '$_uploadedCount',
                    Icons.cloud_done,
                    const Color(0xFF8b5cf6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Failed',
                    '$_failedCount',
                    Icons.cloud_off,
                    Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: navyDark.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidStudentsList() {
    if (_validStudents.isEmpty) {
      return _buildEmptyState('No valid students found', Icons.check_circle, accentGreen);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _validStudents.length,
      itemBuilder: (context, index) {
        final student = _validStudents[index];
        return _buildStudentCard(student, accentGreen, isValid: true);
      },
    );
  }

  Widget _buildInvalidStudentsList() {
    if (_invalidStudents.isEmpty) {
      return _buildEmptyState('No invalid students', Icons.celebration, accentGreen);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invalidStudents.length,
      itemBuilder: (context, index) {
        final student = _invalidStudents[index];
        return _buildStudentCard(student, accentRed, isValid: false);
      },
    );
  }

  Widget _buildDuplicatesList() {
    if (_duplicateIds.isEmpty) {
      return _buildEmptyState('No duplicates found', Icons.thumb_up, accentGreen);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _duplicateIds.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentOrange.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: navyDark.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.content_copy, color: accentOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _duplicateIds[index],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: navyDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Student ID already exists in system',
                      style: TextStyle(
                        color: navyDark.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: color.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: navyDark.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, Color color,
      {required bool isValid}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: navyDark.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isValid ? Icons.check_circle : Icons.error,
              color: color,
              size: 24,
            ),
          ),
          title: Text(
            '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: navyDark,
            ),
          ),
          subtitle: Text(
            student['studentId'] ?? 'No ID',
            style: TextStyle(
              fontSize: 12,
              color: navyDark.withOpacity(0.6),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isValid && student['errors'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentRed.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.error_outline, size: 16, color: accentRed),
                              SizedBox(width: 8),
                              Text(
                                'Errors:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: accentRed,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...(student['errors'] as List).map((error) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $error',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: navyDark.withOpacity(0.8),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ✅ SECTION 1: STUDENT INFORMATION
                  _buildSectionHeader('Student Information', Icons.person),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: navyBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: navyBlue.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('First Name', student['firstName'] ?? 'N/A'),
                        _buildDetailRow('Last Name', student['lastName'] ?? 'N/A'),
                        _buildDetailRow('Class', student['class'] ?? 'N/A'),
                        _buildDetailRow('Gender', student['gender'] ?? 'N/A'),
                        _buildDetailRow('Date of Birth', student['dateOfBirth'] ?? 'N/A'),
                        _buildDetailRow('Blood Group', student['bloodGroup'] ?? 'N/A', isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ SECTION 2: GUARDIAN INFORMATION
                  _buildSectionHeader('Guardian Information', Icons.family_restroom),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentGreen.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Guardian Name', student['guardianName'] ?? 'N/A'),
                        _buildDetailRow('Guardian Phone', student['guardianPhone'] ?? 'N/A'),
                        _buildDetailRow('Guardian Email', student['guardianEmail'] ?? 'N/A'),
                        _buildDetailRow('Emergency Contact', student['emergencyContact'] ?? 'N/A', isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ SECTION 3: MEDICAL INFORMATION
                  _buildSectionHeader('Medical & Additional Information', Icons.medical_services),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentOrange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentOrange.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Medical Info', student['medicalInfo'] ?? 'None'),
                        _buildDetailRow('Address', student['address'] ?? 'N/A', isLast: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [navyDark, navyBlue],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: navyDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: navyDark.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: navyDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return Container(
      color: cardWhite,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isUploading ? null : _resetUpload,
              icon: const Icon(Icons.refresh),
              label: const Text('Start Over'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: navyButton, width: 2),
                foregroundColor: navyButton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [navyDark, navyBlue],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: navyDark.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadStudents,
                icon: const Icon(Icons.cloud_upload),
                label: Text('Upload ${_validStudents.length} Students'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result != null) {
        setState(() {
          _isParsing = true;
          _fileName = result.files.first.name;
        });

        final file = File(result.files.first.path!);
        final extension = result.files.first.extension?.toLowerCase();

        if (extension == 'csv') {
          await _parseCSV(file);
        } else if (extension == 'xlsx' || extension == 'xls') {
          await _parseExcel(file);
        }

        await _validateAndCheckDuplicates();
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: ${e.toString()}');
    } finally {
      setState(() => _isParsing = false);
    }
  }

  Future<void> _parseCSV(File file) async {
    try {
      final input = file.readAsStringSync();
      final fields = const CsvToListConverter().convert(input);

      if (fields.isEmpty) {
        throw Exception('CSV file is empty');
      }

      final headers = fields[0].map((e) => e.toString().trim()).toList();
      final students = <Map<String, dynamic>>[];

      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        final student = <String, dynamic>{};

        for (int j = 0; j < headers.length && j < row.length; j++) {
          student[headers[j]] = row[j].toString().trim();
        }

        students.add(student);
      }

      setState(() => _parsedStudents = students);
    } catch (e) {
      _showErrorSnackBar('Error parsing CSV: ${e.toString()}');
    }
  }

  Future<void> _parseExcel(File file) async {
    try {
      final bytes = file.readAsBytesSync();
      final workbook = excel.Excel.decodeBytes(bytes);

      if (workbook.tables.isEmpty) {
        throw Exception('Excel file has no sheets');
      }

      final sheet = workbook.tables[workbook.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('Excel sheet is empty');
      }

      final headers = sheet.rows[0]
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .toList();

      final students = <Map<String, dynamic>>[];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final student = <String, dynamic>{};

        for (int j = 0; j < headers.length && j < row.length; j++) {
          student[headers[j]] = row[j]?.value?.toString().trim() ?? '';
        }

        students.add(student);
      }

      setState(() => _parsedStudents = students);
    } catch (e) {
      _showErrorSnackBar('Error parsing Excel: ${e.toString()}');
    }
  }

  Future<void> _validateAndCheckDuplicates() async {
    final valid = <Map<String, dynamic>>[];
    final invalid = <Map<String, dynamic>>[];
    final duplicates = <String>[];

    // Check for duplicates in database
    final existingStudents = await FirebaseFirestore.instance
        .collection('students')
        .where('schoolId', isEqualTo: widget.schoolId)
        .get();

    final existingIds = existingStudents.docs
        .map((doc) => doc.data()['studentId'] as String?)
        .where((id) => id != null)
        .toSet();

    for (final student in _parsedStudents) {
      final errors = <String>[];

      // Check required fields
      for (final field in _requiredColumns) {
        if (student[field] == null || student[field].toString().trim().isEmpty) {
          errors.add('Missing required field: $field');
        }
      }

      // Validate gender
      if (student['gender'] != null) {
        final gender = student['gender'].toString().toLowerCase();
        if (gender != 'male' && gender != 'female') {
          errors.add('Gender must be Male or Female');
        }
      }

      // Validate phone numbers
      if (student['guardianPhone'] != null) {
        final phone = student['guardianPhone'].toString().replaceAll(RegExp(r'\D'), '');
        if (phone.length < 10) {
          errors.add('Invalid guardian phone number');
        }
      }

      // Generate student ID if not provided
      if (student['studentId'] == null || student['studentId'].toString().isEmpty) {
        student['studentId'] = await _generateStudentId();
      }

      // Check for duplicates
      if (existingIds.contains(student['studentId'])) {
        if (!duplicates.contains(student['studentId'])) {
          duplicates.add(student['studentId']);
        }
        errors.add('Student ID already exists');
      }

      if (errors.isEmpty) {
        valid.add(student);
      } else {
        student['errors'] = errors;
        invalid.add(student);
      }
    }

    setState(() {
      _validStudents = valid;
      _invalidStudents = invalid;
      _duplicateIds = duplicates;
    });
  }

  Future<String> _generateStudentId() async {
    final initials = _getSchoolInitials();
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('schoolId', isEqualTo: widget.schoolId)
        .get();

    int highestNumber = 0;
    for (var doc in studentsSnapshot.docs) {
      final studentId = doc.data()['studentId'] as String?;
      if (studentId != null && studentId.contains('STUD')) {
        final numberPart = studentId.split('STUD').last;
        final number = int.tryParse(numberPart) ?? 0;
        if (number > highestNumber) {
          highestNumber = number;
        }
      }
    }

    return '${initials}STUD${(highestNumber + 1).toString().padLeft(4, '0')}';
  }

  String _getSchoolInitials() {
    final words = widget.schoolName.trim().split(' ');
    if (words.isEmpty) return 'XX';

    String initials = '';
    for (var word in words.take(2)) {
      if (word.isNotEmpty) {
        initials += word[0].toUpperCase();
      }
    }

    if (initials.length == 1) {
      initials = initials + (words[0].length > 1 ? words[0][1].toUpperCase() : 'X');
    }
    if (initials.isEmpty) {
      initials = 'XX';
    }

    return initials.substring(0, 2);
  }

  Future<void> _uploadStudents() async {
    // Check internet connectivity first
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showErrorSnackBar('No internet connection. Please check and try again.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _failedCount = 0;
    });

    for (final student in _validStudents) {
      try {
        final fullName = '${student['firstName']} ${student['lastName']}'.trim();

        final studentRef = await FirebaseFirestore.instance.collection('students').add({
          'studentId': student['studentId'],
          'firstName': student['firstName'],
          'lastName': student['lastName'],
          'fullName': fullName,
          'dateOfBirth': student['dateOfBirth'],
          'gender': student['gender'],
          'bloodGroup': student['bloodGroup'] ?? '',
          'class': student['class'],
          'address': student['address'] ?? '',
          'guardianName': student['guardianName'],
          'guardianPhone': student['guardianPhone'],
          'guardianEmail': student['guardianEmail'] ?? '',
          'emergencyContact': student['emergencyContact'],
          'medicalInfo': student['medicalInfo'] ?? '',
          'parentId': null,
          'schoolId': widget.schoolId,
          'schoolName': widget.schoolName,
          'isActive': true,
          'isOnCompound': false,
          'hasDevice': false,
          'deviceId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('studentTracking').add({
          'studentId': student['studentId'],
          'studentDocId': studentRef.id,
          'studentName': fullName,
          'schoolId': widget.schoolId,
          'isOnCompound': false,
          'latitude': null,
          'longitude': null,
          'accuracy': null,
          'speed': null,
          'lastUpdate': null,
          'deviceId': null,
          'hasDevice': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _uploadedCount++);

        // Small delay to show progress
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        setState(() => _failedCount++);
        debugPrint('Error uploading student: ${e.toString()}');
      }
    }

    setState(() {
      _isUploading = false;
      _uploadComplete = true;
    });

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [accentGreen, Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upload Complete!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Successfully uploaded $_uploadedCount students',
                style: const TextStyle(
                  fontSize: 15,
                  color: navyDark,
                ),
              ),
              if (_failedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Failed to upload $_failedCount students',
                  style: const TextStyle(
                    color: accentRed,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [navyBlue.withOpacity(0.1), navyDark.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: navyBlue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.devices, color: navyButton, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ready to assign devices to students',
                        style: TextStyle(
                          fontSize: 13,
                          color: navyDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: navyButton, width: 2),
                        foregroundColor: navyButton,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [navyDark, navyBlue],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: navyDark.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToDeviceAssignment();
                        },
                        icon: const Icon(Icons.devices),
                        label: const Text('Assign'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDeviceAssignment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceStudentPage(
          schoolId: widget.schoolId,
          schoolName: widget.schoolName,
          adminId: widget.adminId,
        ),
      ),
    );
  }

  void _resetUpload() {
    setState(() {
      _parsedStudents.clear();
      _validStudents.clear();
      _invalidStudents.clear();
      _duplicateIds.clear();
      _fileName = null;
      _uploadedCount = 0;
      _failedCount = 0;
      _uploadComplete = false;
    });
  }

  void _downloadTemplate() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [navyDark, navyBlue],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Template Format',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: navyDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Create a CSV or Excel file with these columns:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 12),
              ..._requiredColumns.map((col) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: accentGreen),
                    const SizedBox(width: 8),
                    Text(
                      col,
                      style: const TextStyle(
                        fontSize: 13,
                        color: navyDark,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: navyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Optional: bloodGroup, address, guardianEmail, medicalInfo',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: navyDark,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [navyDark, navyBlue],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}