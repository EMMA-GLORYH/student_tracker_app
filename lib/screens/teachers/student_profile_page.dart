import 'package:flutter/material.dart';

class StudentProfilePage extends StatelessWidget {
  final Map<String, dynamic> student;

  const StudentProfilePage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade700],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: student['gender'] == 'Male'
                          ? Colors.blue.shade100
                          : Colors.pink.shade100,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: student['gender'] == 'Male'
                            ? Colors.blue.shade700
                            : Colors.pink.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    student['name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Student ID: ${student['id']}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      student['class'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Personal Information
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.cake,
                    color: Colors.orange,
                    label: 'Age',
                    value: '${student['age']} years old',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: student['gender'] == 'Male'
                        ? Icons.male
                        : Icons.female,
                    color: student['gender'] == 'Male'
                        ? Colors.blue
                        : Colors.pink,
                    label: 'Gender',
                    value: student['gender'],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.location_on,
                    color: Colors.red,
                    label: 'Address',
                    value: student['address'],
                  ),
                  const SizedBox(height: 24),

                  // Medical Information
                  const Text(
                    'Medical Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.bloodtype,
                    color: Colors.red,
                    label: 'Blood Group',
                    value: student['bloodGroup'],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                    label: 'Allergies',
                    value: student['allergies'],
                  ),
                  const SizedBox(height: 24),

                  // Guardian Information
                  const Text(
                    'Guardian Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    color: Colors.purple,
                    label: 'Guardian Name',
                    value: student['guardianName'],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.phone,
                    color: Colors.green,
                    label: 'Guardian Phone',
                    value: student['guardianPhone'],
                    isClickable: true,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.emergency,
                    color: Colors.red,
                    label: 'Emergency Contact',
                    value: student['emergencyContact'],
                    isClickable: true,
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Call guardian
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Calling ${student['guardianName']}...'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('Call Guardian'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Send message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opening message...'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Send Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    bool isClickable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
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
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isClickable)
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}