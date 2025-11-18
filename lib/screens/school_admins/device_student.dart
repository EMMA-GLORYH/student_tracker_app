import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class DeviceStudentPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final String adminId;

  const DeviceStudentPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.adminId,
  });

  @override
  State<DeviceStudentPage> createState() => _DeviceStudentPageState();
}

class _DeviceStudentPageState extends State<DeviceStudentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Auto-refresh every 10 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _getDeviceStatus(Map<String, dynamic> data) {
    final lastUpdate = data['lastUpdate'] as Timestamp?;
    if (lastUpdate == null) return 'offline';

    final diff = DateTime.now().difference(lastUpdate.toDate());
    if (diff.inMinutes < 5) return 'online';
    if (diff.inMinutes < 15) return 'idle';
    return 'offline';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'idle':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  int _getBatteryLevel(Map<String, dynamic> data) {
    return data['batteryLevel'] ?? 0;
  }

  Color _getBatteryColor(int level) {
    if (level > 50) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _simulateDeviceUpdate(String deviceId, String studentId) async {
    // Simulate device location update (In production, this comes from actual device)
    try {
      await FirebaseFirestore.instance
          .collection('deviceTracking')
          .doc('${widget.schoolId}_$deviceId')
          .set({
        'deviceId': deviceId,
        'studentId': studentId,
        'schoolId': widget.schoolId,
        'latitude': 5.6037 + (0.001 * (DateTime.now().second % 10)),
        'longitude': -0.1870 + (0.001 * (DateTime.now().second % 10)),
        'accuracy': 10.0,
        'speed': 0.0,
        'altitude': 100.0,
        'heading': 0.0,
        'batteryLevel': 85,
        'signalStrength': -70,
        'lastUpdate': FieldValue.serverTimestamp(),
        'isMoving': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device location updated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Device Tracking'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Devices'),
            Tab(text: 'Online'),
            Tab(text: 'Low Battery'),
            Tab(text: 'Alerts'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by device or student name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusIndicator('Online', Colors.green),
                    const SizedBox(width: 16),
                    _buildStatusIndicator('Idle', Colors.orange),
                    const SizedBox(width: 16),
                    _buildStatusIndicator('Offline', Colors.red),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeviceList(null),
                _buildDeviceList('online'),
                _buildDeviceList('lowbattery'),
                _buildAlertsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDeviceList(String? filter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('devices')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('isAssigned', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.devices_other, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No devices tracking yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        var devices = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final deviceId = (data['deviceId'] ?? '').toLowerCase();
          final studentName = (data['assignedToStudentName'] ?? '').toLowerCase();

          // Search filter
          if (_searchQuery.isNotEmpty) {
            if (!deviceId.contains(_searchQuery) && !studentName.contains(_searchQuery)) {
              return false;
            }
          }

          return true;
        }).toList();

        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: _loadDeviceTracking(devices),
          builder: (context, trackingSnapshot) {
            if (!trackingSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final trackingData = trackingSnapshot.data!;

            // Apply status filters
            var filteredDevices = devices.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final deviceId = data['deviceId'];
              final tracking = trackingData[deviceId] ?? {};

              if (filter == 'online') {
                return _getDeviceStatus(tracking) == 'online';
              } else if (filter == 'lowbattery') {
                return _getBatteryLevel(tracking) < 30;
              }

              return true;
            }).toList();

            if (filteredDevices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      filter == 'online'
                          ? 'No devices online'
                          : 'No low battery devices',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDevices.length,
              itemBuilder: (context, index) {
                final deviceDoc = filteredDevices[index];
                final deviceData = deviceDoc.data() as Map<String, dynamic>;
                final tracking = trackingData[deviceData['deviceId']] ?? {};
                return _buildDeviceTrackingCard(deviceDoc.id, deviceData, tracking);
              },
            );
          },
        );
      },
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadDeviceTracking(
      List<QueryDocumentSnapshot> devices) async {
    Map<String, Map<String, dynamic>> trackingData = {};

    for (var doc in devices) {
      final data = doc.data() as Map<String, dynamic>;
      final deviceId = data['deviceId'];

      try {
        final trackingDoc = await FirebaseFirestore.instance
            .collection('deviceTracking')
            .doc('${widget.schoolId}_$deviceId')
            .get();

        if (trackingDoc.exists) {
          trackingData[deviceId] = trackingDoc.data()!;
        }
      } catch (e) {
        debugPrint('Error loading tracking for $deviceId: $e');
      }
    }

    return trackingData;
  }

  Widget _buildDeviceTrackingCard(
      String docId, Map<String, dynamic> deviceData, Map<String, dynamic> tracking) {
    final status = _getDeviceStatus(tracking);
    final statusColor = _getStatusColor(status);
    final batteryLevel = _getBatteryLevel(tracking);
    final batteryColor = _getBatteryColor(batteryLevel);
    final lastUpdate = tracking['lastUpdate'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.gps_fixed, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceData['assignedToStudentName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Device: ${deviceData['deviceId']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTrackingInfo(
                          Icons.battery_std,
                          'Battery',
                          '$batteryLevel%',
                          batteryColor,
                        ),
                      ),
                      Expanded(
                        child: _buildTrackingInfo(
                          Icons.schedule,
                          'Last Update',
                          lastUpdate != null
                              ? _getTimeAgo(lastUpdate.toDate())
                              : 'Never',
                          Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTrackingInfo(
                          Icons.speed,
                          'Speed',
                          '${tracking['speed'] ?? 0} km/h',
                          Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildTrackingInfo(
                          Icons.gps_fixed,
                          'Accuracy',
                          '${tracking['accuracy'] ?? 0}m',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (tracking['latitude'] != null && tracking['longitude'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lat: ${tracking['latitude'].toStringAsFixed(6)}, '
                            'Lng: ${tracking['longitude'].toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 11, color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeviceDetails(deviceData, tracking),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _simulateDeviceUpdate(
                      deviceData['deviceId'],
                      deviceData['assignedToStudentId'],
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildTrackingInfo(
      IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deviceAlerts')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('isResolved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No active alerts',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final alertDoc = snapshot.data!.docs[index];
            final alertData = alertDoc.data() as Map<String, dynamic>;
            return _buildAlertCard(alertDoc.id, alertData);
          },
        );
      },
    );
  }

  Widget _buildAlertCard(String alertId, Map<String, dynamic> alertData) {
    final alertType = alertData['alertType'] ?? 'unknown';
    final severity = alertData['severity'] ?? 'medium';

    Color alertColor;
    IconData alertIcon;

    switch (severity) {
      case 'critical':
        alertColor = Colors.red;
        alertIcon = Icons.error;
        break;
      case 'high':
        alertColor = Colors.orange;
        alertIcon = Icons.warning;
        break;
      default:
        alertColor = Colors.blue;
        alertIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withOpacity(0.3), width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: alertColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(alertIcon, color: alertColor),
        ),
        title: Text(
          alertData['message'] ?? 'Unknown Alert',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Device: ${alertData['deviceId']}'),
            Text('Student: ${alertData['studentName']}'),
            if (alertData['createdAt'] != null)
              Text(
                _getTimeAgo((alertData['createdAt'] as Timestamp).toDate()),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          onPressed: () => _resolveAlert(alertId),
          tooltip: 'Resolve',
        ),
      ),
    );
  }

  Future<void> _resolveAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection('deviceAlerts')
          .doc(alertId)
          .update({
        'isResolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': widget.adminId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert resolved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeviceDetails(
      Map<String, dynamic> deviceData, Map<String, dynamic> tracking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Device Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.person, 'Student',
                deviceData['assignedToStudentName'] ?? 'Unknown'),
            const Divider(),
            _buildDetailRow(
                Icons.devices, 'Device ID', deviceData['deviceId'] ?? 'N/A'),
            const Divider(),
            _buildDetailRow(Icons.category, 'Type',
                deviceData['deviceType'] ?? 'Unknown'),
            const Divider(),
            _buildDetailRow(Icons.battery_std, 'Battery',
                '${_getBatteryLevel(tracking)}%'),
            const Divider(),
            _buildDetailRow(
                Icons.signal_cellular_alt, 'Signal', '${tracking['signalStrength'] ?? 0} dBm'),
            const Divider(),
            _buildDetailRow(Icons.speed, 'Speed', '${tracking['speed'] ?? 0} km/h'),
            const Divider(),
            _buildDetailRow(Icons.height, 'Altitude', '${tracking['altitude'] ?? 0}m'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF667eea)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}