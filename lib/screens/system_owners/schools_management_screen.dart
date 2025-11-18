import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolsManagementScreen extends StatefulWidget {
  final String userName;
  final String userId;

  const SchoolsManagementScreen({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<SchoolsManagementScreen> createState() => _SchoolsManagementScreenState();
}

class _SchoolsManagementScreenState extends State<SchoolsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _isGridView = false;

  // Statistics
  int _totalSchools = 0;
  int _activeSchools = 0;
  int _inactiveSchools = 0;
  int _pendingSchools = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      final allSchools = await FirebaseFirestore.instance
          .collection('schools')
          .get();

      final activeSchools = await FirebaseFirestore.instance
          .collection('schools')
          .where('isActive', isEqualTo: true)
          .where('verified', isEqualTo: true)
          .get();

      final inactiveSchools = await FirebaseFirestore.instance
          .collection('schools')
          .where('isActive', isEqualTo: false)
          .get();

      final pendingSchools = await FirebaseFirestore.instance
          .collection('schools')
          .where('verified', isEqualTo: false)
          .get();

      setState(() {
        _totalSchools = allSchools.docs.length;
        _activeSchools = activeSchools.docs.length;
        _inactiveSchools = inactiveSchools.docs.length;
        _pendingSchools = pendingSchools.docs.length;
      });
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  Stream<QuerySnapshot> _getSchoolsStream() {
    Query query = FirebaseFirestore.instance.collection('schools');

    // Apply filter based on selected tab
    switch (_tabController.index) {
      case 0: // All Schools
        break;
      case 1: // Active
        query = query.where('isActive', isEqualTo: true)
            .where('verified', isEqualTo: true);
        break;
      case 2: // Inactive
        query = query.where('isActive', isEqualTo: false);
        break;
      case 3: // Pending
        query = query.where('verified', isEqualTo: false);
        break;
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildStatisticsCards(isDark),
          _buildSearchAndFilter(isDark),
          _buildTabBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSchoolsList('all'),
                _buildSchoolsList('active'),
                _buildSchoolsList('inactive'),
                _buildSchoolsList('pending'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSchoolDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add School'),
        backgroundColor: const Color(0xFF667eea),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schools Management',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Manage all registered schools',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.filter_list_rounded),
          onPressed: _showFilterDialog,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            switch (value) {
              case 'export':
                _exportSchoolsData();
                break;
              case 'import':
                _importSchoolsData();
                break;
              case 'bulk':
                _showBulkActionsDialog();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Export Data'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.upload_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Import Schools'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'bulk',
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Bulk Actions'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticsCards(bool isDark) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard('Total', _totalSchools, Colors.blue, Icons.school_rounded, isDark),
          _buildStatCard('Active', _activeSchools, Colors.green, Icons.check_circle_rounded, isDark),
          _buildStatCard('Inactive', _inactiveSchools, Colors.orange, Icons.pause_circle_rounded, isDark),
          _buildStatCard('Pending', _pendingSchools, Colors.red, Icons.pending_actions_rounded, isDark),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color, IconData icon, bool isDark) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
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
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search schools by name, ID, or location...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
            },
          )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return TabBar(
      controller: _tabController,
      indicatorColor: const Color(0xFF667eea),
      labelColor: const Color(0xFF667eea),
      unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
      tabs: [
        Tab(text: 'All ($_totalSchools)'),
        Tab(text: 'Active ($_activeSchools)'),
        Tab(text: 'Inactive ($_inactiveSchools)'),
        Tab(text: 'Pending ($_pendingSchools)'),
      ],
      onTap: (index) {
        setState(() {});
      },
    );
  }

  Widget _buildSchoolsList(String filter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getSchoolsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final schools = snapshot.data?.docs ?? [];

        // Apply search filter
        final filteredSchools = schools.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['schoolName'] ?? '').toString().toLowerCase();
          final id = (data['schoolId'] ?? '').toString().toLowerCase();
          final location = (data['location'] ?? '').toString().toLowerCase();

          return name.contains(_searchQuery) ||
              id.contains(_searchQuery) ||
              location.contains(_searchQuery);
        }).toList();

        if (filteredSchools.isEmpty) {
          return _buildEmptyState(filter);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _loadStatistics();
            setState(() {});
          },
          child: _isGridView
              ? _buildGridView(filteredSchools)
              : _buildListView(filteredSchools),
        );
      },
    );
  }

  Widget _buildGridView(List<QueryDocumentSnapshot> schools) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: schools.length,
      itemBuilder: (context, index) {
        final data = schools[index].data() as Map<String, dynamic>;
        return _buildSchoolGridCard(data, schools[index].id, isDark);
      },
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot> schools) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schools.length,
      itemBuilder: (context, index) {
        final data = schools[index].data() as Map<String, dynamic>;
        return _buildSchoolListCard(data, schools[index].id, isDark);
      },
    );
  }

  Widget _buildSchoolGridCard(Map<String, dynamic> data, String docId, bool isDark) {
    final isActive = data['isActive'] ?? false;
    final isVerified = data['verified'] ?? false;

    return GestureDetector(
      onTap: () => _showSchoolDetails(data, docId),
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF667eea),
                    size: 24,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (value) => _handleSchoolAction(value, docId, data),
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'view', child: Text('View Details')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: isActive ? 'deactivate' : 'activate',
                      child: Text(isActive ? 'Deactivate' : 'Activate'),
                    ),
                    if (!isVerified)
                      const PopupMenuItem(value: 'verify', child: Text('Verify')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['schoolName'] ?? 'Unknown School',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              data['schoolId'] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                _buildStatusChip(
                  isActive ? 'Active' : 'Inactive',
                  isActive ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                if (!isVerified)
                  _buildStatusChip('Pending', Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people_rounded,
                    size: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${data['studentCount'] ?? 0}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on_rounded,
                    size: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['location'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolListCard(Map<String, dynamic> data, String docId, bool isDark) {
    final isActive = data['isActive'] ?? false;
    final isVerified = data['verified'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Color(0xFF667eea),
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['schoolName'] ?? 'Unknown School',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildStatusChip(
              isActive ? 'Active' : 'Inactive',
              isActive ? Colors.green : Colors.orange,
            ),
            if (!isVerified) ...[
              const SizedBox(width: 8),
              _buildStatusChip('Pending', Colors.red),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'ID: ${data['schoolId'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['location'] ?? 'Unknown location',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildInfoChip(Icons.people_rounded, '${data['studentCount'] ?? 0} Students'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.person_rounded, '${data['teacherCount'] ?? 0} Teachers'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.drive_eta_rounded, '${data['driverCount'] ?? 0} Drivers'),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) => _handleSchoolAction(value, docId, data),
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: isActive ? 'deactivate' : 'activate',
              child: Text(isActive ? 'Deactivate' : 'Activate'),
            ),
            if (!isVerified)
              const PopupMenuItem(value: 'verify', child: Text('Verify')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _showSchoolDetails(data, docId),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String filter) {
    String message;
    IconData icon;

    switch (filter) {
      case 'active':
        message = 'No active schools found';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'inactive':
        message = 'No inactive schools found';
        icon = Icons.pause_circle_outline_rounded;
        break;
      case 'pending':
        message = 'No pending schools for approval';
        icon = Icons.pending_actions_rounded;
        break;
      default:
        message = _searchQuery.isNotEmpty
            ? 'No schools found matching "$_searchQuery"'
            : 'No schools registered yet';
        icon = Icons.school_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  void _handleSchoolAction(String action, String docId, Map<String, dynamic> data) {
    switch (action) {
      case 'view':
        _showSchoolDetails(data, docId);
        break;
      case 'edit':
        _showEditSchoolDialog(data, docId);
        break;
      case 'activate':
      case 'deactivate':
        _toggleSchoolStatus(docId, action == 'activate');
        break;
      case 'verify':
        _verifySchool(docId);
        break;
      case 'delete':
        _showDeleteConfirmation(docId, data['schoolName'] ?? 'this school');
        break;
    }
  }

  void _showSchoolDetails(Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Color(0xFF667eea),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['schoolName'] ?? 'Unknown School',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${data['schoolId'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('Location', data['location'] ?? 'Not specified', Icons.location_on_rounded),
                  _buildDetailRow('Contact', data['contact'] ?? 'Not specified', Icons.phone_rounded),
                  _buildDetailRow('Email', data['email'] ?? 'Not specified', Icons.email_rounded),
                  _buildDetailRow('Students', '${data['studentCount'] ?? 0}', Icons.people_rounded),
                  _buildDetailRow('Teachers', '${data['teacherCount'] ?? 0}', Icons.person_rounded),
                  _buildDetailRow('Drivers', '${data['driverCount'] ?? 0}', Icons.drive_eta_rounded),
                  _buildDetailRow('Status', (data['isActive'] ?? false) ? 'Active' : 'Inactive', Icons.info_rounded),
                  _buildDetailRow('Verified', (data['verified'] ?? false) ? 'Yes' : 'No', Icons.verified_rounded),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditSchoolDialog(data, docId);
                          },
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(docId, data['schoolName'] ?? 'this school');
                          },
                          icon: const Icon(Icons.delete_rounded, color: Colors.red),
                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSchoolDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final contactController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_business_rounded, color: Color(0xFF667eea)),
              SizedBox(width: 12),
              Text('Add New School'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'School Name',
                      prefixIcon: Icon(Icons.school_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter school name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_rounded),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        // ✅ Corrected regex and syntax
                        final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameController.dispose();
                locationController.dispose();
                contactController.dispose();
                emailController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final schoolId = 'SCH${DateTime.now().millisecondsSinceEpoch}';
                    await FirebaseFirestore.instance.collection('schools').add({
                      'schoolId': schoolId,
                      'schoolName': nameController.text.trim(),
                      'location': locationController.text.trim(),
                      'contact': contactController.text.trim(),
                      'email': emailController.text.trim(),
                      'isActive': false,
                      'verified': false,
                      'studentCount': 0,
                      'teacherCount': 0,
                      'driverCount': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy': widget.userId,
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('School added successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadStatistics();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add School'),
            ),
          ],
        );
      },
    );
  }


  void _showEditSchoolDialog(Map<String, dynamic> data, String docId) {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: data['schoolName']);
  final locationController = TextEditingController(text: data['location']);
  final contactController = TextEditingController(text: data['contact']);
  final emailController = TextEditingController(text: data['email']);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: Color(0xFF667eea)),
              SizedBox(width: 12),
              Text('Edit School'),
            ],
          ),
          content: SingleChildScrollView(
              child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'School Name',
                      prefixIcon: Icon(Icons.school_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter school name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_rounded),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        // Create a proper regex for email
                        if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                      }
                      return null;
                    },

                  ),
  ],
  ),
  ),
  ),
  actions: [
  TextButton(
  onPressed: () {
  nameController.dispose();
  locationController.dispose();
  contactController.dispose();
  emailController.dispose();
  Navigator.pop(context);
  },
  child: const Text('Cancel'),
  ),
  ElevatedButton(
  onPressed: () async {
  if (formKey.currentState!.validate()) {
  try {
  await FirebaseFirestore.instance
      .collection('schools')
      .doc(docId)
      .update({
  'schoolName': nameController.text.trim(),
  'location': locationController.text.trim(),
  'contact': contactController.text.trim(),
  'email': emailController.text.trim(),
  'updatedAt': FieldValue.serverTimestamp(),
  'updatedBy': widget.userId,
  });

  if (mounted) {
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
  content: Text('School updated successfully'),
  backgroundColor: Colors.green,
  ),
  );
  _loadStatistics();
  }
  } catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text('Error: $e'),
  backgroundColor: Colors.red,
  ),
  );
  }
  }
  },
  style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF667eea),
  foregroundColor: Colors.white,
  ),
  child: const Text('Update School'),
  ),
  ],
  );
  },
);
}

void _toggleSchoolStatus(String docId, bool activate) async {
  try {
    await FirebaseFirestore.instance
        .collection('schools')
        .doc(docId)
        .update({
      'isActive': activate,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': widget.userId,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('School ${activate ? 'activated' : 'deactivated'} successfully'),
        backgroundColor: Colors.green,
      ),
    );
    _loadStatistics();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _verifySchool(String docId) async {
  try {
    await FirebaseFirestore.instance
        .collection('schools')
        .doc(docId)
        .update({
      'verified': true,
      'isActive': true,
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': widget.userId,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('School verified successfully'),
        backgroundColor: Colors.green,
      ),
    );
    _loadStatistics();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _showDeleteConfirmation(String docId, String schoolName) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirm Delete'),
          ],
        ),
        content: Text('Are you sure you want to delete "$schoolName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(docId)
                    .delete();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('School deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadStatistics();
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}

void _showFilterDialog() {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Advanced filters - Coming soon!')),
  );
}

void _exportSchoolsData() {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Export functionality - Coming soon!')),
  );
}

void _importSchoolsData() {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Import functionality - Coming soon!')),
  );
}

void _showBulkActionsDialog() {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Bulk actions - Coming soon!')),
  );
}
}