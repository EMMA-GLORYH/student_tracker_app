import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StudentCheckInOutScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String schoolId;

  const StudentCheckInOutScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.schoolId,
  });

  @override
  State<StudentCheckInOutScreen> createState() => _StudentCheckInOutScreenState();
}

class _StudentCheckInOutScreenState extends State<StudentCheckInOutScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isScanning = false;
  bool _isLoading = false;
  String _selectedTab = 'check_in'; // check_in or check_out

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _todayRecords = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadTodayRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          _students = snapshot.docs
              .map((doc) => {
            'id': doc.id,
            ...doc.data(),
          })
              .toList();
          _filteredStudents = _students;
        });
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
    }
  }

  Future<void> _loadTodayRecords() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection('studentMovements')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          _todayRecords = snapshot.docs
              .map((doc) => {
            'id': doc.id,
            ...doc.data(),
          })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading today records: $e');
    }
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students.where((student) {
          final name = (student['fullName'] ?? '').toLowerCase();
          final studentId = (student['studentId'] ?? '').toLowerCase();
          final className = (student['class'] ?? '').toLowerCase();
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) ||
              studentId.contains(searchLower) ||
              className.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _recordMovement(
      Map<String, dynamic> student,
      String type, // 'check_in' or 'check_out'
      String? notes,
      ) async {
    setState(() => _isLoading = true);

    try {
      // Check if student already has a record today
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final existingRecords = await _firestore
          .collection('studentMovements')
          .where('studentId', isEqualTo: student['id'])
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('type', isEqualTo: type)
          .get();

      if (existingRecords.docs.isNotEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Student already ${type == 'check_in' ? 'checked in' : 'checked out'} today'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Record the movement
      final movement = {
        'studentId': student['id'],
        'studentName': student['fullName'],
        'studentClass': student['class'],
        'schoolId': widget.schoolId,
        'type': type,
        'verifiedBy': widget.userId,
        'verifiedByName': widget.userName,
        'timestamp': FieldValue.serverTimestamp(),
        'notes': notes ?? '',
        'method': _isScanning ? 'QR Code' : 'Manual',
      };

      await _firestore.collection('studentMovements').add(movement);

      // Update attendance if check-in
      if (type == 'check_in') {
        await _updateAttendance(student['id'], 'present');
      }

      // Log activity
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity': '$type: ${student['fullName']}',
        'type': 'student',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Notify parents
      await _notifyParents(student, type);

      await _loadTodayRecords();

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${student['fullName']} ${type == 'check_in' ? 'checked in' : 'checked out'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        if (_isScanning) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error recording movement: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error recording movement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAttendance(String studentId, String status) async {
    try {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);

      await _firestore.collection('attendance').add({
        'studentId': studentId,
        'schoolId': widget.schoolId,
        'date': Timestamp.fromDate(now),
        'dateKey': dateKey,
        'status': status,
        'markedBy': widget.userId,
        'markedByName': widget.userName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating attendance: $e');
    }
  }

  Future<void> _notifyParents(Map<String, dynamic> student, String type) async {
    try {
      // Get parents of the student
      final parentsSnapshot = await _firestore
          .collection('parents')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('children', arrayContains: student['id'])
          .get();

      final message = type == 'check_in'
          ? '${student['fullName']} has checked in at school at ${DateFormat('hh:mm a').format(DateTime.now())}'
          : '${student['fullName']} has checked out from school at ${DateFormat('hh:mm a').format(DateTime.now())}';

      for (var parent in parentsSnapshot.docs) {
        await _firestore.collection('notifications').add({
          'userId': parent.id,
          'title': type == 'check_in' ? 'Student Check-In' : 'Student Check-Out',
          'message': message,
          'type': 'movement',
          'priority': 'normal',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error notifying parents: $e');
    }
  }

  void _showStudentDetails(Map<String, dynamic> student) {
    final notesController = TextEditingController();

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
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['fullName'] ?? 'Unknown Student',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${student['studentId'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Class', student['class'] ?? 'N/A', Icons.class_),
              _buildInfoRow('Grade', student['grade'] ?? 'N/A', Icons.grade),
              _buildInfoRow('Section', student['section'] ?? 'N/A', Icons.group),
              const SizedBox(height: 20),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add any special notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                        Navigator.pop(context);
                        _recordMovement(
                          student,
                          'check_in',
                          notesController.text,
                        );
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Check In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                        Navigator.pop(context);
                        _recordMovement(
                          student,
                          'check_out',
                          notesController.text,
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Check Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
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

  Future<void> _handleQRScan(String studentId) async {
    try {
      final studentDoc = await _firestore.collection('students').doc(studentId).get();

      if (!studentDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student not found!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final student = {'id': studentDoc.id, ...studentDoc.data()!};

      if (mounted) {
        Navigator.pop(context);
        _showStudentDetails(student);
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
            title: const Text('Scan Student QR Code'),
            backgroundColor: Colors.blue,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty || _isLoading) return;

              final String? studentId = barcodes.first.rawValue;
              if (studentId != null) {
                _handleQRScan(studentId);
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
        title: const Text('Student Check-In/Out'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _showQRScanner,
            tooltip: 'Scan QR Code',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.blue,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _selectedTab = 'check_in'),
                    style: TextButton.styleFrom(
                      backgroundColor: _selectedTab == 'check_in'
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'Check In',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _selectedTab = 'check_out'),
                    style: TextButton.styleFrom(
                      backgroundColor: _selectedTab == 'check_out'
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'Check Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _selectedTab = 'history'),
                    style: TextButton.styleFrom(
                      backgroundColor: _selectedTab == 'history'
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'Today\'s Log',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_selectedTab != 'history')
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.withOpacity(0.1),
              child: TextField(
                controller: _searchController,
                onChanged: _filterStudents,
                decoration: InputDecoration(
                  hintText: 'Search students...',
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
            child: _selectedTab == 'history'
                ? _buildHistoryView()
                : _buildStudentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    if (_filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No students found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
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
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.blue,
              ),
            ),
            title: Text(
              student['fullName'] ?? 'Unknown Student',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('ID: ${student['studentId'] ?? 'N/A'}'),
                Text('Class: ${student['class'] ?? 'N/A'}'),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showStudentDetails(student),
          ),
        );
      },
    );
  }

  Widget _buildHistoryView() {
    if (_todayRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No records today',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todayRecords.length,
      itemBuilder: (context, index) {
        final record = _todayRecords[index];
        final timestamp = record['timestamp'] as Timestamp?;
        final timeStr = timestamp != null
            ? DateFormat('hh:mm a').format(timestamp.toDate())
            : 'Unknown time';
        final type = record['type'] ?? 'unknown';
        final isCheckIn = type == 'check_in';

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
                color: isCheckIn
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCheckIn ? Icons.login : Icons.logout,
                color: isCheckIn ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(
              record['studentName'] ?? 'Unknown Student',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Class: ${record['studentClass'] ?? 'N/A'}'),
                Text('Time: $timeStr'),
                Text('By: ${record['verifiedByName'] ?? 'Unknown'}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCheckIn
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCheckIn ? 'IN' : 'OUT',
                style: TextStyle(
                  color: isCheckIn ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}