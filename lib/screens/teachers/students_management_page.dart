import 'package:flutter/material.dart';
import 'student_profile_page.dart';

class StudentsManagementPage extends StatefulWidget {
  final String teacherId;

  const StudentsManagementPage({super.key, required this.teacherId});

  @override
  State<StudentsManagementPage> createState() => _StudentsManagementPageState();
}

class _StudentsManagementPageState extends State<StudentsManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String selectedClass = 'All Classes';

  final List<String> classes = [
    'All Classes',
    'Class 1A',
    'Class 1B',
    'Class 2A',
    'Class 2B'
  ];

  // Sample student data
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
      'attendance': 95,
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
      'attendance': 88,
      'photo': null,
    },
    {
      'id': 'STU003',
      'name': 'Kofi Asante',
      'gender': 'Male',
      'class': 'Class 2A',
      'age': 9,
      'guardianName': 'Mr. Asante',
      'guardianPhone': '+233 24 345 6789',
      'address': '789 Tema Avenue',
      'emergencyContact': '+233 20 765 4321',
      'bloodGroup': 'B+',
      'allergies': 'None',
      'attendance': 92,
      'photo': null,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getFilteredStudents() {
    List<Map<String, dynamic>> filtered = allStudents;

    // Filter by class
    if (selectedClass != 'All Classes') {
      filtered = filtered.where((s) => s['class'] == selectedClass).toList();
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
                .contains(searchQuery.toLowerCase()) ||
            student['guardianName']
                .toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = getFilteredStudents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Students'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID, or guardian...',
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
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Class Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedClass,
                      icon: const Icon(Icons.arrow_drop_down),
                      items: classes.map((classItem) {
                        return DropdownMenuItem(
                          value: classItem,
                          child: Row(
                            children: [
                              const Icon(Icons.filter_list, size: 20),
                              const SizedBox(width: 8),
                              Text(classItem),
                            ],
                          ),
                        );
                      }).toList(),
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

          // Student Count
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredStudents.length} Students',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () {
                    _showSortOptions(context);
                  },
                ),
              ],
            ),
          ),

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
                  child: InkWell(
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
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Profile Picture
                          CircleAvatar(
                            radius: 30,
                            backgroundColor:
                            student['gender'] == 'Male'
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
                          const SizedBox(width: 16),

                          // Student Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${student['id']} • ${student['class']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline,
                                        size: 14,
                                        color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        student['guardianName'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Attendance Badge
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getAttendanceColor(
                                      student['attendance'])
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${student['attendance']}%',
                                  style: TextStyle(
                                    color: _getAttendanceColor(
                                        student['attendance']),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Attendance',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey.shade400),
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
    );
  }

  Color _getAttendanceColor(int attendance) {
    if (attendance >= 90) return Colors.green;
    if (attendance >= 75) return Colors.orange;
    return Colors.red;
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption('Name (A-Z)', Icons.sort_by_alpha),
            _buildSortOption('Attendance (High to Low)', Icons.trending_down),
            _buildSortOption('Class', Icons.class_),
            _buildSortOption('Recently Added', Icons.access_time),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.purple),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sorted by $label')),
        );
      },
    );
  }
}