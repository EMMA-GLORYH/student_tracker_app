import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_profile.dart'; // Import the profile page

class DriverDashboard extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String schoolId;

  const DriverDashboard({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.schoolId,
  });

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _profileComplete = false;
  bool _accountActive = true;
  int _studentsOnBoard = 0;
  int _tripsCompleted = 0;
  List<Map<String, dynamic>> _todayActivity = [];

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();
    _checkAccountStatus();
    _loadStudentsOnBoard();
    _loadTodayActivity();
  }

  Future<void> _checkProfileCompletion() async {
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('driver_profiles')
          .doc(widget.driverId)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data();
        final isComplete = data?['profileComplete'] == true &&
            data?['ghanaCardNumber'] != null &&
            data?['ghanaCardFront'] != null &&
            data?['ghanaCardBack'] != null;

        setState(() => _profileComplete = isComplete);

        if (!isComplete) {
          _showProfileIncompleteWarning();
        }
      }
    } catch (e) {
      debugPrint('Error checking profile: $e');
    }
  }

  Future<void> _checkAccountStatus() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.driverId)
          .get();

      if (userDoc.exists) {
        setState(() => _accountActive = userDoc['isActive'] ?? false);
      }
    } catch (e) {
      debugPrint('Error checking account status: $e');
    }
  }

  Future<void> _loadStudentsOnBoard() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('studentTransport')
          .where('driverId', isEqualTo: widget.driverId)
          .where('status', isEqualTo: 'on_board')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      setState(() => _studentsOnBoard = snapshot.docs.length);
    } catch (e) {
      debugPrint('Error loading students: $e');
    }
  }

  Future<void> _loadTodayActivity() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transport_logs')
          .where('driverId', isEqualTo: widget.driverId)
          .where('schoolId', isEqualTo: widget.schoolId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      setState(() {
        _todayActivity = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        _tripsCompleted = _todayActivity
            .where((activity) => activity['status'] == 'completed')
            .length;
      });
    } catch (e) {
      debugPrint('Error loading activity: $e');
    }
  }

  void _showProfileIncompleteWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.warning_amber_rounded,
            size: 48, color: Colors.orange[700]),
        title: const Text('Profile Incomplete'),
        content: const Text(
          'Your account has been deactivated for security reasons. Please complete your professional credentials to reactivate your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToProfilePage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfilePage() async {
    // Navigate to driver profile completion page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverProfilePage(
          driverId: widget.driverId,
          driverName: widget.driverName,
          schoolId: widget.schoolId,
        ),
      ),
    );

    // Refresh data if profile was updated
    if (result == true) {
      _checkProfileCompletion();
      _checkAccountStatus();
    }
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showSOSEmergency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.emergency_share_rounded,
            size: 48, color: Colors.red[700]),
        title: const Text('EMERGENCY - SOS ALERT'),
        content: const Text(
          'This will immediately alert:\n'
              '• School Administration\n'
              '• All Parents/Guardians\n'
              '• Security Personnel\n'
              '• Teachers\n\n'
              'Are you sure you need emergency assistance?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _selectSOSMessage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed to SOS'),
          ),
        ],
      ),
    );
  }

  void _selectSOSMessage() {
    final messages = [
      'Vehicle hijacked or stopped by armed robbers',
      'Serious vehicle accident - need immediate help',
      'Medical emergency with student - urgent',
      'Vehicle breakdown on route',
      'Traffic incident - student safety concern',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Alert Message'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: messages
                .map(
                  (msg) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(msg),
                onTap: () {
                  Navigator.pop(context);
                  _sendSOSAlert(msg);
                },
              ),
            )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _sendSOSAlert(String message) async {
    try {
      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'driverId': widget.driverId,
        'driverName': widget.driverName,
        'schoolId': widget.schoolId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'studentsOnBoard': _studentsOnBoard,
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'sos_emergency',
        'schoolId': widget.schoolId,
        'title': 'EMERGENCY SOS ALERT',
        'message': '${widget.driverName}: $message',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SOS Alert sent to all recipients'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending SOS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markPickup(String studentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('studentTransport')
          .doc(studentId)
          .update({
        'status': 'on_board',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'pickedUpBy': widget.driverId,
      });

      await FirebaseFirestore.instance.collection('transport_logs').add({
        'driverId': widget.driverId,
        'studentId': studentId,
        'schoolId': widget.schoolId,
        'action': 'pickup',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student picked up successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStudentsOnBoard();
        _loadTodayActivity();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _markDropoff(String studentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('studentTransport')
          .doc(studentId)
          .update({
        'status': 'dropped_off',
        'droppedOffAt': FieldValue.serverTimestamp(),
        'droppedOffBy': widget.driverId,
      });

      await FirebaseFirestore.instance.collection('transport_logs').add({
        'driverId': widget.driverId,
        'studentId': studentId,
        'schoolId': widget.schoolId,
        'action': 'dropoff',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student dropped off successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadStudentsOnBoard();
        _loadTodayActivity();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_accountActive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driver Dashboard'),
          backgroundColor: const Color(0xFF1E88E5),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Account Deactivated',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please complete your profile verification',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _navigateToProfilePage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Complete Profile'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        actions: [
          if (!_profileComplete)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Profile Incomplete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _navigateToProfilePage,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showSignOutConfirmation,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(),
                const SizedBox(height: 20),
                _buildSOSButton(),
                const SizedBox(height: 24),
                _buildStatsSection(),
                const SizedBox(height: 24),
                _buildQuickActionsSection(),
                const SizedBox(height: 24),
                _buildActivitySection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (!_profileComplete)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade400,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Deactivated',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Complete your profile to activate',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToProfilePage,
                      child: const Text(
                        'Fix Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${widget.driverName}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Driver ID: ${widget.driverId}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: _showSOSEmergency,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.red.shade800],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.emergency_share_rounded,
              size: 40,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            const Text(
              'EMERGENCY - SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to alert school, parents & security',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Students On Board',
            _studentsOnBoard.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Trips Completed',
            _tripsCompleted.toString(),
            Icons.route,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionTile(
              icon: Icons.location_on,
              label: 'Pickup Student',
              color: Colors.green,
              onTap: () => _showPickupDialog(),
            ),
            _buildActionTile(
              icon: Icons.location_off,
              label: 'Dropoff Student',
              color: Colors.orange,
              onTap: () => _showDropoffDialog(),
            ),
            _buildActionTile(
              icon: Icons.map,
              label: 'View Route',
              color: Colors.blue,
              onTap: () {},
            ),
            _buildActionTile(
              icon: Icons.history,
              label: 'Activity Log',
              color: Colors.purple,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 40) / 2,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (_todayActivity.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No activity yet today',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: _todayActivity
                  .asMap()
                  .entries
                  .map((entry) {
                final activity = entry.value;
                final isLast =
                    entry.key == _todayActivity.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            activity['action'] == 'pickup'
                                ? Icons.person_add
                                : Icons.person_remove,
                            color: activity['action'] == 'pickup'
                                ? Colors.green
                                : Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity['action'] == 'pickup'
                                      ? 'Student Picked Up'
                                      : 'Student Dropped Off',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'ID: ${activity['studentId']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 0),
                  ],
                );
              })
                  .toList(),
            ),
          ),
      ],
    );
  }

  void _showPickupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark Student Pickup'),
        content: const Text('Confirm student pickup?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markPickup('student_id_123');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Pickup'),
          ),
        ],
      ),
    );
  }

  void _showDropoffDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark Student Dropoff'),
        content: const Text('Confirm student dropoff?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markDropoff('student_id_123');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Dropoff'),
          ),
        ],
      ),
    );
  }
}