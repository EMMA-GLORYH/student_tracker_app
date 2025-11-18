import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmergencyAlertsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String schoolId;

  const EmergencyAlertsScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.schoolId,
  });

  @override
  State<EmergencyAlertsScreen> createState() => _EmergencyAlertsScreenState();
}

class _EmergencyAlertsScreenState extends State<EmergencyAlertsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  String _selectedAlertType = 'emergency';
  String _selectedSeverity = 'high';
  String _selectedLocation = 'Main Gate';

  List<Map<String, dynamic>> _activeAlerts = [];
  List<Map<String, dynamic>> _recentAlerts = [];

  final List<String> _alertTypes = [
    'emergency',
    'fire',
    'medical',
    'intruder',
    'suspicious_activity',
    'unauthorized_entry',
    'other',
  ];

  final List<String> _severityLevels = [
    'critical',
    'high',
    'medium',
    'low',
  ];

  final List<String> _locations = [
    'Main Gate',
    'Back Gate',
    'Playground',
    'Parking Lot',
    'Building A',
    'Building B',
    'Cafeteria',
    'Library',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    try {
      // Get active alerts
      final activeSnapshot = await _firestore
          .collection('emergencyAlerts')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('status', isEqualTo: 'active')
          .orderBy('timestamp', descending: true)
          .get();

      // Get recent alerts (last 24 hours)
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final recentSnapshot = await _firestore
          .collection('emergencyAlerts')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _activeAlerts = activeSnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _recentAlerts = recentSnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    }
  }

  Future<void> _triggerAlert() async {
    setState(() => _isLoading = true);

    try {
      final alertData = {
        'schoolId': widget.schoolId,
        'type': _selectedAlertType,
        'severity': _selectedSeverity,
        'location': _selectedLocation,
        'description': _descriptionController.text.trim(),
        'triggeredBy': widget.userId,
        'triggeredByName': widget.userName,
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'resolvedBy': null,
        'responseNotes': '',
      };

      await _firestore.collection('emergencyAlerts').add(alertData);

      // Notify all administrators and relevant personnel
      await _notifyEmergencyContacts();

      // Log activity
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity': 'Triggered ${_selectedAlertType} alert at $_selectedLocation',
        'type': 'emergency',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _loadAlerts();

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency alert sent successfully!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error triggering alert: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sending alert'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _notifyEmergencyContacts() async {
    try {
      // Get all admins and security personnel
      final usersSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('roleId', whereIn: ['ROL0001', 'ROL0004', 'ROL0006'])
          .get();

      final message = 'EMERGENCY: ${_selectedAlertType.toUpperCase()} alert at $_selectedLocation. '
          'Severity: ${_selectedSeverity.toUpperCase()}. '
          'Description: ${_descriptionController.text.trim()}';

      for (var user in usersSnapshot.docs) {
        await _firestore.collection('notifications').add({
          'userId': user.id,
          'title': '🚨 EMERGENCY ALERT',
          'message': message,
          'type': 'emergency',
          'priority': 'critical',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error notifying contacts: $e');
    }
  }

  Future<void> _resolveAlert(Map<String, dynamic> alert) async {
    final notesController = TextEditingController();

    final shouldResolve = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resolve Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to resolve this alert?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Resolution Notes',
                hintText: 'Enter details about how the alert was resolved...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (shouldResolve == true) {
      try {
        await _firestore.collection('emergencyAlerts').doc(alert['id']).update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': widget.userId,
          'resolvedByName': widget.userName,
          'responseNotes': notesController.text.trim(),
        });

        // Log activity
        await _firestore.collection('securityLogs').add({
          'schoolId': widget.schoolId,
          'securityPersonnelId': widget.userId,
          'securityPersonnelName': widget.userName,
          'activity': 'Resolved ${alert['type']} alert',
          'type': 'emergency',
          'timestamp': FieldValue.serverTimestamp(),
        });

        await _loadAlerts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alert resolved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error resolving alert: $e');
      }
    }

    notesController.dispose();
  }

  void _showTriggerAlertDialog() {
    _descriptionController.clear();
    setState(() {
      _selectedAlertType = 'emergency';
      _selectedSeverity = 'high';
      _selectedLocation = 'Main Gate';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Text('Trigger Alert'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alert Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedAlertType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: _alertTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_formatAlertType(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => _selectedAlertType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Severity Level',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSeverity,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: _severityLevels.map((severity) {
                    return DropdownMenuItem(
                      value: severity,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _getSeverityColor(severity),
                          ),
                          const SizedBox(width: 8),
                          Text(severity.toUpperCase()),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => _selectedSeverity = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedLocation,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: _locations.map((location) {
                    return DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => _selectedLocation = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe the emergency situation...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _triggerAlert,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('TRIGGER ALERT'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    final timestamp = alert['timestamp'] as Timestamp?;
    final resolvedAt = alert['resolvedAt'] as Timestamp?;

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
                      color: _getSeverityColor(alert['severity'] ?? 'high')
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getAlertIcon(alert['type'] ?? 'emergency'),
                      size: 32,
                      color: _getSeverityColor(alert['severity'] ?? 'high'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatAlertType(alert['type'] ?? 'Emergency'),
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
                            color: alert['status'] == 'active'
                                ? Colors.red.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            alert['status'] == 'active' ? 'ACTIVE' : 'RESOLVED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: alert['status'] == 'active'
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow(
                'Severity',
                (alert['severity'] ?? 'Unknown').toUpperCase(),
                Icons.warning,
              ),
              _buildInfoRow(
                'Location',
                alert['location'] ?? 'Unknown',
                Icons.location_on,
              ),
              _buildInfoRow(
                'Triggered By',
                alert['triggeredByName'] ?? 'Unknown',
                Icons.person,
              ),
              _buildInfoRow(
                'Time',
                timestamp != null
                    ? DateFormat('MMM d, yyyy hh:mm a').format(timestamp.toDate())
                    : 'Unknown',
                Icons.access_time,
              ),
              if (alert['description']?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    alert['description'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              if (resolvedAt != null) ...[
                const SizedBox(height: 16),
                _buildInfoRow(
                  'Resolved At',
                  DateFormat('MMM d, yyyy hh:mm a').format(resolvedAt.toDate()),
                  Icons.check_circle,
                ),
                _buildInfoRow(
                  'Resolved By',
                  alert['resolvedByName'] ?? 'Unknown',
                  Icons.person,
                ),
                if (alert['responseNotes']?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Resolution Notes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      alert['responseNotes'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              if (alert['status'] == 'active')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _resolveAlert(alert);
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Resolve Alert'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
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

  String _formatAlertType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red[900]!;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'fire':
        return Icons.local_fire_department;
      case 'medical':
        return Icons.medical_services;
      case 'intruder':
        return Icons.person_off;
      case 'suspicious_activity':
        return Icons.visibility;
      case 'unauthorized_entry':
        return Icons.block;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alerts'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          if (_activeAlerts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red[50],
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_activeAlerts.length} Active Alert${_activeAlerts.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _recentAlerts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No alerts in the last 24 hours',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recentAlerts.length,
              itemBuilder: (context, index) {
                final alert = _recentAlerts[index];
                final isActive = alert['status'] == 'active';
                final timestamp = alert['timestamp'] as Timestamp?;
                final severity = alert['severity'] ?? 'high';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isActive ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isActive
                        ? BorderSide(
                      color: _getSeverityColor(severity),
                      width: 2,
                    )
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getSeverityColor(severity).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getAlertIcon(alert['type'] ?? 'emergency'),
                        color: _getSeverityColor(severity),
                      ),
                    ),
                    title: Text(
                      _formatAlertType(alert['type'] ?? 'Emergency'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Location: ${alert['location'] ?? 'Unknown'}'),
                        Text('Severity: ${severity.toUpperCase()}'),
                        if (timestamp != null)
                          Text(
                            DateFormat('MMM d, hh:mm a')
                                .format(timestamp.toDate()),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'ACTIVE' : 'RESOLVED',
                        style: TextStyle(
                          color: isActive ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    onTap: () => _showAlertDetails(alert),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTriggerAlertDialog,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.warning_amber_rounded),
        label: const Text('Trigger Alert'),
      ),
    );
  }
}