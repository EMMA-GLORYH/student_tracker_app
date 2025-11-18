import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:find_me/screens/messaging/messaging_page.dart';
import 'package:find_me/screens/school_admins/add_students.dart';
import 'package:find_me/screens/school_admins/assign_device.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:find_me/screens/school_admins/school_profile_page.dart';
import 'package:find_me/screens/school_admins/verify_student_assignment.dart';

class SchoolAdminPage extends StatefulWidget {
  final String userId;
  final String schoolId;
  final String userName;

  const SchoolAdminPage({
    super.key,
    required this.userId,
    required this.schoolId,
    required this.userName,
  });

  @override
  State<SchoolAdminPage> createState() => _SchoolAdminPageState();
}

class _SchoolAdminPageState extends State<SchoolAdminPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String _schoolName = '';
  bool _isLoading = true;
  bool _isLoggingOut = false;

  // ✅ Animation controller for 3-dot loading
  late AnimationController _dotsController;

  // Search controller for real-time search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Statistics
  int _totalTeachers = 0;
  int _totalParents = 0;
  int _totalDrivers = 0;
  int _totalSecurity = 0;
  int _pendingApprovals = 0;
  int _totalStudents = 0;
  int _studentsOnCompound = 0;
  int _studentsOffCompound = 0;

  // School Profile
  Map<String, dynamic> _schoolProfile = {};

  // ✅ Navy Blue Colors (Professional Theme)
  static const Color navyDark = Color(0xFF0A1929);
  static const Color navyBlue = Color(0xFF1A2F3F);
  static const Color navyButton = Color(0xFF667eea);

  @override
  void initState() {
    super.initState();

    // ✅ Initialize animation controller for loading dots
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _loadSchoolData();
    _loadStatistics();
    _loadSchoolProfile();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchoolData() async {
    try {
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();

      if (schoolDoc.exists && mounted) {
        setState(() {
          _schoolName = schoolDoc.data()?['schoolName'] ?? 'School';
          _isLoading = false;
        });
        debugPrint('✅ School data loaded: $_schoolName');
      }
    } catch (e) {
      debugPrint('❌ Error loading school data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load school information');
      }
    }
  }

  Future<void> _loadSchoolProfile() async {
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('schoolProfiles')
          .doc(widget.schoolId)
          .get();

      if (profileDoc.exists && mounted) {
        setState(() {
          _schoolProfile = profileDoc.data() ?? {};
        });
        debugPrint('✅ School profile loaded');
      }
    } catch (e) {
      debugPrint('❌ Error loading school profile: $e');
    }
  }

  // ✅ FIXED: Proper error handling without QuerySnapshot.fromDocuments
  Future<void> _loadStatistics() async {
    try {
      debugPrint('📊 Loading statistics...');

      // Helper function to safely execute queries
      Future<QuerySnapshot> safeQuery(Future<QuerySnapshot> query) async {
        try {
          return await query;
        } catch (e) {
          debugPrint('⚠️ Query failed: $e');
          // Return empty query snapshot by creating a query that matches nothing
          return FirebaseFirestore.instance
              .collection('_nonexistent')
              .limit(0)
              .get();
        }
      }

      // Load all data in parallel with safe error handling
      final results = await Future.wait([
        safeQuery(FirebaseFirestore.instance
            .collection('pendingAccounts')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('status', isEqualTo: 'pending')
            .get()),
        safeQuery(FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('roleId', isEqualTo: 'ROL0002')
            .where('isActive', isEqualTo: true)
            .get()),
        safeQuery(FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('roleId', isEqualTo: 'ROL0003')
            .where('isActive', isEqualTo: true)
            .get()),
        safeQuery(FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('roleId', isEqualTo: 'ROL0005')
            .where('isActive', isEqualTo: true)
            .get()),
        safeQuery(FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('roleId', isEqualTo: 'ROL0004')
            .where('isActive', isEqualTo: true)
            .get()),
        safeQuery(FirebaseFirestore.instance
            .collection('students')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('isActive', isEqualTo: true)
            .get()),
      ]);

      final pendingSnapshot = results[0];
      final teachersSnapshot = results[1];
      final parentsSnapshot = results[2];
      final driversSnapshot = results[3];
      final securitySnapshot = results[4];
      final studentsSnapshot = results[5];

      // Count students on/off compound
      int onCompound = 0;
      int offCompound = 0;
      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          if (data['isOnCompound'] == true) {
            onCompound++;
          } else {
            offCompound++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _pendingApprovals = pendingSnapshot.docs.length;
          _totalTeachers = teachersSnapshot.docs.length;
          _totalParents = parentsSnapshot.docs.length;
          _totalDrivers = driversSnapshot.docs.length;
          _totalSecurity = securitySnapshot.docs.length;
          _totalStudents = studentsSnapshot.docs.length;
          _studentsOnCompound = onCompound;
          _studentsOffCompound = offCompound;
        });

        debugPrint('✅ Statistics loaded successfully');
        debugPrint('📊 Teachers: $_totalTeachers | Parents: $_totalParents');
        debugPrint('🚗 Drivers: $_totalDrivers | 🔒 Security: $_totalSecurity');
        debugPrint('🎓 Students: $_totalStudents (On: $_studentsOnCompound, Off: $_studentsOffCompound)');
        debugPrint('⏳ Pending: $_pendingApprovals');
      }
    } catch (e) {
      debugPrint('❌ Error loading statistics: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load statistics. Please check your connection.');
      }
    }
  }

  // ✅ Helper method for showing error messages
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFef4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadStatistics,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [navyDark, navyBlue],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? Center(
                        child: CircularProgressIndicator(
                          color: navyButton,
                        ),
                      )
                          : _buildContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ PROFESSIONAL 3-DOT LOADING OVERLAY
          if (_isLoggingOut)
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
                                    color: index == 1
                                        ? navyDark
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Signing out...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessagingPage(
                          schoolId: widget.schoolId,
                          schoolName: _schoolName,
                          userId: widget.userId,
                          adminName: widget.userName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildTracking();
      case 2:
        return _buildUserManagement();
      case 3:
        return _buildPendingApprovals();
      case 4:
        return _buildSettings();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'School Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildScrollableStatCards(),
          const SizedBox(height: 24),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Student Management
          _buildActionCard(
            'Student Management',
            'Add, edit, and manage student information',
            Icons.school,
            navyButton,
            false,
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddStudentsPage(
                    schoolId: widget.schoolId,
                    schoolName: _schoolName,
                    adminId: widget.userId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Device Assignment
          _buildActionCard(
            'Device Assignment',
            'Assign tracking devices to students',
            Icons.watch,
            const Color(0xFF06b6d4),
            false,
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignDevicePage(
                    schoolId: widget.schoolId,
                    schoolName: _schoolName,
                    adminId: widget.userId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Approve Accounts
          _buildActionCard(
            'Approve Accounts',
            'Review and approve pending user registrations',
            Icons.how_to_reg,
            const Color(0xFF10b981),
            _pendingApprovals > 0,
                () {
              setState(() => _selectedIndex = 3);
            },
          ),
          const SizedBox(height: 12),

          // ✅ NEW: Verify Student Assignments
          _buildActionCard(
            'Verify Assignments',
            'Review and approve parent-child tracking assignments',
            Icons.verified_user,
            const Color(0xFF8b5cf6), // Purple color for verification
            false, // TODO: Add badge count for pending verifications
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerifyStudentAssignmentPage(
                    schoolId: widget.schoolId,
                    schoolName: _schoolName,
                    adminId: widget.userId,
                    adminName: widget.userName,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Manage Users
          _buildActionCard(
            'Manage Users',
            'View, edit, and manage all school users',
            Icons.people_outline,
            navyButton,
            false,
                () {
              setState(() => _selectedIndex = 2);
            },
          ),
          const SizedBox(height: 12),

          // School Settings
          _buildActionCard(
            'School Settings',
            'Update school information and GPS location',
            Icons.settings_outlined,
            navyDark,
            false,
                () {
              setState(() => _selectedIndex = 4);
            },
          ),
          const SizedBox(height: 24),
          _buildStaffOverview(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTracking() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search student by name or ID...',
                        prefixIcon: Icon(Icons.search, color: navyButton),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: navyButton),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: navyButton, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'View all students on map',
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [navyDark, navyBlue],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.map, color: Colors.white),
                        onPressed: _viewAllStudentsOnMap,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: Colors.white, // ✅ White background
                  child: TabBar(
                    labelColor: navyDark, // ✅ Navy blue when selected
                    unselectedLabelColor: Colors.grey, // ✅ Gray when unselected
                    indicatorColor: navyDark, // ✅ Navy blue indicator
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.people, size: 20),
                        text: 'All Students',
                      ),
                      Tab(
                        icon: Icon(Icons.location_on, size: 20),
                        text: 'On Campus',
                      ),
                      Tab(
                        icon: Icon(Icons.location_off, size: 20),
                        text: 'Off Campus',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildStudentTrackingList(null),
                      _buildStudentTrackingList(true),
                      _buildStudentTrackingList(false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _viewAllStudentsOnMap() async {
    try {
      final trackingSnapshot = await FirebaseFirestore.instance
          .collection('studentTracking')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      if (trackingSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('No students with tracking data found'),
                ],
              ),
              backgroundColor: const Color(0xFFf59e0b),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      final schoolLat = _schoolProfile['latitude'] as double? ?? 5.6037;
      final schoolLng = _schoolProfile['longitude'] as double? ?? -0.1870;
      final safeZoneRadius = _schoolProfile['safeZoneRadius'] as double? ?? 500.0;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllStudentsMapView(
              students: trackingSnapshot.docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList(),
              schoolLatitude: schoolLat,
              schoolLongitude: schoolLng,
              safeZoneRadius: safeZoneRadius,
              schoolName: _schoolName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error loading student locations: ${e.toString()}');
      }
    }
  }

  Widget _buildStudentTrackingList(bool? isOnCompound) {
    Query query = FirebaseFirestore.instance
        .collection('studentTracking')
        .where('schoolId', isEqualTo: widget.schoolId);

    if (isOnCompound != null) {
      query = query.where('isOnCompound', isEqualTo: isOnCompound);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: navyButton,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading students...',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: navyDark.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_search,
                    size: 64,
                    color: navyDark.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No students found',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No tracking data available',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // ✅ FIX: Remove duplicates by using a Map with studentId as key
        Map<String, DocumentSnapshot> uniqueStudents = {};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final studentId = data['studentId'] as String?;

          if (studentId != null) {
            // Keep only the latest entry for each student
            if (!uniqueStudents.containsKey(studentId)) {
              // First occurrence of this student
              uniqueStudents[studentId] = doc;
            } else {
              // Compare timestamps to keep the latest one
              final currentTimestamp = data['lastUpdate'] as Timestamp?;
              final existingData = uniqueStudents[studentId]!.data() as Map<String, dynamic>;
              final existingTimestamp = existingData['lastUpdate'] as Timestamp?;

              // Only update if both timestamps exist and current is newer
              if (currentTimestamp != null && existingTimestamp != null) {
                if (currentTimestamp.compareTo(existingTimestamp) > 0) {
                  uniqueStudents[studentId] = doc;
                }
              } else if (currentTimestamp != null && existingTimestamp == null) {
                // Current has timestamp, existing doesn't - prefer current
                uniqueStudents[studentId] = doc;
              }
              // If current has no timestamp, keep existing
            }
          }
        }

        // Convert back to list
        List<DocumentSnapshot> filteredDocs = uniqueStudents.values.where((doc) {
          if (_searchQuery.isEmpty) return true;

          final data = doc.data() as Map<String, dynamic>;
          final studentName = (data['studentName'] ?? '').toString().toLowerCase();
          final studentId = (data['studentId'] ?? '').toString().toLowerCase();

          return studentName.contains(_searchQuery) || studentId.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: navyDark.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off,
                    size: 64,
                    color: navyDark.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No students match "$_searchQuery"',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final trackingDoc = filteredDocs[index];
            final trackingData = trackingDoc.data() as Map<String, dynamic>;

            return _buildTrackingCard(trackingData);
          },
        );
      },
    );
  }

  Widget _buildTrackingCard(Map<String, dynamic> trackingData) {
    final isOnCompound = trackingData['isOnCompound'] ?? false;
    final accuracy = trackingData['accuracy'] ?? 0.0;
    final timestamp = trackingData['lastUpdate'] as Timestamp?;
    final timeAgo = timestamp != null
        ? _getTimeAgo(timestamp.toDate())
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            navyDark.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnCompound
              ? const Color(0xFF10b981).withOpacity(0.3)
              : const Color(0xFFf59e0b).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: navyDark.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isOnCompound
                          ? [
                        const Color(0xFF10b981),
                        const Color(0xFF10b981).withOpacity(0.8),
                      ]
                          : [
                        const Color(0xFFf59e0b),
                        const Color(0xFFf59e0b).withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isOnCompound
                            ? const Color(0xFF10b981)
                            : const Color(0xFFf59e0b))
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isOnCompound ? Icons.location_on : Icons.location_off,
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
                        trackingData['studentName'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: navyDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${trackingData['studentId'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: navyDark.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOnCompound
                        ? const Color(0xFF10b981).withOpacity(0.1)
                        : const Color(0xFFf59e0b).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOnCompound
                          ? const Color(0xFF10b981).withOpacity(0.3)
                          : const Color(0xFFf59e0b).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    isOnCompound ? 'On Campus' : 'Off Campus',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOnCompound
                          ? const Color(0xFF10b981)
                          : const Color(0xFFf59e0b),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: navyDark.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: navyDark.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTrackingInfo(
                      Icons.schedule,
                      'Last Update',
                      timeAgo,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: navyDark.withOpacity(0.1),
                  ),
                  Expanded(
                    child: _buildTrackingInfo(
                      Icons.gps_fixed,
                      'Accuracy',
                      '${accuracy.toStringAsFixed(1)}m',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: navyDark.withOpacity(0.1),
                  ),
                  Expanded(
                    child: _buildTrackingInfo(
                      Icons.speed,
                      'Speed',
                      '${trackingData['speed'] ?? 0}km/h',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [navyDark, navyBlue],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: navyDark.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _showStudentLocation(trackingData),
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('View Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _contactGuardian(trackingData),
                    icon: Icon(Icons.phone, size: 16, color: navyDark),
                    label: Text('Contact', style: TextStyle(color: navyDark)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navyDark,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: navyDark, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildTrackingInfo(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: navyDark.withOpacity(0.6)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: navyDark.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: navyDark,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showStudentLocation(Map<String, dynamic> trackingData) {
    final lat = trackingData['latitude'] as double?;
    final lng = trackingData['longitude'] as double?;
    final studentName = trackingData['studentName'] ?? 'Unknown';
    final studentId = trackingData['studentId'] ?? '';

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 12),
              Text('Location not available for $studentName'),
            ],
          ),
          backgroundColor: const Color(0xFFf59e0b),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final schoolLat = _schoolProfile['latitude'] as double? ?? 5.6037;
    final schoolLng = _schoolProfile['longitude'] as double? ?? -0.1870;
    final safeZoneRadius = _schoolProfile['safeZoneRadius'] as double? ?? 500.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStudentMapView(
          studentName: studentName,
          studentId: studentId,
          latitude: lat,
          longitude: lng,
          schoolLatitude: schoolLat,
          schoolLongitude: schoolLng,
          safeZoneRadius: safeZoneRadius,
        ),
      ),
    );
  }

  void _contactGuardian(Map<String, dynamic> trackingData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                    child: const Icon(Icons.phone, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Contact Guardian',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: navyDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Student: ${trackingData['studentName']}',
                style: TextStyle(
                  fontSize: 14,
                  color: navyDark.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select action:',
                style: TextStyle(
                  fontSize: 13,
                  color: navyDark.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [navyDark, navyBlue],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call Guardian'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.sms, color: navyDark),
                  label: Text('Send SMS', style: TextStyle(color: navyDark)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navyDark,
                    side: BorderSide(color: navyDark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserManagement() {
    return DefaultTabController(
      length: 4,
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
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              isScrollable: false,  // ✅ CHANGED: Set to false for justified spacing
              tabs: const [
                Tab(
                  icon: Icon(Icons.school, size: 20),
                  text: 'Teachers',
                ),
                Tab(
                  icon: Icon(Icons.family_restroom, size: 20),
                  text: 'Parents',
                ),
                Tab(
                  icon: Icon(Icons.local_shipping, size: 20),
                  text: 'Drivers',
                ),
                Tab(
                  icon: Icon(Icons.security, size: 20),
                  text: 'Security',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUserList('ROL0002'),  // Teachers
                _buildUserList('ROL0003'),  // Parents
                _buildUserList('ROL0005'),  // Drivers
                _buildUserList('ROL0004'),  // Security
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(String roleId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('roleId', isEqualTo: roleId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: navyButton,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading users...',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: navyDark.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 64,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading users',
                  style: TextStyle(
                    color: navyDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your connection',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {}); // Trigger rebuild
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navyButton,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: navyDark.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_off,
                    size: 64,
                    color: navyDark.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No active users in this category',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final userDoc = snapshot.data!.docs[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            return _buildUserCard(userDoc.id, userData);
          },
        );
      },
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> userData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            navyDark.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: navyDark.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: navyDark.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navyDark, navyBlue],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: navyDark.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              (userData['fullName'] ?? 'U')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
        title: Text(
          userData['fullName'] ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: navyDark,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, size: 14, color: navyDark.withOpacity(0.6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    userData['email'] ?? 'No email',
                    style: TextStyle(
                      fontSize: 13,
                      color: navyDark.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: navyDark.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  userData['phone'] ?? 'No phone',
                  style: TextStyle(
                    fontSize: 13,
                    color: navyDark.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: navyDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.more_vert, color: navyDark, size: 20),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: navyDark.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          elevation: 8,
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'view',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: navyButton.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.visibility,
                      size: 18,
                      color: navyButton,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: navyDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: navyDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 18,
                      color: navyDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit User',
                    style: TextStyle(
                      color: navyDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: navyDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.delete_forever,
                      size: 18,
                      color: navyDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete User',
                    style: TextStyle(
                      color: navyDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'view':
                _showUserDetailsDialog(userData);
                break;
              case 'edit':
                _showEditUserDialog(userId, userData);
                break;
              case 'delete':
                _deleteUserPermanently(userId, userData);
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildPendingApprovals() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pendingAccounts')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: navyButton),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No pending approvals',
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
            final pendingDoc = snapshot.data!.docs[index];
            final pendingData = pendingDoc.data() as Map<String, dynamic>;
            return _buildPendingCard(pendingDoc.id, pendingData);
          },
        );
      },
    );
  }

  Widget _buildPendingCard(String pendingId, Map<String, dynamic> pendingData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFf59e0b).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFf59e0b).withOpacity(0.1),
                  child: Text(
                    (pendingData['fullName'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFf59e0b),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pendingData['fullName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _getRoleName(pendingData['roleId']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf59e0b).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFf59e0b),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Email: ${pendingData['email'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Phone: ${pendingData['phone'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveUser(pendingId, pendingData),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10b981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectUser(pendingId, pendingData),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFef4444),
                      side: const BorderSide(color: Color(0xFFef4444)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  String _getRoleName(String? roleId) {
    switch (roleId) {
      case 'ROL0002':
        return 'Teacher';
      case 'ROL0003':
        return 'Parent';
      case 'ROL0004':
        return 'Security';
      case 'ROL0005':
        return 'Driver';
      default:
        return 'Unknown Role';
    }
  }

  Future<void> _deactivateUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFef4444).withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Color(0xFFef4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Deactivate User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to deactivate this user? They will no longer be able to access the system.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFef4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Deactivate'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isActive': false});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('User deactivated successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        _loadStatistics();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to deactivate user: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteUserPermanently(String userId, Map<String, dynamic> userData) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                navyDark.withOpacity(0.03),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated warning icon
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [navyDark, navyBlue],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: navyDark.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Delete User Permanently?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: navyDark.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: navyDark.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: navyDark.withOpacity(0.1),
                          child: Text(
                            (userData['fullName'] ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              color: navyDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData['fullName'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: navyDark,
                                ),
                              ),
                              Text(
                                userData['email'] ?? 'No email',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: navyDark.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: navyDark.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: navyDark,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All user data will be permanently removed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: navyDark.withOpacity(0.8),
                          height: 1.4,
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
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: navyDark.withOpacity(0.3),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: navyDark.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [navyDark, navyBlue],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: navyDark.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
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

    if (confirm != true) return;

    try {
      // Delete user from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .delete();

      // Delete from Firebase Auth if firebaseUid exists
      if (userData['firebaseUid'] != null) {
        try {
          // Note: Deleting from Firebase Auth requires admin SDK
          // This will only work if you have Cloud Functions set up
          debugPrint('⚠️ Firebase Auth deletion requires admin privileges');
        } catch (e) {
          debugPrint('⚠️ Could not delete from Firebase Auth: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'User deleted permanently',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: navyDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        _loadStatistics();
      }
    } catch (e) {
      debugPrint('❌ Error deleting user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to delete user: ${e.toString()}')),
              ],
            ),
            backgroundColor: navyDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _approveUser(
      String pendingId, Map<String, dynamic> pendingData) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(pendingData['userId'])
          .update({
        'isActive': true,
        'status': 'approved',
      });

      await FirebaseFirestore.instance
          .collection('pendingAccounts')
          .doc(pendingId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': widget.userId,
      });

      await FirebaseFirestore.instance.collection('mail').add({
        'to': [pendingData['email']],
        'message': {
          'subject': 'Account Approved - Welcome!',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #10b981;">Account Approved!</h2>
              <p>Hello ${pendingData['fullName']},</p>
              <p>Great news! Your account has been approved by the school administrator.</p>
              <p>You can now login and access all features of the FindMe system.</p>
              <br>
              <p>Best regards,<br>$_schoolName</p>
            </div>
          ''',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('User approved successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        _loadStatistics();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to approve user: ${e.toString()}');
      }
    }
  }

  Future<void> _rejectUser(
      String pendingId, Map<String, dynamic> pendingData) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFef4444).withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFef4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reject Application',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to reject this user application?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFef4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(pendingData['userId'])
          .update({
        'status': 'rejected',
      });

      await FirebaseFirestore.instance
          .collection('pendingAccounts')
          .doc(pendingId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': widget.userId,
      });

      await FirebaseFirestore.instance.collection('mail').add({
        'to': [pendingData['email']],
        'message': {
          'subject': 'Account Application Update',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #ef4444;">Application Not Approved</h2>
              <p>Hello ${pendingData['fullName']},</p>
              <p>Thank you for your interest in joining our school management system.</p>
              <p>Unfortunately, we are unable to approve your application at this time.</p>
              <p>If you believe this is an error, please contact the school administration.</p>
              <br>
              <p>Best regards,<br>$_schoolName</p>
            </div>
          ''',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: 12),
                Text('User application rejected'),
              ],
            ),
            backgroundColor: const Color(0xFFf59e0b),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        _loadStatistics();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to reject user: ${e.toString()}');
      }
    }
  }

  void _showUserDetailsDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: navyButton.withOpacity(0.1),
                  child: Text(
                    (userData['fullName'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: navyButton,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userData['fullName'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: navyButton.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getRoleName(userData['roleId']),
                    style: TextStyle(
                      color: navyButton,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow(Icons.email, 'Email', userData['email'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.phone, 'Phone', userData['phone'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.verified_user,
                  'Status',
                  userData['isActive'] == true ? 'Active' : 'Inactive',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navyButton,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditUserDialog(String userId, Map<String, dynamic> userData) {
    final nameController = TextEditingController(text: userData['fullName']);
    final emailController = TextEditingController(text: userData['email']);
    final phoneController = TextEditingController(text: userData['phone']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: navyButton, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: navyButton, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: navyButton, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: navyButton),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .update({
                              'fullName': nameController.text.trim(),
                              'email': emailController.text.trim(),
                              'phone': phoneController.text.trim(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text('User updated successfully'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF10b981),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showErrorSnackBar('Failed to update user: ${e.toString()}');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyButton,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ PROFESSIONAL SETTINGS PAGE
  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingsCard(
            'School & Admin Profile',
            'View and manage school and administrator profiles with photos',
            Icons.account_circle,
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SchoolProfilePage(
                    userId: widget.userId,
                    schoolId: widget.schoolId,
                    userName: widget.userName,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            'Safe Zone Configuration',
            'Set the school safe zone radius and location',
            Icons.location_on,
                () {
              _showSafeZoneDialog();
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            'Reports & Analytics',
            'View school performance and activity reports',
            Icons.analytics,
                () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('Reports feature coming soon!'),
                    ],
                  ),
                  backgroundColor: navyDark,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            'Help & Support',
            'Get help or contact support team',
            Icons.help_outline,
                () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.support_agent, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('Support feature coming soon!'),
                    ],
                  ),
                  backgroundColor: navyDark,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSettingsCard(
            'Logout',
            'Sign out of your administrator account',
            Icons.logout_rounded,
                () {
              _showLogoutDialog();
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback onTap, {
        bool isDestructive = false,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? const Color(0xFFef4444).withOpacity(0.1)
                    : navyButton.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDestructive ? const Color(0xFFef4444) : navyButton,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDestructive ? const Color(0xFFef4444) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDestructive ? const Color(0xFFef4444) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ PROFESSIONAL NAVY BLUE LOGOUT DIALOG WITH 3-DOT LOADING
  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon container
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [navyDark, navyBlue],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: navyDark.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Confirm Logout',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to sign out of your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: navyDark.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: navyDark.withOpacity(0.1),
                      child: Text(
                        widget.userName[0].toUpperCase(),
                        style: const TextStyle(
                          color: navyDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: navyDark,
                          ),
                        ),
                        Text(
                          _schoolName,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [navyDark, navyBlue],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: navyDark.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          // Close the dialog
                          Navigator.pop(dialogContext);

                          // ✅ Show 3-dot loading overlay
                          setState(() {
                            _isLoggingOut = true;
                          });

                          try {
                            // ✅ ACTUALLY SIGN OUT FROM FIREBASE
                            await FirebaseAuth.instance.signOut();

                            debugPrint('✅ User signed out successfully');

                            // Short delay for smooth UX
                            await Future.delayed(const Duration(milliseconds: 800));

                            if (mounted) {
                              // Navigate to login and clear all routes
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                    (route) => false,
                              );
                            }
                          } catch (e) {
                            debugPrint('❌ Logout error: $e');
                            if (mounted) {
                              setState(() {
                                _isLoggingOut = false;
                              });
                              _showErrorSnackBar('Logout failed. Please try again.');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
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

  void _showSafeZoneDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
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
                        color: navyButton.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.location_on, color: navyButton),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Safe Zone Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10b981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10b981).withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Safe Zone Radius: ${_schoolProfile['safeZoneRadius'] ?? 100}m',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF10b981).withOpacity(0.8),
                        ),
                      ),
                      Text(
                        'Location: ${_schoolProfile['latitude'] != null ? '${_schoolProfile['latitude']?.toStringAsFixed(4)}, ${_schoolProfile['longitude']?.toStringAsFixed(4)}' : 'Not Set'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF10b981).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'How Safe Zone Works:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint(
                    'Students within the radius are marked as "On Campus"'),
                _buildBulletPoint(
                    'Students outside the radius trigger "Off Campus" alerts'),
                _buildBulletPoint(
                    'Real-time tracking updates every 10 seconds'),
                _buildBulletPoint(
                    'Alerts sent to guardians when status changes'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navyButton,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableStatCards() {
    final PageController pageController = PageController(viewportFraction: 0.92);
    int currentPage = 0;

    return StatefulBuilder(
      builder: (context, setState) {
        // ✅ GET SCREEN SIZE
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        // ✅ CALCULATE DYNAMIC HEIGHT (responsive to screen size)
        final cardHeight = screenHeight * 0.12; // 12% of screen height for each card
        final totalHeight = (cardHeight * 2) + 60; // 2 rows + spacing + indicators

        // ✅ CALCULATE DYNAMIC CARD ASPECT RATIO
        final cardWidth = (screenWidth * 0.92 - 12) / 2; // Account for padding
        final aspectRatio = cardWidth / cardHeight;

        return Column(
          children: [
            // Page indicators (dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentPage == index
                        ? navyButton
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // ✅ DYNAMIC HEIGHT CONTAINER
            SizedBox(
              height: totalHeight,
              child: Stack(
                children: [
                  PageView(
                    controller: pageController,
                    onPageChanged: (index) {
                      setState(() {
                        currentPage = index;
                      });
                    },
                    children: [
                      // PAGE 1: Student Stats
                      _buildStatsPage(
                        [
                          _buildCompactStatCard(
                            'Total Students',
                            _totalStudents.toString(),
                            Icons.people,
                            navyButton,
                          ),
                          _buildCompactStatCard(
                            'On Campus',
                            _studentsOnCompound.toString(),
                            Icons.location_on,
                            const Color(0xFF10b981),
                          ),
                          _buildCompactStatCard(
                            'Off Campus',
                            _studentsOffCompound.toString(),
                            Icons.location_off,
                            const Color(0xFFf59e0b),
                          ),
                          _buildCompactStatCard(
                            'Total Staff',
                            (_totalTeachers + _totalDrivers + _totalSecurity).toString(),
                            Icons.badge,
                            const Color(0xFF8b5cf6),
                          ),
                        ],
                        aspectRatio,
                      ),

                      // PAGE 2: Staff Stats
                      _buildStatsPage(
                        [
                          _buildCompactStatCard(
                            'Teachers',
                            _totalTeachers.toString(),
                            Icons.school,
                            navyButton,
                          ),
                          _buildCompactStatCard(
                            'Parents',
                            _totalParents.toString(),
                            Icons.family_restroom,
                            const Color(0xFF2563EB),
                          ),
                          _buildCompactStatCard(
                            'Drivers',
                            _totalDrivers.toString(),
                            Icons.local_shipping,
                            const Color(0xFF06b6d4),
                          ),
                          _buildCompactStatCard(
                            'Security',
                            _totalSecurity.toString(),
                            Icons.security,
                            const Color(0xFF10b981),
                          ),
                        ],
                        aspectRatio,
                      ),
                    ],
                  ),

                  // Left arrow (only show on page 2)
                  if (currentPage > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                            color: navyButton,
                            padding: const EdgeInsets.all(8),
                            onPressed: () {
                              pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  // Right arrow (only show on page 1)
                  if (currentPage < 1)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 18),
                            color: navyButton,
                            padding: const EdgeInsets.all(8),
                            onPressed: () {
                              pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

// ✅ UPDATED: Added aspectRatio parameter
  Widget _buildStatsPage(List<Widget> cards, double aspectRatio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio, // ✅ DYNAMIC ASPECT RATIO
        children: cards,
      ),
    );
  }

// ✅ FULLY RESPONSIVE STAT CARD
  Widget _buildCompactStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ CALCULATE SIZES BASED ON AVAILABLE SPACE
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;

        // ✅ RESPONSIVE FONT SIZES
        final valueFontSize = (cardHeight * 0.25).clamp(18.0, 28.0);
        final titleFontSize = (cardHeight * 0.12).clamp(9.0, 11.0);
        final iconSize = (cardHeight * 0.22).clamp(18.0, 24.0);
        final iconPadding = (cardHeight * 0.08).clamp(5.0, 8.0);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: cardWidth * 0.08,
            vertical: cardHeight * 0.08,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon container
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: iconSize,
                ),
              ),
              SizedBox(height: cardHeight * 0.06),

              // Value
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: cardHeight * 0.03),

              // Title
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      bool hasNotification,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (hasNotification) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFef4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _pendingApprovals.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Staff Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildStaffItem('Teachers', _totalTeachers, navyButton),
          const SizedBox(height: 12),
          _buildStaffItem('Drivers', _totalDrivers, const Color(0xFF06b6d4)),
          const SizedBox(height: 12),
          _buildStaffItem('Security', _totalSecurity, const Color(0xFF10b981)),
        ],
      ),
    );
  }

  Widget _buildStaffItem(String role, int count, Color color) {
    final total = _totalTeachers + _totalDrivers + _totalSecurity;
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              role,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [navyDark, navyBlue],
        ),
        boxShadow: [
          BoxShadow(
            color: navyDark.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.location_on,
                label: 'Tracking',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.people,
                label: 'Users',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.approval,
                label: 'Approvals',
                index: 3,
                badge: _pendingApprovals,
              ),
              _buildNavItem(
                icon: Icons.settings,
                label: 'Settings',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    int badge = 0,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white60,
                  size: 24,
                ),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFef4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SINGLE STUDENT MAP VIEW
// ============================================
class LiveStudentMapView extends StatefulWidget {
  final String studentName;
  final String studentId;
  final double latitude;
  final double longitude;
  final double schoolLatitude;
  final double schoolLongitude;
  final double safeZoneRadius;

  const LiveStudentMapView({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.latitude,
    required this.longitude,
    required this.schoolLatitude,
    required this.schoolLongitude,
    required this.safeZoneRadius,
  });

  @override
  State<LiveStudentMapView> createState() => _LiveStudentMapViewState();
}

class _LiveStudentMapViewState extends State<LiveStudentMapView> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _setupMapElements();
  }

  void _setupMapElements() {
    final schoolMarker = Marker(
      markerId: const MarkerId('school'),
      position: LatLng(widget.schoolLatitude, widget.schoolLongitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'School'),
    );

    final safeCircle = Circle(
      circleId: const CircleId('safeZone'),
      center: LatLng(widget.schoolLatitude, widget.schoolLongitude),
      radius: widget.safeZoneRadius,
      strokeColor: const Color(0xFF10b981).withOpacity(0.6),
      fillColor: const Color(0xFF10b981).withOpacity(0.15),
      strokeWidth: 3,
    );

    setState(() {
      _markers = {schoolMarker};
      _circles = {safeCircle};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} - Live Location'),
        backgroundColor: const Color(0xFF667eea),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in Google Maps',
            onPressed: () {
              _launchGoogleMaps(widget.latitude, widget.longitude);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('studentTracking')
            .where('studentId', isEqualTo: widget.studentId)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF667eea),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No location data available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Student: ${widget.studentName}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final double? lat = data['latitude']?.toDouble();
          final double? lng = data['longitude']?.toDouble();

          if (lat == null || lng == null) {
            return const Center(
              child: Text('Invalid location coordinates'),
            );
          }

          final position = LatLng(lat, lng);

          final studentMarker = Marker(
            markerId: const MarkerId('student'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: widget.studentName),
          );

          _markers = {
            _markers.firstWhere(
                  (m) => m.markerId.value == 'school',
              orElse: () => _markers.first,
            ),
            studentMarker,
          };

          _controller?.animateCamera(
            CameraUpdate.newLatLng(position),
          );

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: position,
                  zoom: 16,
                ),
                markers: _markers,
                circles: _circles,
                onMapCreated: (controller) {
                  _controller = controller;
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF667eea),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.studentName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${widget.studentId}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                Icons.location_on,
                                'Coordinates',
                                '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                Icons.my_location,
                                'Accuracy',
                                '${(data['accuracy'] ?? 0).toStringAsFixed(1)}m',
                              ),
                            ),
                            Expanded(
                              child: _buildInfoItem(
                                Icons.speed,
                                'Speed',
                                '${(data['speed'] ?? 0).toStringAsFixed(1)} km/h',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          Icons.access_time,
                          'Last Updated',
                          _getTimeAgo(data['lastUpdate']),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _controller?.animateCamera(
                                    CameraUpdate.newLatLngZoom(position, 17),
                                  );
                                },
                                icon: const Icon(Icons.my_location, size: 18),
                                label: const Text('Center on Student'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667eea),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _fitBothMarkers(position);
                                },
                                icon: const Icon(Icons.zoom_out_map, size: 18),
                                label: const Text('View All'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF667eea),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: Color(0xFF667eea)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _fitBothMarkers(LatLng studentPos) {
    final schoolPos = LatLng(widget.schoolLatitude, widget.schoolLongitude);

    final bounds = LatLngBounds(
      southwest: LatLng(
        studentPos.latitude < schoolPos.latitude
            ? studentPos.latitude
            : schoolPos.latitude,
        studentPos.longitude < schoolPos.longitude
            ? studentPos.longitude
            : schoolPos.longitude,
      ),
      northeast: LatLng(
        studentPos.latitude > schoolPos.latitude
            ? studentPos.latitude
            : schoolPos.latitude,
        studentPos.longitude > schoolPos.longitude
            ? studentPos.longitude
            : schoolPos.longitude,
      ),
    );

    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final dateTime = (timestamp as Timestamp).toDate();
      final diff = DateTime.now().difference(dateTime);

      if (diff.inSeconds < 10) return 'Just now';
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _launchGoogleMaps(double lat, double lng) async {
    final url = 'https://maps.google.com/?q=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

// ============================================
// ALL STUDENTS MAP VIEW
// ============================================
class AllStudentsMapView extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final double schoolLatitude;
  final double schoolLongitude;
  final double safeZoneRadius;
  final String schoolName;

  const AllStudentsMapView({
    super.key,
    required this.students,
    required this.schoolLatitude,
    required this.schoolLongitude,
    required this.safeZoneRadius,
    required this.schoolName,
  });

  @override
  State<AllStudentsMapView> createState() => _AllStudentsMapViewState();
}

class _AllStudentsMapViewState extends State<AllStudentsMapView> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _setupMapElements();
  }

  void _setupMapElements() {
    final schoolMarker = Marker(
      markerId: const MarkerId('school'),
      position: LatLng(widget.schoolLatitude, widget.schoolLongitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(title: widget.schoolName),
    );

    final safeCircle = Circle(
      circleId: const CircleId('safeZone'),
      center: LatLng(widget.schoolLatitude, widget.schoolLongitude),
      radius: widget.safeZoneRadius,
      strokeColor: const Color(0xFF10b981).withOpacity(0.6),
      fillColor: const Color(0xFF10b981).withOpacity(0.15),
      strokeWidth: 3,
    );

    Set<Marker> studentMarkers = {};
    for (var student in widget.students) {
      final lat = student['latitude'] as double?;
      final lng = student['longitude'] as double?;
      final studentId = student['studentId'] as String?;
      final studentName = student['studentName'] as String?;
      final isOnCompound = student['isOnCompound'] as bool? ?? false;

      if (lat != null && lng != null && studentId != null) {
        studentMarkers.add(
          Marker(
            markerId: MarkerId(studentId),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isOnCompound ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: studentName ?? 'Student',
              snippet: isOnCompound ? 'On Campus' : 'Off Campus',
            ),
            onTap: () {
              setState(() {
                _selectedStudentId = studentId;
              });
            },
          ),
        );
      }
    }

    setState(() {
      _markers = {schoolMarker, ...studentMarkers};
      _circles = {safeCircle};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Students (${widget.students.length})'),
        backgroundColor: const Color(0xFF667eea),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Show all markers',
            onPressed: _fitAllMarkers,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.schoolLatitude, widget.schoolLongitude),
              zoom: 14,
            ),
            markers: _markers,
            circles: _circles,
            onMapCreated: (controller) {
              _controller = controller;
              _fitAllMarkers();
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            onTap: (position) {
              setState(() {
                _selectedStudentId = null;
              });
            },
          ),
          if (_selectedStudentId != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildSelectedStudentCard(),
            ),
          Positioned(
            top: 20,
            right: 20,
            child: _buildLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedStudentCard() {
    final student = widget.students.firstWhere(
          (s) => s['studentId'] == _selectedStudentId,
      orElse: () => {},
    );

    if (student.isEmpty) return const SizedBox.shrink();

    final isOnCompound = student['isOnCompound'] as bool? ?? false;
    final lat = student['latitude'] as double?;
    final lng = student['longitude'] as double?;
    final accuracy = student['accuracy'] as double? ?? 0.0;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isOnCompound
                      ? const Color(0xFF10b981).withOpacity(0.1)
                      : const Color(0xFFf59e0b).withOpacity(0.1),
                  child: Icon(
                    isOnCompound ? Icons.location_on : Icons.location_off,
                    color: isOnCompound
                        ? const Color(0xFF10b981)
                        : const Color(0xFFf59e0b),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['studentName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${student['studentId'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnCompound
                        ? const Color(0xFF10b981).withOpacity(0.1)
                        : const Color(0xFFf59e0b).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOnCompound ? 'On Campus' : 'Off Campus',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOnCompound
                          ? const Color(0xFF10b981)
                          : const Color(0xFFf59e0b),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedStudentId = null;
                    });
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.gps_fixed,
                    'Accuracy',
                    '${accuracy.toStringAsFixed(1)}m',
                  ),
                ),
                Expanded(
                  child: _buildInfoChip(
                    Icons.speed,
                    'Speed',
                    '${student['speed'] ?? 0}km/h',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (lat != null && lng != null) {
                        _controller?.animateCamera(
                          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 17),
                        );
                      }
                    },
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('Center'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (lat != null && lng != null) {
                        _launchGoogleMaps(lat, lng);
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF667eea),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFF667eea)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Legend',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem(Colors.blue, 'School'),
            _buildLegendItem(const Color(0xFF10b981), 'On Campus'),
            _buildLegendItem(const Color(0xFFf59e0b), 'Off Campus'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty || _controller == null) return;

    LatLngBounds bounds;
    final positions = _markers.map((m) => m.position).toList();

    if (positions.length == 1) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 16),
      );
      return;
    }

    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (var pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _launchGoogleMaps(double lat, double lng) async {
    final url = 'https://maps.google.com/?q=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}