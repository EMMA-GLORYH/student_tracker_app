import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_tracking_service.dart';

// Tracking Integration Helper
class TrackingIntegration {
  static final LocationTrackingService _service = LocationTrackingService();

  // Start tracking for a student
  static Future<void> startTrackingForStudent({
    required String deviceId,
    required String studentDocId,
    required String studentId,
    required String schoolId,
    required String studentName,
  }) async {
    try {
      debugPrint('🚀 Starting tracking for: $studentName');

      await _service.initialize(
        deviceId: deviceId,
        studentDocId: studentDocId,
        studentId: studentId,
        schoolId: schoolId,
        studentName: studentName,
      );

      await _service.startTracking();

      debugPrint('✅ Tracking started successfully');
    } catch (e) {
      debugPrint('❌ Tracking error: $e');
      rethrow;
    }
  }

  /// Stop tracking
  static Future<void> stopTracking() async {
    await _service.stopTracking();
  }

  /// Check if tracking is active
  static bool isTrackingActive() {
    return _service.isTracking;
  }

  /// Get current tracking status
  static Future<Map<String, dynamic>?> getTrackingStatus() async {
    return await _service.getCurrentStatus();
  }

  /// Auto-initialize from device assignment
  static Future<void> autoInitializeFromDevice(String deviceId) async {
    try {
      debugPrint('🔍 Checking device assignment...');

      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .get();

      if (!deviceDoc.exists) {
        debugPrint('⚠️ Device not found');
        return;
      }

      final data = deviceDoc.data();
      if (data == null) return;

      final isAssigned = data['isAssigned'] as bool? ?? false;
      if (!isAssigned) {
        debugPrint('ℹ️ Device not assigned');
        return;
      }

      final studentDocId = data['assignedToStudentDocId'] as String?;
      final studentId = data['assignedToStudentId'] as String?;
      final studentName = data['assignedToStudentName'] as String?;
      final schoolId = data['schoolId'] as String?;

      if (studentDocId == null || studentId == null || schoolId == null) {
        debugPrint('⚠️ Missing assignment info');
        return;
      }

      await startTrackingForStudent(
        deviceId: deviceId,
        studentDocId: studentDocId,
        studentId: studentId,
        schoolId: schoolId,
        studentName: studentName ?? 'Unknown',
      );

      debugPrint('✅ Auto-initialized tracking');
    } catch (e) {
      debugPrint('❌ Auto-init error: $e');
    }
  }
}

/// Tracking Status Widget
class TrackingStatusWidget extends StatefulWidget {
  const TrackingStatusWidget({Key? key}) : super(key: key);

  @override
  State<TrackingStatusWidget> createState() => _TrackingStatusWidgetState();
}

class _TrackingStatusWidgetState extends State<TrackingStatusWidget> {
  Map<String, dynamic>? _status;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _loadStatus(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await TrackingIntegration.getTrackingStatus();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isActive = TrackingIntegration.isTrackingActive();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.gps_fixed : Icons.gps_off,
                  color: isActive ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isActive ? 'Tracking Active' : 'Tracking Inactive',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_status != null) ...[
              const Divider(height: 24),
              _buildRow('Student', _status!['studentName'] ?? 'N/A'),
              _buildRow('School ID', _status!['schoolId'] ?? 'N/A'),
              _buildRow('Device ID', _status!['deviceId'] ?? 'N/A'),
              _buildRow(
                'On Compound',
                (_status!['isOnCompound'] ?? false) ? 'Yes' : 'No',
              ),
              if (_status!['latitude'] != null)
                _buildRow(
                  'Location',
                  '${_status!['latitude'].toStringAsFixed(6)}, '
                      '${_status!['longitude'].toStringAsFixed(6)}',
                ),
              if (_status!['speed'] != null)
                _buildRow('Speed', '${_status!['speed']} km/h'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}