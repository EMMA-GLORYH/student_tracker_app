import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'schools_management_screen.dart';

// Main System Owner Dashboard
class SystemOwnerDashboard extends StatefulWidget {
  final String userName;
  final String userId;

  const SystemOwnerDashboard({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<SystemOwnerDashboard> createState() => _SystemOwnerDashboardState();
}

class _SystemOwnerDashboardState extends State<SystemOwnerDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 0;

  // Real-time statistics
  int _totalSchools = 0;
  int _activeSchools = 0;
  int _totalStudents = 0;
  int _totalParents = 0;
  int _totalDrivers = 0;
  int _totalTeachers = 0;
  int _pendingApprovals = 0;
  int _todayAlerts = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadStatistics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      final schoolsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .get();

      final activeSchoolsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .where('isActive', isEqualTo: true)
          .where('verified', isEqualTo: true)
          .get();

      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('isActive', isEqualTo: true)
          .get();

      final parentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: 'ROL0003')
          .where('isActive', isEqualTo: true)
          .get();

      final driversSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: 'ROL0005')
          .where('isActive', isEqualTo: true)
          .get();

      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: 'ROL0002')
          .where('isActive', isEqualTo: true)
          .get();

      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('pendingAccounts')
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _totalSchools = schoolsSnapshot.docs.length;
        _activeSchools = activeSchoolsSnapshot.docs.length;
        _totalStudents = studentsSnapshot.docs.length;
        _totalParents = parentsSnapshot.docs.length;
        _totalDrivers = driversSnapshot.docs.length;
        _totalTeachers = teachersSnapshot.docs.length;
        _pendingApprovals = pendingSnapshot.docs.length;
      });
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  Future<bool> _onWillPop() async {
    return await _showLogoutConfirmation();
  }

  Future<bool> _showLogoutConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirm Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Navigate to login - adjust route name as needed
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
        appBar: _buildAppBar(isDark),
        drawer: _buildDrawer(isDark),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildBody(isDark),
        ),
        bottomNavigationBar: _buildBottomNav(isDark),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showQuickActions(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Quick Add'),
          backgroundColor: const Color(0xFF667eea),
          elevation: 4,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Owner Portal',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Complete System Control & Management',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        if (_pendingApprovals > 0)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {
                  // TODO: Navigate to pending approvals
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$_pendingApprovals pending approvals')),
                  );
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _pendingApprovals > 9 ? '9+' : _pendingApprovals.toString(),
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
          )
        else
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () {
              // TODO: Navigate to profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile - Coming soon!')),
              );
            },
            child: CircleAvatar(
              backgroundColor: const Color(0xFF667eea),
              child: Text(
                widget.userName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F2027), const Color(0xFF2C5364)]
                    : [const Color(0xFF667eea), const Color(0xFF764ba2)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.admin_panel_settings_rounded,
                      size: 40, color: Color(0xFF667eea)),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'System Owner',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', () {
            setState(() => _selectedIndex = 0);
            Navigator.pop(context);
          }),
          _buildDrawerItem(Icons.school_rounded, 'Schools Management', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SchoolsManagementScreen(
                  userName: widget.userName,
                  userId: widget.userId,
                ),
              ),
            );
          }),
          _buildDrawerItem(Icons.people_rounded, 'All Users', () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Users Management - Coming soon!')),
            );
          }),
          _buildDrawerItem(Icons.pending_actions_rounded,
              'Pending Approvals ($_pendingApprovals)', () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$_pendingApprovals pending approvals')),
                );
              }),
          _buildDrawerItem(Icons.map_rounded, 'Schools Map View', () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Schools Map - Coming soon!')),
            );
          }),
          _buildDrawerItem(Icons.track_changes_rounded, 'Student Tracking', () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Student Tracking - Coming soon!')),
            );
          }),
          _buildDrawerItem(Icons.analytics_rounded, 'System Analytics', () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Analytics - Coming soon!')),
            );
          }),
          _buildDrawerItem(Icons.warning_amber_rounded, 'SOS Alerts', () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('SOS Alerts - Coming soon!')),
            );
          }),
          _buildDrawerItem(Icons.settings_rounded, 'System Settings', () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings - Coming soon!')),
            );
          }),
          const Divider(),
          _buildDrawerItem(Icons.logout_rounded, 'Logout', _showLogoutConfirmation,
              textColor: Colors.red),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {Color? textColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon,
          color: textColor ?? (isDark ? Colors.grey[400] : Colors.grey[700])),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? (isDark ? Colors.white : Colors.black87),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildBody(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadStatistics();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(isDark),
            const SizedBox(height: 24),
            _buildStatsGrid(isDark),
            const SizedBox(height: 24),
            _buildQuickActions(isDark),
            const SizedBox(height: 24),
            _buildRecentActivity(isDark),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            const Color(0xFF667eea).withOpacity(0.2),
            const Color(0xFF764ba2).withOpacity(0.2)
          ]
              : [const Color(0xFF667eea), const Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,',
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.white70)),
                const SizedBox(height: 4),
                Text(widget.userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'You have $_pendingApprovals pending approval${_pendingApprovals == 1 ? "" : "s"} and $_activeSchools active school${_activeSchools == 1 ? "" : "s"}.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.admin_panel_settings_rounded,
              color: Colors.white, size: 50),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    final stats = [
      {
        'title': 'Total Schools',
        'value': _totalSchools.toString(),
        'icon': Icons.school_rounded,
        'color': Colors.indigo,
        'subtitle': '$_activeSchools active',
      },
      {
        'title': 'Students',
        'value': _totalStudents.toString(),
        'icon': Icons.people_rounded,
        'color': Colors.green,
        'subtitle': 'Across all schools',
      },
      {
        'title': 'Parents',
        'value': _totalParents.toString(),
        'icon': Icons.family_restroom_rounded,
        'color': Colors.orange,
        'subtitle': 'Registered users',
      },
      {
        'title': 'Drivers',
        'value': _totalDrivers.toString(),
        'icon': Icons.drive_eta_rounded,
        'color': Colors.blue,
        'subtitle': 'Active drivers',
      },
      {
        'title': 'Teachers',
        'value': _totalTeachers.toString(),
        'icon': Icons.school_rounded,
        'color': Colors.purple,
        'subtitle': 'Active teachers',
      },
      {
        'title': 'Pending',
        'value': _pendingApprovals.toString(),
        'icon': Icons.pending_actions_rounded,
        'color': Colors.red,
        'subtitle': 'Awaiting approval',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(stat, isDark);
      },
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat, bool isDark) {
    return GestureDetector(
      onTap: () {
        if (stat['title'] == 'Pending') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${stat['value']} pending approvals')),
          );
        } else if (stat['title'] == 'Total Schools') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SchoolsManagementScreen(
                userName: widget.userName,
                userId: widget.userId,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (stat['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(stat['icon'] as IconData,
                      color: stat['color'] as Color, size: 24),
                ),
                if (stat['title'] == 'Pending' && _pendingApprovals > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat['title'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  stat['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    final actions = [
      {
        'icon': Icons.add_business_rounded,
        'label': 'Approve School',
        'color': Colors.indigo,
      },
      {
        'icon': Icons.person_add_alt_1_rounded,
        'label': 'Add User',
        'color': Colors.green,
      },
      {
        'icon': Icons.map_rounded,
        'label': 'View Map',
        'color': Colors.blue,
      },
      {
        'icon': Icons.track_changes_rounded,
        'label': 'Track Students',
        'color': Colors.orange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${action['label']} - Coming soon!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (action['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        size: 28,
                        color: action['color'] as Color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      action['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivity(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent System Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Activity Log - Coming soon!')),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text('No recent activity'),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          switch (index) {
            case 0:
            // Dashboard - already here
              break;
            case 1:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Schools Map - Coming soon!')),
              );
              break;
            case 2:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics - Coming soon!')),
              );
              break;
            case 3:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile - Coming soon!')),
              );
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFF667eea),
        unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded), label: 'Analytics'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.add_business_rounded, color: Colors.indigo),
                title: const Text('Approve School'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Approve School - Coming soon!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_rounded, color: Colors.green),
                title: const Text('Add User'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add User - Coming soon!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_rounded, color: Colors.blue),
                title: const Text('View Schools Map'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Schools Map - Coming soon!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}