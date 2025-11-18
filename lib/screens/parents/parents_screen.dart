import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'parent_profile.dart';
import 'track_child.dart';
import 'search_assign_children.dart';

/// ✅ PROFESSIONAL PARENT DASHBOARD
/// - Navy blue color scheme (#0A1929)
/// - Immediate dashboard access after profile completion
/// - Child search and assignment system
/// - School admin verification workflow
/// - User-friendly interface with professional loading animations

class ParentHomepage extends StatefulWidget {
  final String parentId;
  const ParentHomepage({super.key, required this.parentId});

  @override
  State<ParentHomepage> createState() => _ParentHomepageState();
}

class _ParentHomepageState extends State<ParentHomepage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _dotsController;

  String _selectedChild = '';
  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic>? _parentProfile;
  bool _isLoading = true; // ✅ Show loading screen on page load
  bool _profileCompleted = false;
  String _schoolId = '';

  List<Map<String, dynamic>> _notifications = [];
  int _pendingChildRequests = 0;

  // ✅ Navigation loading state
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _initializeParentData();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  // ============================================================================
  // INITIALIZATION & DATA LOADING
  // ============================================================================

  Future<void> _initializeParentData() async {
    try {
      setState(() => _isLoading = true);

      // Get parent document from users collection
      final userDoc = await _firestore.collection('users').doc(widget.parentId).get();

      if (!userDoc.exists) {
        _showErrorDialog('Error', 'User profile not found.');
        return;
      }

      final userData = userDoc.data()!;
      _schoolId = userData['schoolId'] ?? '';

      // Check if parent profile exists
      final parentDoc = await _firestore.collection('parents').doc(widget.parentId).get();

      if (!parentDoc.exists) {
        // Create minimal parent document
        await _firestore.collection('parents').doc(widget.parentId).set({
          'userId': widget.parentId,
          'firebaseUid': userData['firebaseUid'],
          'fullName': userData['fullName'] ?? '',
          'email': userData['email'] ?? '',
          'phone': userData['phone'] ?? '',
          'schoolId': _schoolId,
          'createdAt': FieldValue.serverTimestamp(),
          'profileCompleted': false,
        });

        // Navigate to profile setup
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ParentProfilePage(parentId: widget.parentId),
            ),
          );
        }
        return;
      }

      final parentData = parentDoc.data()!;
      _parentProfile = {
        ...parentData,
        // Ensure we have fullName for display
        'fullName': parentData['fullName'] ?? parentData['name'] ?? 'Parent',
      };
      _profileCompleted = parentData['profileCompleted'] ?? false;

      if (!_profileCompleted) {
        // Navigate to profile setup
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ParentProfilePage(parentId: widget.parentId),
            ),
          );
        }
        return;
      }

      // ✅ Profile completed - load data
      await _loadChildren();
      _listenToNotifications();
      _listenToPendingRequests();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error initializing parent data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Error', 'Failed to load your profile. Please try again.');
      }
    }
  }

  Future<void> _loadChildren() async {
    try {
      debugPrint('🔍 Loading children for parent: ${widget.parentId}');

      // Load assigned children (approved by school admin)
      final snapshot = await _firestore
          .collection('childAssignments')
          .where('parentId', isEqualTo: widget.parentId)
          .where('status', isEqualTo: 'approved')
          .get();

      debugPrint('📋 Found ${snapshot.docs.length} approved assignments');

      List<Map<String, dynamic>> childrenList = [];

      for (var doc in snapshot.docs) {
        final assignmentData = doc.data();
        final childId = assignmentData['studentId'] as String?;

        if (childId == null || childId.isEmpty) {
          debugPrint('⚠️ Skipping assignment with no studentId');
          continue;
        }

        debugPrint('👶 Processing student: $childId');

        // Get child details from students collection
        final childDoc = await _firestore.collection('students').doc(childId).get();

        if (childDoc.exists) {
          final childData = childDoc.data()!;
          final age = _calculateAge(childData['dateOfBirth']);
          final classInfo = childData['class'] ?? childData['grade'] ?? 'N/A';

          debugPrint('   - Name: ${childData['fullName']}');
          debugPrint('   - Age: $age');
          debugPrint('   - Class: $classInfo');

          childrenList.add({
            'id': childId,
            'assignmentId': doc.id,
            'name': childData['fullName'] ?? assignmentData['childName'] ?? 'Unknown',
            'age': age,
            'grade': childData['grade'] ?? classInfo,
            'class': classInfo,
            'classRoom': childData['classRoom'] ?? 'N/A',
            'school': childData['schoolName'] ?? 'N/A',
            'schoolId': childData['schoolId'] ?? '',
            'studentId': childData['studentId'] ?? '',
            'profileImage': childData['profileImage'] ?? '',
            'relationship': assignmentData['relationship'] ?? 'Parent',
            'emergencyContact': assignmentData['emergencyContact'] ?? false,
            'status': childData['status'] ?? 'Unknown',
          });
        } else {
          // Fallback to assignment data if student doc doesn't exist
          debugPrint('   ⚠️ Student document not found - using assignment data');
          childrenList.add({
            'id': childId,
            'assignmentId': doc.id,
            'name': assignmentData['childName'] ?? 'Unknown',
            'age': 0,
            'grade': assignmentData['childGrade'] ?? 'N/A',
            'class': assignmentData['childGrade'] ?? 'N/A',
            'classRoom': 'N/A',
            'school': 'N/A',
            'schoolId': assignmentData['schoolId'] ?? '',
            'studentId': assignmentData['childStudentId'] ?? childId,
            'profileImage': '',
            'relationship': assignmentData['relationship'] ?? 'Parent',
            'emergencyContact': assignmentData['emergencyContact'] ?? false,
            'status': 'Unknown',
          });
        }
      }

      debugPrint('✅ Loaded ${childrenList.length} children successfully');

      if (mounted) {
        setState(() {
          _children = childrenList;
          if (_children.isNotEmpty) {
            _selectedChild = _children[0]['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading children: $e');
    }
  }

  int _calculateAge(dynamic dateOfBirth) {
    if (dateOfBirth == null) return 0;
    try {
      final dob = (dateOfBirth as Timestamp).toDate();
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      debugPrint('⚠️ Error calculating age: $e');
      return 0;
    }
  }

  void _listenToNotifications() {
    _firestore
        .collection('notifications')
        .where('userId', isEqualTo: widget.parentId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          // Filter by userType in the app instead of the query
          _notifications = snapshot.docs
              .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? 'Notification',
              'message': data['message'] ?? '',
              'time': _formatTimestamp(data['timestamp']),
              'read': data['read'] ?? false,
              'type': data['type'] ?? 'info',
              'icon': _getNotificationIcon(data['type'] ?? 'info'),
              'userType': data['userType'] ?? '',
            };
          })
              .where((notif) =>
          notif['userType'] == 'parent' || notif['userType'] == '')
              .toList();
        });
      }
    });
  }

  void _listenToPendingRequests() {
    _firestore
        .collection('childAssignments')
        .where('parentId', isEqualTo: widget.parentId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingChildRequests = snapshot.docs.length;
        });
      }
    });
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sos':
        return Icons.sos;
      case 'arrival':
        return Icons.check_circle;
      case 'departure':
        return Icons.directions_bus;
      case 'alert':
        return Icons.warning;
      case 'message':
        return Icons.message;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dateTime = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _handleRefresh() async {
    try {
      setState(() => _isLoading = true);

      // Reload all data
      await _loadChildren();

      // Small delay for smooth animation
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error refreshing: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================================
  // NAVIGATION LOADING OVERLAY
  // ============================================================================

  Widget _buildNavigationLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.60), // ✅ Exactly like login page
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
                    final offset = (value < 0.5 ? value * 2 : (1 - value) * 2) * 18;

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
                                ? const Color(0xFF0A1929) // Middle dot: Navy blue
                                : Colors.white, // Outer dots: White
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
              'Loading...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UI BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: _buildAppBar(isDark),
      drawer: _buildDrawer(isDark),
      body: Stack(
        children: [
          // Main body content
          _children.isEmpty
              ? RefreshIndicator(
            onRefresh: _handleRefresh,
            color: const Color(0xFF0A1929),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 100,
                child: _buildEmptyState(isDark),
              ),
            ),
          )
              : RefreshIndicator(
            onRefresh: _handleRefresh,
            color: const Color(0xFF0A1929),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildWelcomeCard(isDark),
                  const SizedBox(height: 16),
                  if (_pendingChildRequests > 0) _buildPendingRequestsBanner(isDark),
                  if (_pendingChildRequests > 0) const SizedBox(height: 16),
                  _buildChildSelector(isDark),
                  const SizedBox(height: 16),
                  _buildLiveStatusCard(isDark),
                  const SizedBox(height: 16),
                  _buildQuickActions(isDark),
                  const SizedBox(height: 16),
                  _buildNotificationsSection(isDark),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ✅ Initial page loading overlay - exactly like login page
          if (_isLoading)
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
                                        ? const Color(0xFF0A1929) // Middle dot: Navy blue
                                        : Colors.white, // Outer dots: White
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
                      'Loading your dashboard...',
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

          // Loading overlay for navigation
          if (_isNavigating) _buildNavigationLoadingOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showChildSearchOptions,
        backgroundColor: const Color(0xFF0A1929),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Child', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: const Text(
        'Parent Dashboard',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      backgroundColor: const Color(0xFF0A1929),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      actions: [
        // Pending requests badge
        if (_pendingChildRequests > 0)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.pending_actions, color: Colors.white),
                onPressed: _showPendingRequests,
                tooltip: 'Pending Requests',
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    _pendingChildRequests.toString(),
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

        // Notifications
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: _showNotificationsPanel,
              tooltip: 'Notifications',
            ),
            if (_notifications.where((n) => !n['read']).isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    _notifications.where((n) => !n['read']).length.toString(),
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
      ],
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          // Drawer header with navy blue gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A1929), Color(0xFF1A2F3F)],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile picture with fallback to initials
                  _parentProfile?['profileImage'] != null &&
                      (_parentProfile!['profileImage'] as String).isNotEmpty
                      ? Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      image: DecorationImage(
                        image: NetworkImage(_parentProfile!['profileImage']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                      : CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Text(
                      (_parentProfile?['fullName'] ?? 'P')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A1929),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _parentProfile?['fullName'] ?? 'Parent',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _parentProfile?['email'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _parentProfile?['phone'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.child_care, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '${_children.length} ${_children.length == 1 ? 'Child' : 'Children'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.home,
                  title: 'Dashboard',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'My Profile',
                  onTap: () async {
                    Navigator.pop(context);
                    setState(() => _isNavigating = true);
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (!mounted) return; // ✅ Check if mounted
                    setState(() => _isNavigating = false);
                    if (!mounted) return; // ✅ Double check
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParentProfilePage(parentId: widget.parentId),
                      ),
                    ).then((_) {
                      if (mounted) _initializeParentData();
                    });
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.child_care,
                  title: 'Manage Children',
                  onTap: () {
                    Navigator.pop(context);
                    _showChildSearchOptions();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.pending_actions,
                  title: 'Pending Requests',
                  trailing: _pendingChildRequests > 0
                      ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _pendingChildRequests.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    setState(() => _isNavigating = true);
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (!mounted) return; // ✅ Check if mounted
                    setState(() => _isNavigating = false);
                    if (mounted) _showPendingRequests();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.message,
                  title: 'Messages',
                  onTap: () {
                    Navigator.pop(context);
                    _showMessagesPage();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.history,
                  title: 'Tracking History',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tracking history feature coming soon')),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings page coming soon')),
                    );
                  },
                ),
                const Divider(),
                _buildDrawerItem(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help & support coming soon')),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  textColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildPendingRequestsBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _showPendingRequests,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFA726), Color(0xFFFF9800)],
            ),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.pending_actions, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Child Requests',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_pendingChildRequests request${_pendingChildRequests > 1 ? 's' : ''} waiting for admin approval',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1929), Color(0xFF1A2F3F)],
                ),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(Icons.child_care, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Children Assigned',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Search and assign your children to start tracking their location and safety',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showChildSearchOptions,
              icon: const Icon(Icons.search),
              label: const Text('Search for My Child'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A1929),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showAddNewChildInfo,
              icon: const Icon(Icons.add),
              label: const Text('Register New Child'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A1929),
                side: const BorderSide(color: Color(0xFF0A1929), width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A1929), Color(0xFF1A2F3F)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1929).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${_parentProfile?['fullName']?.split(' ')[0] ?? 'Parent'} 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Real-time tracking active',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.verified_user, color: Colors.white, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                        const SizedBox(width: 6),
                        Text(
                          '${_children.length} Active',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _parentProfile?['schoolName'] ?? 'School',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
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

  Widget _buildChildSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Children',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: _showChildSearchOptions,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0A1929),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _children.length,
              itemBuilder: (context, index) {
                final child = _children[index];
                final isSelected = child['id'] == _selectedChild;
                final age = child['age'] ?? 0;
                final ageDisplay = age > 0 ? '$age yrs' : 'Age N/A';
                final classInfo = child['class'] ?? child['grade'] ?? 'N/A';

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedChild = child['id']),
                    child: Container(
                      width: 150,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                          colors: [Color(0xFF0A1929), Color(0xFF1A2F3F)],
                        )
                            : null,
                        color: isSelected ? null : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0A1929) : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF0A1929).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [Colors.white, Colors.white70]
                                      : [const Color(0xFF0A1929), const Color(0xFF1A2F3F)],
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                Icons.child_care,
                                color: isSelected ? const Color(0xFF0A1929) : Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              child['name'].split(' ')[0],
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$ageDisplay • $classInfo',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard(bool isDark) {
    final child = _children.firstWhere(
          (c) => c['id'] == _selectedChild,
      orElse: () => _children.isNotEmpty ? _children[0] : {},
    );

    if (child.isEmpty) return const SizedBox.shrink();

    final status = child['status'] ?? 'Unknown';
    final classInfo = child['class'] ?? child['grade'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(status),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(status).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child['name'],
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _getStatusEmoji(status),
                    style: const TextStyle(fontSize: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStatusRow('School', child['school']),
                    const SizedBox(height: 10),
                    _buildStatusRow('Class', classInfo),
                    const SizedBox(height: 10),
                    _buildStatusRow('Classroom', child['classRoom']),
                    const SizedBox(height: 10),
                    _buildStatusRow('Relationship', child['relationship']),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _isNavigating = true);
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (!mounted) return; // ✅ Check if mounted
                    setState(() => _isNavigating = false);
                    if (!mounted) return; // ✅ Double check
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackChildPage(
                          childId: child['id'],
                          childName: child['name'],
                          parentId: widget.parentId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on, size: 20),
                  label: const Text('Track Live Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A1929),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.sos,
                  label: 'SOS Alert',
                  onTap: _showSosAlert,
                  isDark: isDark,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.message,
                  label: 'Message',
                  onTap: _showMessagesPage,
                  isDark: isDark,
                  color: const Color(0xFF0A1929),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.history,
                  label: 'History',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Showing tracking history')),
                  ),
                  isDark: isDark,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: _showNotificationsPanel,
                child: const Text('View All', style: TextStyle(color: Color(0xFF0A1929))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_notifications.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No notifications yet', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ..._notifications.take(3).map((notif) => _buildNotificationItem(notif, isDark)),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif, bool isDark) {
    final isUnread = !notif['read'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? Colors.green // ✅ Thick green border for unread
              : Colors.transparent,
          width: isUnread ? 3 : 1.5, // ✅ Thicker border for unread
        ),
        boxShadow: [
          BoxShadow(
            color: isUnread
                ? Colors.green.withOpacity(0.2) // ✅ Green glow for unread
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1929).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(notif['icon'], color: const Color(0xFF0A1929), size: 20),
              ),
              // ✅ Green dot for unread
              if (isUnread)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif['title'],
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notif['message'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  notif['time'],
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ✅ Actions menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Colors.grey[600],
              size: 20,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'read') {
                _markNotificationAsRead(notif['id'], true);
              } else if (value == 'unread') {
                _markNotificationAsRead(notif['id'], false);
              } else if (value == 'delete') {
                _showDeleteNotificationDialog(notif['id']);
              }
            },
            itemBuilder: (context) => [
              if (isUnread)
                PopupMenuItem(
                  value: 'read',
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_read, size: 18, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      const Text('Mark as Read', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              if (!isUnread)
                PopupMenuItem(
                  value: 'unread',
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_unread, size: 18, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      const Text('Mark as Unread', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // NOTIFICATION ACTIONS
  // ============================================================================

  Future<void> _markNotificationAsRead(String notificationId, bool isRead) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': isRead,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isRead ? 'Marked as read' : 'Marked as unread'),
            backgroundColor: const Color(0xFF0A1929),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Color(0xFF0A1929),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete notification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteNotificationDialog(String notificationId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Notification?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone. The notification will be permanently deleted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0A1929)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF0A1929),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteNotification(notificationId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

  // ============================================================================
  // DIALOGS & MODALS
  // ============================================================================

  void _showChildSearchOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Child',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to add your child',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildSearchOption(
                icon: Icons.search,
                title: 'Search for My Child',
                subtitle: 'Find your child in the school database',
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _isNavigating = true);
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (!mounted) return; // ✅ Check if widget is still mounted
                  setState(() => _isNavigating = false);
                  if (!mounted) return; // ✅ Double check before navigation
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchAssignChildrenPage(
                        parentId: widget.parentId,
                        schoolId: _schoolId,
                      ),
                    ),
                  ).then((_) {
                    if (mounted) _loadChildren();
                  });
                },
                color: const Color(0xFF0A1929),
              ),
              const SizedBox(height: 14),
              _buildSearchOption(
                icon: Icons.add_circle_outline,
                title: 'Register New Child',
                subtitle: 'Add a child not yet in the system (requires admin approval)',
                onTap: () {
                  Navigator.pop(context);
                  _showAddNewChildInfo();
                },
                color: const Color(0xFF1A2F3F),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showAddNewChildInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF0A1929)),
            SizedBox(width: 12),
            Text('Register New Child'),
          ],
        ),
        content: const Text(
          'To register a new child:\n\n'
              '1. Contact your school admin to add the child to the system\n'
              '2. Once added, you can search and assign the child to your account\n'
              '3. The school admin will verify the relationship\n\n'
              'This process ensures child safety and proper verification.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please contact your school administrator to register a new child'),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A1929),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPendingRequests() async {
    setState(() => _isNavigating = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return; // ✅ Check if mounted
    setState(() => _isNavigating = false);
    if (!mounted) return; // ✅ Double check
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PendingRequestsPage(parentId: widget.parentId),
      ),
    ).then((_) {
      if (mounted) _loadChildren();
    });
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        if (_notifications.where((n) => !n['read']).isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _notifications.where((n) => !n['read']).length.toString(),
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
                    TextButton(
                      onPressed: () async {
                        for (var notif in _notifications.where((n) => !n['read'])) {
                          await _firestore.collection('notifications').doc(notif['id']).update({'read': true});
                        }
                      },
                      child: const Text('Mark all read', style: TextStyle(color: Color(0xFF0A1929))),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) => _buildNotificationItem(_notifications[index], isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessagesPage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Messages feature coming soon')),
    );
  }

  void _showSosAlert() {
    if (_children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a child first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sos, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('SOS Alert'),
          ],
        ),
        content: const Text('Send an emergency SOS alert for your child?\n\nThis will notify school administration, security, and emergency contacts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _firestore.collection('notifications').add({
                  'userId': widget.parentId,
                  'userType': 'parent',
                  'childId': _selectedChild,
                  'type': 'sos',
                  'title': 'SOS Alert Sent',
                  'message': 'Emergency alert sent to school authorities and emergency contacts',
                  'timestamp': FieldValue.serverTimestamp(),
                  'read': false,
                  'priority': 'urgent',
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🚨 SOS Alert Sent!'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending SOS: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A1929),
                Color(0xFF1A2F3F),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logout icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              const Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 28),

              // Action buttons
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Logout button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _auth.signOut();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error logging out: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFF0A1929),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A1929)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in transit':
      case 'on bus':
        return Colors.blue;
      case 'at school':
      case 'in class':
        return Colors.green;
      case 'at home':
        return Colors.orange;
      case 'absent':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusEmoji(String status) {
    switch (status.toLowerCase()) {
      case 'in transit':
      case 'on bus':
        return '🚐';
      case 'at school':
      case 'in class':
        return '📚';
      case 'at home':
        return '🏠';
      case 'absent':
        return '❌';
      default:
        return '📍';
    }
  }
}

// ============================================================================
// PENDING REQUESTS PAGE
// ============================================================================

class PendingRequestsPage extends StatelessWidget {
  final String parentId;

  const PendingRequestsPage({super.key, required this.parentId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Pending Requests'),
        backgroundColor: const Color(0xFF0A1929),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('childAssignments')
            .where('parentId', isEqualTo: parentId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pending_actions, size: 80, color: Colors.grey),
                    const SizedBox(height: 24),
                    const Text(
                      'No Pending Requests',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All your child assignment requests have been processed',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
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
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.child_care, color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['childName'] ?? 'Unknown',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Student ID: ${data['studentId'] ?? 'N/A'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Relationship: ${data['relationship'] ?? 'Parent'}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requested: ${_formatTimestamp(data['requestedAt'])}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Waiting for school admin approval...',
                        style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dateTime = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'N/A';
    }
  }
}