import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ PROFESSIONAL CHILD SEARCH & ASSIGNMENT PAGE
/// - Search students in school database
/// - Send assignment requests to parents
/// - School admin approval workflow
/// - Real-time search with filters

class SearchAssignChildrenPage extends StatefulWidget {
  final String parentId;
  final String schoolId;

  const SearchAssignChildrenPage({
    super.key,
    required this.parentId,
    required this.schoolId,
  });

  @override
  State<SearchAssignChildrenPage> createState() => _SearchAssignChildrenPageState();
}

class _SearchAssignChildrenPageState extends State<SearchAssignChildrenPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _dotsController;

  List<Map<String, dynamic>> _searchResults = [];
  List<String> _assignedChildrenIds = [];
  List<String> _pendingRequestIds = [];

  bool _isSearching = false;
  bool _isLoading = true;
  String _selectedGrade = 'All';
  List<String> _grades = ['All'];

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _loadInitialData();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Load grades available in the school
      final gradesSnapshot = await _firestore
          .collection('students')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      Set<String> gradeSet = {'All'};
      for (var doc in gradesSnapshot.docs) {
        final grade = doc.data()['grade'] as String?;
        if (grade != null && grade.isNotEmpty) {
          gradeSet.add(grade);
        }
      }

      // Load already assigned children
      final assignedSnapshot = await _firestore
          .collection('childAssignments')
          .where('parentId', isEqualTo: widget.parentId)
          .where('status', isEqualTo: 'approved')
          .get();

      List<String> assigned = assignedSnapshot.docs.map((doc) => doc.data()['studentId'] as String).toList();

      // Load pending requests
      final pendingSnapshot = await _firestore
          .collection('childAssignments')
          .where('parentId', isEqualTo: widget.parentId)
          .where('status', isEqualTo: 'pending')
          .get();

      List<String> pending = pendingSnapshot.docs.map((doc) => doc.data()['studentId'] as String).toList();

      if (mounted) {
        setState(() {
          _grades = gradeSet.toList()..sort();
          _assignedChildrenIds = assigned;
          _pendingRequestIds = pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Error', 'Failed to load data. Please try again.');
      }
    }
  }

  Future<void> _searchStudents() async {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      Query studentsQuery = _firestore.collection('students').where('schoolId', isEqualTo: widget.schoolId);

      // Apply grade filter
      if (_selectedGrade != 'All') {
        studentsQuery = studentsQuery.where('grade', isEqualTo: _selectedGrade);
      }

      final snapshot = await studentsQuery.get();

      List<Map<String, dynamic>> results = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final fullName = (data['fullName'] ?? '').toString().toLowerCase();
        final studentId = (data['studentId'] ?? '').toString().toLowerCase();

        // Search by name or student ID
        if (fullName.contains(query) || studentId.contains(query)) {
          results.add({
            'id': doc.id,
            'studentId': data['studentId'] ?? '',
            'fullName': data['fullName'] ?? 'Unknown',
            'grade': data['grade'] ?? 'N/A',
            'classRoom': data['classRoom'] ?? 'N/A',
            'dateOfBirth': data['dateOfBirth'],
            'gender': data['gender'] ?? 'N/A',
            'profileImage': data['profileImage'] ?? '',
            'schoolName': data['schoolName'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error searching students: $e');
      if (mounted) {
        setState(() => _isSearching = false);
        _showErrorDialog('Error', 'Failed to search students. Please try again.');
      }
    }
  }

  Future<void> _requestChildAssignment(Map<String, dynamic> student) async {
    // Show relationship selection dialog
    final relationship = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Relationship'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Mother'),
              onTap: () => Navigator.pop(context, 'Mother'),
            ),
            ListTile(
              title: const Text('Father'),
              onTap: () => Navigator.pop(context, 'Father'),
            ),
            ListTile(
              title: const Text('Guardian'),
              onTap: () => Navigator.pop(context, 'Guardian'),
            ),
            ListTile(
              title: const Text('Other'),
              onTap: () => Navigator.pop(context, 'Other'),
            ),
          ],
        ),
      ),
    );

    if (relationship == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Assignment Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are requesting to assign:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1929).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['fullName'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text('Student ID: ${student['studentId']}', style: const TextStyle(fontSize: 12)),
                  Text('Grade: ${student['grade']}', style: const TextStyle(fontSize: 12)),
                  Text('Relationship: $relationship', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This request will be sent to the school admin for verification. You will be notified once approved.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A1929)),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Get parent info
      final parentDoc = await _firestore.collection('parents').doc(widget.parentId).get();
      final parentData = parentDoc.data()!;

      // Create assignment request
      await _firestore.collection('childAssignments').add({
        'parentId': widget.parentId,
        'parentName': parentData['fullName'] ?? '',
        'parentEmail': parentData['email'] ?? '',
        'parentPhone': parentData['phone'] ?? '',
        'studentId': student['id'],
        'childName': student['fullName'],
        'childStudentId': student['studentId'],
        'childGrade': student['grade'],
        'schoolId': widget.schoolId,
        'relationship': relationship,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'emergencyContact': false,
      });

      // Send notification to school admin
      await _firestore.collection('notifications').add({
        'userId': 'ADMIN', // Will be updated to actual admin ID
        'userType': 'admin',
        'type': 'assignment_request',
        'title': 'New Child Assignment Request',
        'message': '${parentData['fullName']} requested to assign ${student['fullName']}',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'parentId': widget.parentId,
          'studentId': student['id'],
        },
      });

      if (mounted) {
        setState(() {
          _pendingRequestIds.add(student['id']);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Assignment request sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending assignment request: $e');
      if (mounted) {
        _showErrorDialog('Error', 'Failed to send request. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                              color: index == 1 ? const Color(0xFF0A1929) : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: (index == 1 ? const Color(0xFF0A1929) : Colors.white).withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Loading students...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Search for My Child', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchHeader(isDark),
          Expanded(
            child: _buildSearchResults(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or student ID...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF0A1929)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _searchStudents();
                },
              )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (value) {
              setState(() {});
              if (value.length >= 2) {
                _searchStudents();
              } else if (value.isEmpty) {
                setState(() => _searchResults = []);
              }
            },
          ),

          const SizedBox(height: 12),

          // Grade filter
          Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: Color(0xFF0A1929)),
              const SizedBox(width: 8),
              const Text(
                'Filter by Grade:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _grades.length,
                    itemBuilder: (context, index) {
                      final grade = _grades[index];
                      final isSelected = grade == _selectedGrade;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(grade),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedGrade = grade;
                            });
                            if (_searchController.text.isNotEmpty) {
                              _searchStudents();
                            }
                          },
                          backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F7FA),
                          selectedColor: const Color(0xFF0A1929),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_searchController.text.isEmpty) {
      return _buildEmptyState(isDark, 'Start searching', 'Enter a child\'s name or student ID to begin');
    }

    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF0A1929)),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(isDark, 'No results found', 'Try different search terms or filters');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final student = _searchResults[index];
        return _buildStudentCard(student, isDark);
      },
    );
  }

  Widget _buildEmptyState(bool isDark, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isDark) {
    final isAssigned = _assignedChildrenIds.contains(student['id']);
    final isPending = _pendingRequestIds.contains(student['id']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Profile image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A1929), Color(0xFF1A2F3F)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: student['profileImage'] != null && student['profileImage'].isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      student['profileImage'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.child_care, color: Colors.white, size: 32);
                      },
                    ),
                  )
                      : const Icon(Icons.child_care, color: Colors.white, size: 32),
                ),

                const SizedBox(width: 16),

                // Student info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['fullName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${student['studentId']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1929).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              student['grade'],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A1929),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            student['classRoom'],
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status badge
                if (isAssigned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'ASSIGNED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          'PENDING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (!isAssigned && !isPending) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _requestChildAssignment(student),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Request Assignment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A1929),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
}