import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Security Patrol Log Screen
/// Allows security personnel to start patrols, add checkpoints, and track issues
///
/// Features:
/// - Start/End patrol sessions
/// - Add checkpoints with status and observations
/// - Auto-create incidents for major issues
/// - Real-time patrol tracking
/// - Comprehensive patrol history
class SecurityPatrolLogScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String schoolId;

  const SecurityPatrolLogScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.schoolId,
  });

  @override
  State<SecurityPatrolLogScreen> createState() => _SecurityPatrolLogScreenState();
}

class _SecurityPatrolLogScreenState extends State<SecurityPatrolLogScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _locationController = TextEditingController();
  final _observationsController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _selectedStatus = 'all_clear';
  String _selectedArea = 'Main Gate';

  // Data
  List<Map<String, dynamic>> _patrolLogs = [];
  Map<String, dynamic>? _activePatrol;

  // Constants
  final List<String> _statusOptions = [
    'all_clear',
    'minor_issue',
    'major_issue',
    'emergency',
  ];

  final List<String> _areaOptions = [
    'Main Gate',
    'Back Gate',
    'Playground',
    'Parking Lot',
    'Building A',
    'Building B',
    'Building C',
    'Cafeteria',
    'Library',
    'Sports Field',
    'Perimeter',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  /// Initialize screen data
  Future<void> _initializeScreen() async {
    await Future.wait([
      _loadPatrolLogs(),
      _checkActivePatrol(),
    ]);
  }

  /// Load patrol logs from Firestore
  Future<void> _loadPatrolLogs() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final snapshot = await _firestore
          .collection('patrolLogs')
          .where('schoolId', isEqualTo: widget.schoolId)
          .orderBy('startTime', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          _patrolLogs = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading patrol logs: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
        _showErrorSnackBar('Failed to load patrol logs');
      }
    }
  }

  /// Check for active patrol session
  Future<void> _checkActivePatrol() async {
    try {
      final snapshot = await _firestore
          .collection('patrolLogs')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('securityPersonnelId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _activePatrol = {
            'id': snapshot.docs.first.id,
            ...snapshot.docs.first.data(),
          };
        });
      }
    } catch (e) {
      debugPrint('Error checking active patrol: $e');
    }
  }

  /// Start a new patrol session
  Future<void> _startPatrol() async {
    if (_isLoading) return;

    // Confirm start
    final shouldStart = await _showConfirmDialog(
      title: 'Start Patrol',
      message: 'Are you ready to start a new security patrol?',
      confirmText: 'Start',
      confirmColor: Colors.green,
    );

    if (shouldStart != true) return;

    setState(() => _isLoading = true);

    try {
      final patrolData = {
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'status': 'active',
        'checkpoints': [],
        'totalCheckpoints': 0,
        'issuesFound': 0,
      };

      final docRef = await _firestore.collection('patrolLogs').add(patrolData);

      // Log activity
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity': 'Started security patrol',
        'type': 'patrol',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _activePatrol = {
            'id': docRef.id,
            ...patrolData,
          };
          _isLoading = false;
        });
      }

      await _loadPatrolLogs();

      if (mounted) {
        _showSuccessSnackBar('Patrol started successfully');
      }
    } catch (e) {
      debugPrint('Error starting patrol: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to start patrol. Please try again.');
      }
    }
  }

  /// Add a checkpoint to active patrol
  Future<void> _addCheckpoint() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_activePatrol == null) {
      _showErrorSnackBar('No active patrol session');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final checkpoint = {
        'area': _selectedArea,
        'location': _locationController.text.trim(),
        'status': _selectedStatus,
        'observations': _observationsController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Calculate issues increment
      final issuesIncrement = _selectedStatus != 'all_clear' ? 1 : 0;

      await _firestore
          .collection('patrolLogs')
          .doc(_activePatrol!['id'])
          .update({
        'checkpoints': FieldValue.arrayUnion([checkpoint]),
        'totalCheckpoints': FieldValue.increment(1),
        'issuesFound': FieldValue.increment(issuesIncrement),
      });

      // Create incident for major issues or emergencies
      if (_selectedStatus == 'major_issue' || _selectedStatus == 'emergency') {
        await _createIncidentFromCheckpoint(checkpoint);
      }

      // Refresh active patrol data
      final updatedDoc = await _firestore
          .collection('patrolLogs')
          .doc(_activePatrol!['id'])
          .get();

      if (mounted) {
        setState(() {
          _activePatrol = {'id': updatedDoc.id, ...updatedDoc.data()!};
          _isLoading = false;
        });

        // Clear form
        _locationController.clear();
        _observationsController.clear();
        setState(() {
          _selectedStatus = 'all_clear';
          _selectedArea = 'Main Gate';
        });

        Navigator.pop(context);
        _showSuccessSnackBar('Checkpoint added successfully');
      }
    } catch (e) {
      debugPrint('Error adding checkpoint: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to add checkpoint');
      }
    }
  }

  /// Create incident report from checkpoint
  Future<void> _createIncidentFromCheckpoint(
      Map<String, dynamic> checkpoint) async {
    try {
      final incidentNumber = 'INC${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('incidents').add({
        'incidentNumber': incidentNumber,
        'title': 'Patrol Alert: ${_formatStatus(checkpoint['status'])}',
        'description': checkpoint['observations'],
        'category': 'safety_hazard',
        'severity': checkpoint['status'] == 'emergency' ? 'critical' : 'high',
        'location': '${checkpoint['area']} - ${checkpoint['location']}',
        'schoolId': widget.schoolId,
        'reportedBy': widget.userId,
        'reportedByName': widget.userName,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'open',
        'source': 'patrol',
      });

      // Notify admins of critical incident
      await _notifyAdminsOfIncident(incidentNumber, checkpoint);
    } catch (e) {
      debugPrint('Error creating incident: $e');
    }
  }

  /// Notify administrators of critical incident
  Future<void> _notifyAdminsOfIncident(
      String incidentNumber, Map<String, dynamic> checkpoint) async {
    try {
      final adminsSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('roleId', whereIn: ['ROL0001', 'ROL0006'])
          .get();

      for (var admin in adminsSnapshot.docs) {
        await _firestore.collection('notifications').add({
          'userId': admin.id,
          'title': '⚠️ Critical Patrol Alert',
          'message':
          'Incident #$incidentNumber: ${_formatStatus(checkpoint['status'])} at ${checkpoint['area']}. Reported by ${widget.userName}.',
          'type': 'patrol_incident',
          'priority': 'critical',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }

  /// End active patrol session
  Future<void> _endPatrol() async {
    if (_activePatrol == null || _isLoading) return;

    final totalCheckpoints = _activePatrol!['totalCheckpoints'] ?? 0;

    // Confirm end
    final shouldEnd = await _showConfirmDialog(
      title: 'End Patrol',
      message: 'Are you sure you want to end this patrol session?\n\nTotal checkpoints: $totalCheckpoints',
      confirmText: 'End Patrol',
      confirmColor: Colors.red,
    );

    if (shouldEnd != true) return;

    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('patrolLogs')
          .doc(_activePatrol!['id'])
          .update({
        'endTime': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // Log activity
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity':
        'Completed security patrol ($totalCheckpoints checkpoints)',
        'type': 'patrol',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _activePatrol = null;
          _isLoading = false;
        });
      }

      await _loadPatrolLogs();

      if (mounted) {
        _showSuccessSnackBar('Patrol completed successfully');
      }
    } catch (e) {
      debugPrint('Error ending patrol: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to end patrol');
      }
    }
  }

  /// Show add checkpoint dialog
  void _showAddCheckpointDialog() {
    _locationController.clear();
    _observationsController.clear();

    setState(() {
      _selectedStatus = 'all_clear';
      _selectedArea = 'Main Gate';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_location,
                            color: Colors.indigo,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add Checkpoint',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: _selectedArea,
                      decoration: InputDecoration(
                        labelText: 'Area *',
                        prefixIcon: const Icon(Icons.place),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _areaOptions.map((area) {
                        return DropdownMenuItem(
                          value: area,
                          child: Text(area),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => _selectedArea = value);
                          setState(() => _selectedArea = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Specific Location *',
                        hintText: 'e.g., Near entrance, Corner bench',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) =>
                      value?.trim().isEmpty ?? true
                          ? 'Location is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status *',
                        prefixIcon: const Icon(Icons.check_circle),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 12,
                                color: _getStatusColor(status),
                              ),
                              const SizedBox(width: 8),
                              Text(_formatStatus(status)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => _selectedStatus = value);
                          setState(() => _selectedStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _observationsController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Observations *',
                        hintText: 'Describe what you observed in detail...',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.description),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        alignLabelWithHint: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) => value?.trim().isEmpty ?? true
                          ? 'Observations are required'
                          : value!.trim().length < 10
                          ? 'Please provide more details (min 10 characters)'
                          : null,
                    ),
                    if (_selectedStatus == 'major_issue' ||
                        _selectedStatus == 'emergency') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'An incident report will be auto-created and admins will be notified',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _addCheckpoint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                : const Text('Add Checkpoint'),
                          ),
                        ),
                      ],
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

  /// Show patrol details
  void _showPatrolDetails(Map<String, dynamic> patrol) {
    final startTime = patrol['startTime'] as Timestamp?;
    final endTime = patrol['endTime'] as Timestamp?;
    final checkpoints =
        (patrol['checkpoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final duration = startTime != null && endTime != null
        ? endTime.toDate().difference(startTime.toDate())
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 32,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Security Patrol',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By ${patrol['securityPersonnelName'] ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: patrol['status'] == 'active'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      patrol['status'] == 'active' ? 'ACTIVE' : 'COMPLETED',
                      style: TextStyle(
                        color: patrol['status'] == 'active'
                            ? Colors.green
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Statistics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Checkpoints',
                      patrol['totalCheckpoints']?.toString() ?? '0',
                      Icons.location_on,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Issues',
                      patrol['issuesFound']?.toString() ?? '0',
                      Icons.warning,
                      (patrol['issuesFound'] ?? 0) > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Time Information
              _buildInfoRow(
                'Started',
                startTime != null
                    ? DateFormat('MMM d, yyyy hh:mm a').format(startTime.toDate())
                    : 'Unknown',
                Icons.play_arrow,
              ),
              if (endTime != null)
                _buildInfoRow(
                  'Ended',
                  DateFormat('MMM d, yyyy hh:mm a').format(endTime.toDate()),
                  Icons.stop,
                ),
              if (duration != null)
                _buildInfoRow(
                  'Duration',
                  '${duration.inHours}h ${duration.inMinutes % 60}m',
                  Icons.timer,
                ),

              // Checkpoints Section
              if (checkpoints.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text(
                      'Checkpoints',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${checkpoints.length} total',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...checkpoints.asMap().entries.map((entry) {
                  return _buildCheckpointCard(entry.key, entry.value);
                }).toList(),
              ] else ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No checkpoints added yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build checkpoint card
  Widget _buildCheckpointCard(int index, Map<String, dynamic> checkpoint) {
    final timestamp = checkpoint['timestamp'] as Timestamp?;
    final status = checkpoint['status'] ?? 'all_clear';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Checkpoint number
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Location info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkpoint['area'] ?? 'Unknown Area',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      checkpoint['location'] ?? 'Unknown Location',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatStatus(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Observations
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              checkpoint['observations'] ?? 'No observations',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          // Timestamp
          if (timestamp != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('hh:mm a').format(timestamp.toDate()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build info row
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

  /// Build stat card
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Format status string
  String _formatStatus(String status) {
    return status
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'all_clear':
        return Colors.green;
      case 'minor_issue':
        return Colors.orange;
      case 'major_issue':
        return Colors.red;
      case 'emergency':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  /// Show confirmation dialog
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error snackbar
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Patrol'),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _loadPatrolLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatrolLogs,
        child: Column(
          children: [
            // Active Patrol Banner
            if (_activePatrol != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.green[200]!),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Pulsing dot
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Patrol in Progress',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_activePatrol!['totalCheckpoints'] ?? 0} checkpoints',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _showAddCheckpointDialog,
                            icon: const Icon(Icons.add_location, size: 20),
                            label: const Text('Add Checkpoint'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _endPatrol,
                            icon: const Icon(Icons.stop_circle, size: 20),
                            label: const Text('End Patrol'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Patrol Logs List
            Expanded(
              child: _isRefreshing && _patrolLogs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _patrolLogs.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.security,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No patrol logs yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start your first security patrol',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (_activePatrol == null) ...[
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _startPatrol,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Patrol'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _patrolLogs.length,
                itemBuilder: (context, index) {
                  final patrol = _patrolLogs[index];
                  final startTime = patrol['startTime'] as Timestamp?;
                  final isActive = patrol['status'] == 'active';
                  final issuesFound = patrol['issuesFound'] ?? 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isActive ? 4 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isActive
                          ? const BorderSide(
                        color: Colors.green,
                        width: 2,
                      )
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () => _showPatrolDetails(patrol),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.security,
                                color: Colors.indigo,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patrol['securityPersonnelName'] ??
                                        'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (startTime != null)
                                    Text(
                                      DateFormat('MMM d, yyyy • hh:mm a')
                                          .format(startTime.toDate()),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${patrol['totalCheckpoints'] ?? 0} checkpoints',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (issuesFound > 0) ...[
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.warning,
                                          size: 14,
                                          color: Colors.red[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$issuesFound issues',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Status badge
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIVE' : 'DONE',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _activePatrol == null
          ? FloatingActionButton.extended(
        onPressed: _isLoading ? null : _startPatrol,
        backgroundColor: Colors.indigo,
        icon: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(Icons.play_arrow),
        label: Text(_isLoading ? 'Starting...' : 'Start Patrol'),
      )
          : null,
    );
  }
}