import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'verify_drivers.dart';
import 'student_checkin_checkout.dart';
import 'visitor_management.dart';
import 'emergency_alerts.dart';
import 'incident_reporting.dart';
import 'parent_pickup_verification.dart';


/// Security Personnel Homepage
/// Professional dashboard with statistics, quick actions, and recent activities
class SecurityHomePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String schoolId;

  const SecurityHomePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.schoolId,
  });

  @override
  State<SecurityHomePage> createState() => _SecurityHomePageState();
}

class _SecurityHomePageState extends State<SecurityHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Statistics
  int _studentsPresent = 0;
  int _driversVerified = 0;
  int _visitorsToday = 0;
  int _activeAlerts = 0;
  bool _isLoading = true;

  // Recent activities
  List<Map<String, dynamic>> _recentActivities = [];

  // App info
  final String _appVersion = '1.0.0';
  final String _appName = 'S3TS Security';

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadRecentActivities();
  }

  /// Load statistics from Firestore
  Future<void> _loadStatistics() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get students present today
      final studentsSnapshot = await _firestore
          .collection('attendance')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('status', isEqualTo: 'present')
          .get();

      // Get drivers verified today
      final driversSnapshot = await _firestore
          .collection('driverVerifications')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('verifiedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Get visitors today
      final visitorsSnapshot = await _firestore
          .collection('visitors')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('visitDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Get active alerts
      final alertsSnapshot = await _firestore
          .collection('emergencyAlerts')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('status', isEqualTo: 'active')
          .get();

      if (mounted) {
        setState(() {
          _studentsPresent = studentsSnapshot.docs.length;
          _driversVerified = driversSnapshot.docs.length;
          _visitorsToday = visitorsSnapshot.docs.length;
          _activeAlerts = alertsSnapshot.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Load recent activities
  Future<void> _loadRecentActivities() async {
    try {
      final snapshot = await _firestore
          .collection('securityLogs')
          .where('schoolId', isEqualTo: widget.schoolId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (mounted) {
        setState(() {
          _recentActivities = snapshot.docs
              .map((doc) => {
            ...doc.data(),
            'id': doc.id,
          })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
    }
  }

  /// Log activity to Firestore
  Future<void> _logActivity(String activity, String type) async {
    try {
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity': activity,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _loadRecentActivities();
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  /// Show emergency alert dialog
  void _showEmergencyAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Emergency Alert'),
          ],
        ),
        content: const Text(
          'Are you sure you want to trigger an emergency alert? This will notify all administrators and relevant personnel immediately.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _triggerEmergencyAlert();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Trigger Alert'),
          ),
        ],
      ),
    );
  }

  /// Trigger emergency alert
  Future<void> _triggerEmergencyAlert() async {
    try {
      await _firestore.collection('emergencyAlerts').add({
        'schoolId': widget.schoolId,
        'triggeredBy': widget.userId,
        'triggeredByName': widget.userName,
        'type': 'emergency',
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
        'location': 'Security Gate',
      });

      await _logActivity('Emergency alert triggered', 'emergency');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Emergency alert sent successfully!')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _loadStatistics();
    } catch (e) {
      debugPrint('Error triggering alert: $e');
    }
  }

  /// Show logout confirmation dialog
  Future<bool> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Confirm Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout? You will need to login again to access the security dashboard.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    try {
      // Log logout activity
      await _logActivity('Security personnel logged out', 'auth');

      // Sign out from Firebase
      await _auth.signOut();

      if (mounted) {
        // Navigate to login page and remove all previous routes
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error logging out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle back button press
  Future<bool> _onWillPop() async {
    final shouldLogout = await _showLogoutDialog();
    if (shouldLogout) {
      await _handleLogout();
    }
    return false; // Prevent default back action
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Security Dashboard'),
          backgroundColor: Colors.orange,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadStatistics();
                _loadRecentActivities();
              },
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final shouldLogout = await _showLogoutDialog();
                if (shouldLogout) {
                  await _handleLogout();
                }
              },
              tooltip: 'Logout',
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _loadStatistics(),
              _loadRecentActivities(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.security,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${widget.userName}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, MMMM d, yyyy')
                                      .format(DateTime.now()),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Emergency Alert Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showEmergencyAlert,
                          icon: const Icon(Icons.warning_amber_rounded, size: 26),
                          label: const Text(
                            'EMERGENCY ALERT',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Statistics Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isLoading
                          ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                          : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Students\nPresent',
                                  _studentsPresent.toString(),
                                  Icons.people,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Drivers\nVerified',
                                  _driversVerified.toString(),
                                  Icons.directions_bus,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Visitors\nToday',
                                  _visitorsToday.toString(),
                                  Icons.badge,
                                  Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Active\nAlerts',
                                  _activeAlerts.toString(),
                                  Icons.warning,
                                  _activeAlerts > 0 ? Colors.red : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        children: [
                          _buildActionCard(
                            'Verify Driver',
                            Icons.directions_bus,
                            Colors.orange,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VerifyDriversScreen(
                                    userId: widget.userId,
                                    userName: widget.userName,
                                    schoolId: widget.schoolId,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            'Student Check',
                            Icons.how_to_reg,
                            Colors.blue,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentCheckInOutScreen(
                                    userId: widget.userId,
                                    userName: widget.userName,
                                    schoolId: widget.schoolId,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            'Visitor Entry',
                            Icons.badge,
                            Colors.purple,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisitorManagementScreen(
                                    userId: widget.userId,
                                    userName: widget.userName,
                                    schoolId: widget.schoolId,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            'Parent Pickup',
                            Icons.family_restroom,
                            Colors.green,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SecurityPatrolLogScreen(
                                    userId: widget.userId,
                                    userName: widget.userName,
                                    schoolId: widget.schoolId,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            'Report Incident',
                            Icons.report,
                            Colors.red,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => IncidentReportingScreen(
                                    userId: widget.userId,
                                    userName: widget.userName,
                                    schoolId: widget.schoolId,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            'Patrol Log',
                            Icons.security,
                            Colors.indigo,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SecurityPatrolLogScreen(
                                    userId: widget.userId,
                                    userName: widget.userName,
                                    schoolId: widget.schoolId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Recent Activities
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Activities',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_recentActivities.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                // Navigate to full activity log
                              },
                              child: const Text('View All'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _recentActivities.isEmpty
                          ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.history, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No recent activities',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentActivities.length,
                        itemBuilder: (context, index) {
                          final activity = _recentActivities[index];
                          return _buildActivityItem(activity);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build navigation drawer
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange, Colors.deepOrange],
          ),
        ),
        child: Column(
          children: [
            // Drawer Header
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 48,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _appName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $_appVersion',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.userName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Drawer Items
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.directions_bus,
                      title: 'Verify Drivers',
                      subtitle: 'Verify school bus drivers',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VerifyDriversScreen(
                              userId: widget.userId,
                              userName: widget.userName,
                              schoolId: widget.schoolId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.how_to_reg,
                      title: 'Student Check-In/Out',
                      subtitle: 'Track student movements',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentCheckInOutScreen(
                              userId: widget.userId,
                              userName: widget.userName,
                              schoolId: widget.schoolId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.badge,
                      title: 'Visitor Management',
                      subtitle: 'Register and track visitors',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VisitorManagementScreen(
                              userId: widget.userId,
                              userName: widget.userName,
                              schoolId: widget.schoolId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.family_restroom,
                      title: 'Parent Pickup',
                      subtitle: 'Verify authorized pickups',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SecurityPatrolLogScreen(
                              userId: widget.userId,
                              userName: widget.userName,
                              schoolId: widget.schoolId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.warning_amber,
                      title: 'Emergency Alerts',
                      subtitle: 'View and manage alerts',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmergencyAlertsScreen(
                              userId: widget.userId,
                              userName: widget.userName,
                              schoolId: widget.schoolId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.report,
                      title: 'Incident Reports',
                      subtitle: 'Report security incidents',
                      color: Colors.red[700]!,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IncidentReportingScreen(
                              userId: widget.userId,
                              userName: widget.userName,
                              schoolId: widget.schoolId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.security,
                      title: 'Security Patrol',
                      subtitle: 'Log patrol activities',
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SecurityPatrolLogScreen(
                              userId: widget.userId,
                              userName: widget.userName,
                              schoolId: widget.schoolId,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 32),
                    _buildDrawerItem(
                      icon: Icons.info_outline,
                      title: 'About',
                      subtitle: 'App information',
                      color: Colors.grey,
                      onTap: () {
                        Navigator.pop(context);
                        _showAboutDialog();
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      color: Colors.red,
                      onTap: () async {
                        Navigator.pop(context);
                        final shouldLogout = await _showLogoutDialog();
                        if (shouldLogout) {
                          await _handleLogout();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build drawer item
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  /// Show about dialog
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.security, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('About S3TS'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version: $_appVersion',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'School Safety and Security Tracking System',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'A comprehensive security management system designed to ensure the safety of students, staff, and visitors.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build statistics card
  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action card
  Widget _buildActionCard(
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build activity item
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final timestamp = activity['timestamp'] as Timestamp?;
    final timeStr = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp.toDate())
        : 'Unknown time';

    IconData icon;
    Color color;

    switch (activity['type']) {
      case 'driver':
        icon = Icons.directions_bus;
        color = Colors.orange;
        break;
      case 'student':
        icon = Icons.person;
        color = Colors.blue;
        break;
      case 'visitor':
        icon = Icons.badge;
        color = Colors.purple;
        break;
      case 'emergency':
        icon = Icons.warning;
        color = Colors.red;
        break;
      case 'patrol':
        icon = Icons.security;
        color = Colors.indigo;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['activity'] ?? 'Unknown activity',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
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
    );
  }
}