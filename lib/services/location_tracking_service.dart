import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Real-Time Location Tracking Service
class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  Timer? _locationTimer;
  Timer? _batteryTimer;
  Timer? _compoundCheckTimer;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<BatteryState>? _batteryStream;

  String? _deviceId;
  String? _studentDocId;
  String? _studentId;
  String? _schoolId;
  String? _studentName;
  bool _isTracking = false;

  // Update intervals
  static const int LOCATION_UPDATE_INTERVAL = 10; // seconds
  static const int BATTERY_UPDATE_INTERVAL = 30; // seconds
  static const int COMPOUND_CHECK_INTERVAL = 15; // seconds

  /// Get tracking status
  bool get isTracking => _isTracking;

  /// Initialize tracking service
  Future<void> initialize({
    required String deviceId,
    required String studentDocId,
    required String studentId,
    required String schoolId,
    required String studentName,
  }) async {
    try {
      _deviceId = deviceId;
      _studentDocId = studentDocId;
      _studentId = studentId;
      _schoolId = schoolId;
      _studentName = studentName;

      debugPrint('🚀 Initializing tracking...');
      debugPrint('📱 Device: $_deviceId');
      debugPrint('👤 Student: $_studentName');

      await _requestPermissions();
      await _initializeDevice();

      debugPrint('✅ Initialization complete');
    } catch (e) {
      debugPrint('❌ Init error: $e');
      rethrow;
    }
  }

  /// Request permissions
  Future<void> _requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception('Location permission required');
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services disabled');
    }
  }

  /// Initialize device in Firestore
  Future<void> _initializeDevice() async {
    if (_deviceId == null) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Mobile Device';
      String serialNumber = 'Unknown';

      try {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        serialNumber = androidInfo.id;
      } catch (e) {
        debugPrint('Device info error: $e');
      }

      int batteryLevel = await _battery.batteryLevel;

      await _firestore.collection('devices').doc(_deviceId).set({
        'deviceId': _deviceId,
        'deviceName': deviceName,
        'serialNumber': serialNumber,
        'deviceType': 'Mobile Device',
        'batteryLevel': batteryLevel,
        'isActive': true,
        'isAssigned': true,
        'schoolId': _schoolId,
        'assignedToStudentId': _studentId,
        'assignedToStudentDocId': _studentDocId,
        'assignedToStudentName': _studentName,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Device initialized');
    } catch (e) {
      debugPrint('❌ Device init error: $e');
    }
  }

  /// Start tracking
  Future<void> startTracking() async {
    if (_isTracking) {
      debugPrint('⚠️ Already tracking');
      return;
    }

    if (_deviceId == null || _studentDocId == null) {
      throw Exception('Not initialized');
    }

    _isTracking = true;
    debugPrint('▶️ Starting tracking...');

    await _initializeStudentTracking();
    _startLocationTracking();
    _startBatteryMonitoring();
    _startCompoundChecking();

    debugPrint('✅ Tracking started');
  }

  /// Initialize student tracking
  Future<void> _initializeStudentTracking() async {
    try {
      await _firestore.collection('studentTracking').doc(_studentDocId).set({
        'studentId': _studentId,
        'studentName': _studentName,
        'studentDocId': _studentDocId,
        'deviceId': _deviceId,
        'schoolId': _schoolId,
        'hasDevice': true,
        'isOnCompound': false,
        'accuracy': null,
        'speed': 0.0,
        'lastUpdate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Student tracking init error: $e');
    }
  }

  /// Start location tracking
  void _startLocationTracking() {
    debugPrint('📍 Starting GPS...');

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    // Stream for real-time updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
          (position) => _updateLocation(position),
      onError: (e) => debugPrint('GPS error: $e'),
    );

    // Timer as backup
    _locationTimer = Timer.periodic(
      Duration(seconds: LOCATION_UPDATE_INTERVAL),
          (_) async {
        try {
          final position = await Geolocator.getCurrentPosition();
          await _updateLocation(position);
        } catch (e) {
          debugPrint('Location error: $e');
        }
      },
    );
  }

  /// Update location
  Future<void> _updateLocation(Position position) async {
    if (_studentDocId == null || _deviceId == null) return;

    try {
      final speed = (position.speed * 3.6).toStringAsFixed(1);

      // Update studentTracking
      await _firestore.collection('studentTracking').doc(_studentDocId).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': double.parse(speed),
        'altitude': position.altitude,
        'heading': position.heading,
        'lastUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update deviceTracking
      await _firestore.collection('deviceTracking')
          .doc('${_schoolId}_$_deviceId')
          .set({
        'deviceId': _deviceId,
        'studentId': _studentId,
        'schoolId': _schoolId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': double.parse(speed),
        'altitude': position.altitude,
        'heading': position.heading,
        'isMoving': position.speed > 0.5,
        'lastUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Update location error: $e');
    }
  }

  /// Start battery monitoring
  void _startBatteryMonitoring() {
    debugPrint('🔋 Starting battery monitor...');

    _updateBattery();

    _batteryTimer = Timer.periodic(
      Duration(seconds: BATTERY_UPDATE_INTERVAL),
          (_) => _updateBattery(),
    );

    _batteryStream = _battery.onBatteryStateChanged.listen((_) {
      _updateBattery();
    });
  }

  /// Update battery
  Future<void> _updateBattery() async {
    if (_deviceId == null) return;

    try {
      int level = await _battery.batteryLevel;
      BatteryState state = await _battery.batteryState;

      await _firestore.collection('devices').doc(_deviceId).update({
        'batteryLevel': level,
        'batteryState': state.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🔋 Battery: $level%');

      if (level <= 15 && state != BatteryState.charging) {
        await _sendLowBatteryAlert(level);
      }
    } catch (e) {
      debugPrint('❌ Battery update error: $e');
    }
  }

  /// Send low battery alert
  Future<void> _sendLowBatteryAlert(int level) async {
    try {
      final recent = await _firestore
          .collection('deviceAlerts')
          .where('deviceId', isEqualTo: _deviceId)
          .where('alertType', isEqualTo: 'LOW_BATTERY')
          .where('isResolved', isEqualTo: false)
          .limit(1)
          .get();

      if (recent.docs.isNotEmpty) {
        final createdAt = recent.docs.first.data()['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final diff = DateTime.now().difference(createdAt.toDate());
          if (diff.inMinutes < 30) return;
        }
      }

      await _firestore.collection('deviceAlerts').add({
        'alertType': 'LOW_BATTERY',
        'deviceId': _deviceId,
        'studentId': _studentId,
        'studentDocId': _studentDocId,
        'studentName': _studentName,
        'schoolId': _schoolId,
        'batteryLevel': level,
        'message': 'Device battery critically low ($level%)',
        'severity': level <= 10 ? 'critical' : 'high',
        'isResolved': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('⚠️ Low battery alert sent');
    } catch (e) {
      debugPrint('Alert error: $e');
    }
  }

  /// Start compound checking
  void _startCompoundChecking() {
    debugPrint('🏫 Starting compound check...');

    _compoundCheckTimer = Timer.periodic(
      Duration(seconds: COMPOUND_CHECK_INTERVAL),
          (_) => _checkCompound(),
    );

    _checkCompound();
  }

  /// Check compound
  /// Check compound
  /// Check compound
  Future<void> _checkCompound() async {
    if (_studentDocId == null || _schoolId == null) return;

    try {
      final tracking = await _firestore
          .collection('studentTracking')
          .doc(_studentDocId)
          .get();

      if (!tracking.exists) return;

      final data = tracking.data();
      if (data == null) return;

      final studentLat = data['latitude'] as double?;
      final studentLng = data['longitude'] as double?;

      if (studentLat == null || studentLng == null) return;

      final school = await _firestore.collection('schools').doc(_schoolId).get();

      if (!school.exists) return;

      final schoolData = school.data();
      if (schoolData == null) return;

      final schoolLat = schoolData['latitude'] as double? ?? 0.0;
      final schoolLng = schoolData['longitude'] as double? ?? 0.0;
      final radius = schoolData['safeZoneRadius'] as double? ?? 100.0;  // ← CHANGED HERE!

      debugPrint('🏫 School location: $schoolLat, $schoolLng');  // ← ADD THIS
      debugPrint('🏫 Safe zone radius: $radius meters');  // ← ADD THIS

      double distance = Geolocator.distanceBetween(
        studentLat, studentLng, schoolLat, schoolLng,
      );

      debugPrint('📏 Distance from school: ${distance.toStringAsFixed(2)} meters');  // ← ADD THIS

      bool isOnCompound = distance <= radius;
      bool wasOnCompound = data['isOnCompound'] as bool? ?? false;

      if (isOnCompound != wasOnCompound) {
        await _firestore.collection('studentTracking').doc(_studentDocId).update({
          'isOnCompound': isOnCompound,
          'distanceFromSchool': distance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _firestore.collection('students').doc(_studentDocId).update({
          'isOnCompound': isOnCompound,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });

        debugPrint(isOnCompound ? '🟢 Entered compound' : '🔴 Left compound');

        if (!isOnCompound && wasOnCompound) {
          await _sendOffCompoundAlert(distance);
        }
      }
    } catch (e) {
      debugPrint('Compound check error: $e');
    }
  }

  /// Send off-compound alert
  Future<void> _sendOffCompoundAlert(double distance) async {
    try {
      await _firestore.collection('deviceAlerts').add({
        'alertType': 'LEFT_COMPOUND',
        'deviceId': _deviceId,
        'studentId': _studentId,
        'studentDocId': _studentDocId,
        'studentName': _studentName,
        'schoolId': _schoolId,
        'distance': distance,
        'message': '$_studentName left school compound',
        'severity': 'medium',
        'isResolved': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🚨 Off-compound alert sent');
    } catch (e) {
      debugPrint('Alert error: $e');
    }
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    debugPrint('⏹️ Stopping...');

    _locationTimer?.cancel();
    _batteryTimer?.cancel();
    _compoundCheckTimer?.cancel();
    await _positionStream?.cancel();
    await _batteryStream?.cancel();

    if (_deviceId != null) {
      await _firestore.collection('devices').doc(_deviceId).update({
        'status': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    debugPrint('✅ Stopped');
  }

  /// Get current status
  Future<Map<String, dynamic>?> getCurrentStatus() async {
    if (_studentDocId == null) return null;

    try {
      final doc = await _firestore
          .collection('studentTracking')
          .doc(_studentDocId)
          .get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// Cleanup
  void dispose() {
    stopTracking();
  }
}