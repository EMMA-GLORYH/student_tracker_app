import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:find_me/screens/school_admins/device_student.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:find_me/services/tracking_integration.dart';
import 'dart:async';

// 🎨 NAVY BLUE COLOR PALETTE
class AppColors {
  static const navyDark = Color(0xFF0A1929);
  static const navyPrimary = Color(0xFF1e3a5f);
  static const navyBlue = Color(0xFF2563eb);
  static const navyLight = Color(0xFF3b82f6);
  static const white = Colors.white;
  static const lightBg = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF64748b);
  static const success = Color(0xFF10b981);
  static const warning = Color(0xFFf59e0b);
  static const error = Color(0xFFef4444);
}

class AssignDevicePage extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final String adminId;

  const AssignDevicePage({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.adminId,
  });

  @override
  State<AssignDevicePage> createState() => _AssignDevicePageState();
}

class _AssignDevicePageState extends State<AssignDevicePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _deviceFormKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _searchController = TextEditingController();

  String? _selectedDeviceType;
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    _serialNumberController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 🔗 Check Internet Connection
  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return false;

      try {
        await FirebaseFirestore.instance
            .collection('devices')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // 📡 Show Connection Check with 3-Dot Loading
  Future<void> _showConnectivityCheck(VoidCallback onSuccess) async {
    _showLoadingBottomSheet('Checking connection...');

    await Future.delayed(const Duration(seconds: 2));
    final isConnected = await _checkInternetConnection();

    if (mounted) {
      Navigator.pop(context); // Close loading

      if (isConnected) {
        onSuccess();
      } else {
        _showNoInternetBottomSheet();
      }
    }
  }

  // 💫 3-Dot Loading Bottom Sheet
  void _showLoadingBottomSheet(String message) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 250,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ThreeDotLoading(size: 16),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📶 No Internet Bottom Sheet
  void _showNoInternetBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Icon and Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'No Internet Connection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Please check your internet connection and try again.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure Wi-Fi or mobile data is enabled',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showConnectivityCheck(() {});
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyBlue,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ➕ Add Device
  Future<void> _addDevice() async {
    if (!_deviceFormKey.currentState!.validate()) return;

    _showConnectivityCheck(() async {
      _showLoadingBottomSheet('Adding device...');

      try {
        final deviceId = _deviceIdController.text.trim();

        final existingDevice = await FirebaseFirestore.instance
            .collection('devices')
            .where('deviceId', isEqualTo: deviceId)
            .where('schoolId', isEqualTo: widget.schoolId)
            .get();

        if (existingDevice.docs.isNotEmpty) {
          Navigator.pop(context); // Close loading
          if (mounted) {
            _showSnackBar('Device ID already exists!', isError: true);
          }
          return;
        }

        await FirebaseFirestore.instance.collection('devices').add({
          'deviceId': deviceId,
          'deviceName': _deviceNameController.text.trim(),
          'serialNumber': _serialNumberController.text.trim(),
          'deviceType': _selectedDeviceType,
          'schoolId': widget.schoolId,
          'schoolName': widget.schoolName,
          'isAssigned': false,
          'assignedToStudentId': null,
          'assignedToStudentName': null,
          'assignedAt': null,
          'isActive': true,
          'batteryLevel': null,
          'lastSeen': null,
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Navigator.pop(context); // Close loading

        if (mounted) {
          _showSnackBar('Device added successfully!');
          _deviceIdController.clear();
          _deviceNameController.clear();
          _serialNumberController.clear();
          setState(() => _selectedDeviceType = null);
        }
      } catch (e) {
        Navigator.pop(context); // Close loading
        if (mounted) {
          _showSnackBar('Error: ${e.toString()}', isError: true);
        }
      }
    });
  }

  // 🔗 Assign Device
  Future<void> _assignDevice(
      String deviceDocId, Map<String, dynamic> deviceData) async {
    final students = await _loadStudentsWithoutDevice();

    if (!mounted) return;

    if (students.isEmpty) {
      _showSnackBar('No students without devices available', isError: true);
      return;
    }

    final selectedStudent = await _showStudentSelectionBottomSheet(students);
    if (selectedStudent == null) return;

    _showConnectivityCheck(() async {
      _showLoadingBottomSheet('Assigning device...');

      try {
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceDocId)
            .update({
          'isAssigned': true,
          'assignedToStudentId': selectedStudent['studentId'],
          'assignedToStudentName': selectedStudent['fullName'],
          'assignedToStudentDocId': selectedStudent['docId'],
          'assignedAt': FieldValue.serverTimestamp(),
          'status': 'assigned',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('students')
            .doc(selectedStudent['docId'])
            .update({
          'hasDevice': true,
          'deviceId': deviceData['deviceId'],
          'deviceDocId': deviceDocId,
          'deviceAssignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final trackingQuery = await FirebaseFirestore.instance
            .collection('studentTracking')
            .where('studentId', isEqualTo: selectedStudent['studentId'])
            .where('schoolId', isEqualTo: widget.schoolId)
            .get();

        if (trackingQuery.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('studentTracking')
              .doc(trackingQuery.docs.first.id)
              .update({
            'hasDevice': true,
            'deviceId': deviceData['deviceId'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await FirebaseFirestore.instance.collection('deviceAssignments').add({
          'deviceId': deviceData['deviceId'],
          'deviceDocId': deviceDocId,
          'studentId': selectedStudent['studentId'],
          'studentName': selectedStudent['fullName'],
          'studentDocId': selectedStudent['docId'],
          'schoolId': widget.schoolId,
          'assignedAt': FieldValue.serverTimestamp(),
          'assignedBy': widget.adminId,
          'status': 'active',
        });

        // Start tracking
        try {
          await TrackingIntegration.startTrackingForStudent(
            deviceId: deviceData['deviceId'],
            studentDocId: selectedStudent['docId'],
            studentId: selectedStudent['studentId'],
            schoolId: widget.schoolId,
            studentName: selectedStudent['fullName'],
          );
        } catch (e) {
          debugPrint('⚠️ Could not start tracking: $e');
        }

        Navigator.pop(context); // Close loading

        if (mounted) {
          _showSnackBar(
              'Device assigned to ${selectedStudent['fullName']} successfully!');
        }
      } catch (e) {
        Navigator.pop(context); // Close loading
        if (mounted) {
          _showSnackBar('Error: ${e.toString()}', isError: true);
        }
      }
    });
  }

  // 🔓 Unassign Device
  Future<void> _unassignDevice(
      String deviceDocId, Map<String, dynamic> deviceData) async {
    final confirm = await _showConfirmBottomSheet(
      title: 'Unassign Device',
      message:
      'Are you sure you want to unassign this device from ${deviceData['assignedToStudentName']}?',
      confirmText: 'Unassign',
      isDestructive: true,
    );

    if (confirm != true) return;

    _showConnectivityCheck(() async {
      _showLoadingBottomSheet('Unassigning device...');

      try {
        final studentDocId = deviceData['assignedToStudentDocId'];
        final studentId = deviceData['assignedToStudentId'];

        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceDocId)
            .update({
          'isAssigned': false,
          'assignedToStudentId': null,
          'assignedToStudentName': null,
          'assignedToStudentDocId': null,
          'assignedAt': null,
          'status': 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (studentDocId != null) {
          await FirebaseFirestore.instance
              .collection('students')
              .doc(studentDocId)
              .update({
            'hasDevice': false,
            'deviceId': null,
            'deviceDocId': null,
            'deviceAssignedAt': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (studentId != null) {
          final trackingQuery = await FirebaseFirestore.instance
              .collection('studentTracking')
              .where('studentId', isEqualTo: studentId)
              .where('schoolId', isEqualTo: widget.schoolId)
              .get();

          if (trackingQuery.docs.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('studentTracking')
                .doc(trackingQuery.docs.first.id)
                .update({
              'hasDevice': false,
              'deviceId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        final assignmentQuery = await FirebaseFirestore.instance
            .collection('deviceAssignments')
            .where('deviceDocId', isEqualTo: deviceDocId)
            .where('status', isEqualTo: 'active')
            .get();

        for (var doc in assignmentQuery.docs) {
          await doc.reference.update({
            'status': 'unassigned',
            'unassignedAt': FieldValue.serverTimestamp(),
            'unassignedBy': widget.adminId,
          });
        }

        Navigator.pop(context); // Close loading

        if (mounted) {
          _showSnackBar('Device unassigned successfully!');
        }
      } catch (e) {
        Navigator.pop(context); // Close loading
        if (mounted) {
          _showSnackBar('Error: ${e.toString()}', isError: true);
        }
      }
    });
  }

  // 📚 Load Students Without Device
  Future<List<Map<String, dynamic>>> _loadStudentsWithoutDevice() async {
    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('isActive', isEqualTo: true)
          .where('hasDevice', isEqualTo: false)
          .get();

      return studentsSnapshot.docs
          .map((doc) => {
        'docId': doc.id,
        'studentId': doc.data()['studentId'],
        'fullName': doc.data()['fullName'],
        'class': doc.data()['class'],
      })
          .toList();
    } catch (e) {
      debugPrint('Error loading students: $e');
      return [];
    }
  }

  // 📝 Show Student Selection Bottom Sheet
  Future<Map<String, dynamic>?> _showStudentSelectionBottomSheet(
      List<Map<String, dynamic>> students) async {
    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentSelectionBottomSheet(students: students),
    );
  }

  // ✅ Show Confirm Bottom Sheet
  Future<bool?> _showConfirmBottomSheet({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      isDestructive ? AppColors.error : AppColors.navyBlue,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 Show SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: AppColors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        title: const Text(
          'Device Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.navyDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.track_changes),
            tooltip: 'Track Devices',
            onPressed: () {
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
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AnimatedTabBar(tabController: _tabController),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddDeviceTab(),
          _buildMatchingTab(),
          _buildDeviceList(false),
          _buildDeviceList(true),
        ],
      ),
    );
  }

  // 📄 Build Add Device Tab
  Widget _buildAddDeviceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _deviceFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Register New Device',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a new tracking device to your school inventory',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navyDark.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _deviceIdController,
                    label: 'Device ID',
                    hint: 'Enter unique device identifier',
                    icon: Icons.qr_code,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter device ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildTextField(
                    controller: _deviceNameController,
                    label: 'Device Name',
                    hint: 'Enter device name (optional)',
                    icon: Icons.devices,
                  ),
                  const SizedBox(height: 18),
                  _buildTextField(
                    controller: _serialNumberController,
                    label: 'Serial Number',
                    hint: 'Enter manufacturer serial number',
                    icon: Icons.tag,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter serial number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: _selectedDeviceType,
                    decoration: InputDecoration(
                      labelText: 'Device Type',
                      labelStyle: const TextStyle(color: AppColors.navyBlue),
                      prefixIcon:
                      const Icon(Icons.category, color: AppColors.navyBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: AppColors.navyBlue, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.lightBg,
                    ),
                    items: [
                      'GPS Tracker',
                      'Smart Watch',
                      'RFID Tag',
                      'Mobile Device',
                      'Other'
                    ].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDeviceType = value);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select device type';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _addDevice,
                icon: const Icon(Icons.add, size: 22),
                label: const Text(
                  'Add Device',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📋 Build Matching Tab
  Widget _buildMatchingTab() {
    return DeviceStudentMatchingView(
      schoolId: widget.schoolId,
      schoolName: widget.schoolName,
      adminId: widget.adminId,
      onConnectivityCheck: _showConnectivityCheck,
    );
  }

  // 📱 Build Device List
  Widget _buildDeviceList(bool showAssigned) {
    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.navyDark),
            decoration: InputDecoration(
              hintText: 'Search devices...',
              prefixIcon: const Icon(Icons.search, color: AppColors.navyBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.navyBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: AppColors.lightBg,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('devices')
                .where('schoolId', isEqualTo: widget.schoolId)
                .where('isAssigned', isEqualTo: showAssigned)
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: ThreeDotLoading(size: 16));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        showAssigned ? Icons.device_hub : Icons.devices_other,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        showAssigned
                            ? 'No assigned devices'
                            : 'No available devices',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              var devices = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final deviceId = (data['deviceId'] ?? '').toLowerCase();
                final deviceName = (data['deviceName'] ?? '').toLowerCase();
                final studentName =
                (data['assignedToStudentName'] ?? '').toLowerCase();
                return _searchQuery.isEmpty ||
                    deviceId.contains(_searchQuery) ||
                    deviceName.contains(_searchQuery) ||
                    studentName.contains(_searchQuery);
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final deviceDoc = devices[index];
                  final deviceData = deviceDoc.data() as Map<String, dynamic>;
                  return _buildDeviceCard(deviceDoc.id, deviceData);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 🎴 Build Device Card
  Widget _buildDeviceCard(String docId, Map<String, dynamic> deviceData) {
    final isAssigned = deviceData['isAssigned'] ?? false;
    final deviceType = deviceData['deviceType'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssigned ? AppColors.success : AppColors.navyBlue,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDark.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isAssigned ? AppColors.success : AppColors.navyBlue)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getDeviceIcon(deviceType),
                    color: isAssigned ? AppColors.success : AppColors.navyBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceData['deviceId'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deviceType,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                    (isAssigned ? AppColors.success : AppColors.navyBlue)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAssigned ? 'Assigned' : 'Available',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isAssigned ? AppColors.success : AppColors.navyBlue,
                    ),
                  ),
                ),
              ],
            ),
            if (deviceData['deviceName'] != null &&
                deviceData['deviceName'].isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.label, 'Name', deviceData['deviceName']),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(Icons.tag, 'Serial', deviceData['serialNumber']),
            if (isAssigned) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, 'Assigned to',
                  deviceData['assignedToStudentName']),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (!isAssigned)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _assignDevice(docId, deviceData),
                      icon: const Icon(Icons.assignment_ind, size: 18),
                      label: const Text('Assign'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBlue,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                if (isAssigned) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _unassignDevice(docId, deviceData),
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('Unassign'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
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
                      },
                      icon: const Icon(Icons.track_changes, size: 18),
                      label: const Text('Track'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 📝 Build Info Row
  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navyDark,
            ),
          ),
        ),
      ],
    );
  }

  // ✏️ Build Text Field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: AppColors.navyDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.navyBlue),
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.navyBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navyBlue, width: 2),
        ),
        filled: true,
        fillColor: AppColors.lightBg,
      ),
      validator: validator,
    );
  }

  // 🎨 Get Device Icon
  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'gps tracker':
        return Icons.gps_fixed;
      case 'smart watch':
        return Icons.watch;
      case 'rfid tag':
        return Icons.nfc;
      case 'mobile device':
        return Icons.phone_android;
      default:
        return Icons.device_hub;
    }
  }
}

// 🎯 Animated Tab Bar with Size Animation
class AnimatedTabBar extends StatefulWidget {
  final TabController tabController;

  const AnimatedTabBar({super.key, required this.tabController});

  @override
  State<AnimatedTabBar> createState() => _AnimatedTabBarState();
}

class _AnimatedTabBarState extends State<AnimatedTabBar> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppColors.navyPrimary,
      child: Row(
        children: List.generate(4, (index) {
          final isSelected = widget.tabController.index == index;
          final labels = ['Add Device', 'Match Students', 'Available', 'Assigned'];

          return Expanded(
            child: GestureDetector(
              onTap: () => widget.tabController.animateTo(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: isSelected ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.white.withOpacity(0.6),
                      fontSize: isSelected ? 15 : 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// 💫 Three Dot Loading Animation
class ThreeDotLoading extends StatefulWidget {
  final double size;

  const ThreeDotLoading({super.key, this.size = 12});

  @override
  State<ThreeDotLoading> createState() => _ThreeDotLoadingState();
}

class _ThreeDotLoadingState extends State<ThreeDotLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final offset = (value < 0.5 ? value * 2 : (1 - value) * 2) * 15;

            Color dotColor;
            if (index == 1) {
              dotColor = AppColors.white; // Middle dot - white
            } else {
              dotColor = AppColors.navyBlue; // Left and right - navy
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, -offset),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: index == 1
                        ? Border.all(
                      color: AppColors.navyBlue,
                      width: 2,
                    )
                        : null,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// 👥 Student Selection Bottom Sheet
class StudentSelectionBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> students;

  const StudentSelectionBottomSheet({super.key, required this.students});

  @override
  State<StudentSelectionBottomSheet> createState() =>
      _StudentSelectionBottomSheetState();
}

class _StudentSelectionBottomSheetState
    extends State<StudentSelectionBottomSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredStudents = widget.students.where((student) {
      final name = (student['fullName'] ?? '').toLowerCase();
      final id = (student['studentId'] ?? '').toLowerCase();
      return _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          id.contains(_searchQuery);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Student',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyDark,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  style: const TextStyle(color: AppColors.navyDark),
                  decoration: InputDecoration(
                    hintText: 'Search student...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.navyBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.navyBlue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: AppColors.lightBg,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ],
            ),
          ),
          // Student List
          Expanded(
            child: filteredStudents.isEmpty
                ? const Center(
              child: Text(
                'No students found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.navyBlue.withOpacity(0.1),
                      child: Text(
                        (student['fullName'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.navyBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      student['fullName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyDark,
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${student['studentId']} • ${student['class']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, student),
                  ),
                );
              },
            ),
          ),
          // Cancel Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🔗 Device-Student Matching View (Placeholder - implement similarly)
class DeviceStudentMatchingView extends StatelessWidget {
  final String schoolId;
  final String schoolName;
  final String adminId;
  final Function(VoidCallback) onConnectivityCheck;

  const DeviceStudentMatchingView({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.adminId,
    required this.onConnectivityCheck,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link, size: 64, color: AppColors.navyBlue),
          SizedBox(height: 16),
          Text(
            'Match devices to students',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.navyDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Implement matching view with navy theme',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}