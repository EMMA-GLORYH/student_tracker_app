import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class VerifyDriversScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String schoolId;

  const VerifyDriversScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.schoolId,
  });

  @override
  State<VerifyDriversScreen> createState() => _VerifyDriversScreenState();
}

class _VerifyDriversScreenState extends State<VerifyDriversScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isScanning = false;
  bool _isLoading = false;

  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      final snapshot = await _firestore
          .collection('drivers')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          _drivers = snapshot.docs
              .map((doc) => {
            'id': doc.id,
            ...doc.data(),
          })
              .toList();
          _filteredDrivers = _drivers;
        });
      }
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    }
  }

  void _filterDrivers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDrivers = _drivers;
      } else {
        _filteredDrivers = _drivers.where((driver) {
          final name = (driver['name'] ?? '').toLowerCase();
          final busNumber = (driver['busNumber'] ?? '').toLowerCase();
          final licenseNumber = (driver['licenseNumber'] ?? '').toLowerCase();
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) ||
              busNumber.contains(searchLower) ||
              licenseNumber.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _verifyDriver(Map<String, dynamic> driver, bool isAuthorized) async {
    setState(() => _isLoading = true);

    try {
      final verification = {
        'driverId': driver['id'],
        'driverName': driver['name'],
        'busNumber': driver['busNumber'],
        'licenseNumber': driver['licenseNumber'],
        'schoolId': widget.schoolId,
        'verifiedBy': widget.userId,
        'verifiedByName': widget.userName,
        'isAuthorized': isAuthorized,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verificationMethod': _isScanning ? 'QR Code' : 'Manual',
      };

      await _firestore.collection('driverVerifications').add(verification);

      // Log activity
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity': isAuthorized
            ? 'Verified driver: ${driver['name']}'
            : 'Denied entry to unauthorized driver',
        'type': 'driver',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // If unauthorized, send alerts
      if (!isAuthorized) {
        await _sendUnauthorizedDriverAlert(driver);
      }

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAuthorized
                  ? 'Driver verified successfully!'
                  : 'Unauthorized driver - Alerts sent!',
            ),
            backgroundColor: isAuthorized ? Colors.green : Colors.red,
          ),
        );

        if (_isScanning) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error verifying driver: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error verifying driver'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendUnauthorizedDriverAlert(Map<String, dynamic> driver) async {
    try {
      // Create emergency alert
      await _firestore.collection('emergencyAlerts').add({
        'schoolId': widget.schoolId,
        'type': 'unauthorized_driver',
        'severity': 'high',
        'driverInfo': {
          'name': driver['name'],
          'busNumber': driver['busNumber'],
          'licenseNumber': driver['licenseNumber'],
        },
        'reportedBy': widget.userId,
        'reportedByName': widget.userName,
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get admin users
      final admins = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('roleId', whereIn: ['ROL0001', 'ROL0006'])
          .get();

      // Send notifications to admins
      for (var admin in admins.docs) {
        await _firestore.collection('notifications').add({
          'userId': admin.id,
          'title': 'Unauthorized Driver Alert',
          'message':
          'An unauthorized driver attempted to pick up students. Verified by ${widget.userName}.',
          'type': 'security_alert',
          'priority': 'high',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error sending alerts: $e');
    }
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver['name'] ?? 'Unknown Driver',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Authorized Driver',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Bus Number', driver['busNumber'] ?? 'N/A', Icons.directions_bus),
              _buildInfoRow('License Number', driver['licenseNumber'] ?? 'N/A', Icons.badge),
              _buildInfoRow('Phone', driver['phone'] ?? 'N/A', Icons.phone),
              _buildInfoRow('Email', driver['email'] ?? 'N/A', Icons.email),
              const SizedBox(height: 24),
              const Text(
                'Verification Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                        Navigator.pop(context);
                        _verifyDriver(driver, true);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Verify Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                        Navigator.pop(context);
                        _verifyDriver(driver, false);
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text('Deny Entry'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQRScan(String driverId) async {
    try {
      final driverDoc = await _firestore.collection('drivers').doc(driverId).get();

      if (!driverDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver not found!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final driver = {'id': driverDoc.id, ...driverDoc.data()!};

      if (mounted) {
        Navigator.pop(context);
        _showDriverDetails(driver);
      }
    } catch (e) {
      debugPrint('Error handling QR scan: $e');
    }
  }

  void _showQRScanner() {
    setState(() => _isScanning = true);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Scan Driver QR Code'),
            backgroundColor: Colors.orange,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty || _isLoading) return;

              final String? driverId = barcodes.first.rawValue;
              if (driverId != null) {
                _handleQRScan(driverId);
              }
            },
          ),
        ),
      ),
    ).then((_) {
      setState(() => _isScanning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Drivers'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _showQRScanner,
            tooltip: 'Scan QR Code',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.withOpacity(0.1),
            child: TextField(
              controller: _searchController,
              onChanged: _filterDrivers,
              decoration: InputDecoration(
                hintText: 'Search by name, bus, or license...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredDrivers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.directions_bus, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No drivers found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredDrivers.length,
              itemBuilder: (context, index) {
                final driver = _filteredDrivers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.orange,
                      ),
                    ),
                    title: Text(
                      driver['name'] ?? 'Unknown Driver',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Bus: ${driver['busNumber'] ?? 'N/A'}'),
                        Text('License: ${driver['licenseNumber'] ?? 'N/A'}'),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showDriverDetails(driver),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
