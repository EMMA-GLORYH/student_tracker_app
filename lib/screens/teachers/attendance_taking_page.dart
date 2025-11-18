import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'student_profile_page.dart';

class AttendanceTakingPage extends StatefulWidget {
  final String teacherId;

  const AttendanceTakingPage({super.key, required this.teacherId});

  @override
  State<AttendanceTakingPage> createState() => _AttendanceTakingPageState();
}

class _AttendanceTakingPageState extends State<AttendanceTakingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  String selectedClass = 'Class 1A';
  String searchQuery = '';

  // Sample student data - Replace with your database
  final List<Map<String, dynamic>> allStudents = [
    {
      'id': 'STU001',
      'name': 'Kwame Mensah',
      'gender': 'Male',
      'class': 'Class 1A',
      'age': 8,
      'guardianName': 'Mr. Mensah',
      'guardianPhone': '+233 24 123 4567',
      'address': '123 Accra Street',
      'emergencyContact': '+233 20 987 6543',
      'bloodGroup': 'O+',
      'allergies': 'None',
      'photo': null,
    },
    {
      'id': 'STU002',
      'name': 'Ama Osei',
      'gender': 'Female',
      'class': 'Class 1A',
      'age': 7,
      'guardianName': 'Mrs. Osei',
      'guardianPhone': '+233 24 234 5678',
      'address': '456 Kumasi Road',
      'emergencyContact': '+233 20 876 5432',
      'bloodGroup': 'A+',
      'allergies': 'Peanuts',
      'photo': null,
    },
    {
      'id': 'STU003',
      'name': 'Kofi Asante',
      'gender': 'Male',
      'class': 'Class 1A',
      'age': 8,
      'guardianName': 'Mr. Asante',
      'guardianPhone': '+233 24 345 6789',
      'address': '789 Tema Avenue',
      'emergencyContact': '+233 20 765 4321',
      'bloodGroup': 'B+',
      'allergies': 'None',
      'photo': null,
    },
    {
      'id': 'STU004',
      'name': 'Akosua Boateng',
      'gender': 'Female',
      'class': 'Class 1A',
      'age': 7,
      'guardianName': 'Mrs. Boateng',
      'guardianPhone': '+233 24 456 7890',
      'address': '321 Takoradi Street',
      'emergencyContact': '+233 20 654 3210',
      'bloodGroup': 'AB+',
      'allergies': 'Dust',
      'photo': null,
    },
  ];

  Map<String, bool> attendanceMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeAttendance();
  }

  void _initializeAttendance() {
    for (var student in allStudents) {
      attendanceMap[student['id']] = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getFilteredStudents() {
    List<Map<String, dynamic>> filtered = allStudents;

    // Filter by tab (gender)
    if (_tabController.index == 1) {
      filtered = filtered.where((s) => s['gender'] == 'Male').toList();
    } else if (_tabController.index == 2) {
      filtered = filtered.where((s) => s['gender'] == 'Female').toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((student) {
        return student['name']
            .toString()
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            student['id']
                .toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void _submitAttendance() {
    int presentCount =
        attendanceMap.values.where((present) => present).length;
    int totalCount = getFilteredStudents().length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Attendance'),
        content: Text(
          'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}\n'
              'Time: ${selectedTime.format(context)}\n'
              'Class: $selectedClass\n\n'
              'Present: $presentCount\n'
              'Absent: ${totalCount - presentCount}\n\n'
              'Submit attendance?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Save to database
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attendance submitted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = getFilteredStudents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: Colors.blue,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Males'),
            Tab(text: 'Females'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date, Time, and Class Selection
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM dd, yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _selectTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                selectedTime.format(context),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedClass,
                      items: ['Class 1A', 'Class 1B', 'Class 2A', 'Class 2B']
                          .map((classItem) => DropdownMenuItem(
                        value: classItem,
                        child: Text(classItem),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClass = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search student by name or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      searchQuery = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          // Student Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredStudents.length} Students',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Present: ${attendanceMap.values.where((v) => v).length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Student List
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No students found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentProfilePage(
                              student: student,
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: student['gender'] == 'Male'
                            ? Colors.blue.shade100
                            : Colors.pink.shade100,
                        child: Icon(
                          Icons.person,
                          color: student['gender'] == 'Male'
                              ? Colors.blue.shade700
                              : Colors.pink.shade700,
                          size: 32,
                        ),
                      ),
                    ),
                    title: Text(
                      student['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${student['id']} • ${student['gender']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Checkbox(
                      value: attendanceMap[student['id']] ?? false,
                      onChanged: (bool? value) {
                        setState(() {
                          attendanceMap[student['id']] = value ?? false;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              offset: const Offset(0, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    for (var student in filteredStudents) {
                      attendanceMap[student['id']] = true;
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Mark All Present'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Submit Attendance'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}