import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ParentProfilePage extends StatefulWidget {
  final String parentId;
  const ParentProfilePage({super.key, required this.parentId});

  @override
  State<ParentProfilePage> createState() => _ParentProfilePageState();
}

class _ParentProfilePageState extends State<ParentProfilePage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  // ✅ New credential controllers
  final _ghanaCardNumberController = TextEditingController();
  final _occupationController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _alternativePhoneController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _workAddressController = TextEditingController();

  bool _isLoading = false; // ✅ No initial loading screen
  bool _isSaving = false;
  bool _isEditing = false;
  bool _profileCompleted = false;
  File? _profileImage;
  File? _ghanaCardImage; // ✅ Ghana Card image
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _childAssignments = [];

  // Professional Navy Blue Color Scheme (matching dashboard)
  static const Color primaryColor = Color(0xFF0A1929); // Navy Blue
  static const Color secondaryColor = Color(0xFF1A2F3F); // Dark Navy
  static const Color accentColor = Color(0xFF059669); // Green for success
  static const Color warningColor = Color(0xFFFFA726); // Orange for warnings
  static const Color darkBackground = Color(0xFF121212); // Dark background
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightCard = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadParentProfile();
  }

  Future<void> _loadParentProfile() async {
    // Load silently in background - no loading screen

    try {
      debugPrint('🔍 Loading parent profile for: ${widget.parentId}');

      // Load parent profile
      final parentDoc = await _firestore.collection('parents').doc(widget.parentId).get();

      if (parentDoc.exists) {
        final data = parentDoc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? data['fullName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';
          _addressController.text = data['address'] ?? '';
          _emergencyContactController.text = data['emergencyContact'] ?? '';

          // ✅ Load new credentials
          _ghanaCardNumberController.text = data['ghanaCardNumber'] ?? '';
          _occupationController.text = data['occupation'] ?? '';
          _dateOfBirthController.text = data['dateOfBirth'] ?? '';
          _alternativePhoneController.text = data['alternativePhone'] ?? '';
          _nationalityController.text = data['nationality'] ?? 'Ghanaian';
          _workAddressController.text = data['workAddress'] ?? '';

          _profileCompleted = data['profileCompleted'] ?? false;
        });
        debugPrint('✅ Parent profile loaded: ${data['name'] ?? data['fullName']}');
      } else {
        debugPrint('⚠️ Parent document not found');
      }

      // Load approved children assignments
      final assignmentsSnapshot = await _firestore
          .collection('childAssignments')
          .where('parentId', isEqualTo: widget.parentId)
          .where('status', isEqualTo: 'approved')
          .get();

      debugPrint('📋 Found ${assignmentsSnapshot.docs.length} approved assignments');

      List<Map<String, dynamic>> childrenList = [];

      for (var doc in assignmentsSnapshot.docs) {
        final assignmentData = doc.data();
        final studentId = assignmentData['studentId'] as String?;

        debugPrint('👶 Processing assignment: ${doc.id}');
        debugPrint('   - Child Name: ${assignmentData['childName']}');
        debugPrint('   - Student ID: $studentId');
        debugPrint('   - Relationship: ${assignmentData['relationship']}');

        if (studentId == null || studentId.isEmpty) {
          debugPrint('   ⚠️ Skipping - no studentId');
          continue;
        }

        // Get student details from students collection
        final studentDoc = await _firestore.collection('students').doc(studentId).get();

        if (studentDoc.exists) {
          // Student document exists - use student data
          final studentData = studentDoc.data()!;
          debugPrint('   ✅ Student document found');
          debugPrint('   - Full Name: ${studentData['fullName']}');
          debugPrint('   - Class: ${studentData['class']}');

          childrenList.add({
            'id': studentId,
            'assignmentId': doc.id,
            'name': studentData['fullName'] ?? assignmentData['childName'] ?? 'Unknown',
            'age': _calculateAge(studentData['dateOfBirth']),
            'grade': studentData['grade'] ?? studentData['class'] ?? 'N/A',
            'class': studentData['class'] ?? 'N/A',
            'classRoom': studentData['classRoom'] ?? 'N/A',
            'school': studentData['schoolName'] ?? 'N/A',
            'schoolId': studentData['schoolId'] ?? assignmentData['schoolId'] ?? '',
            'studentId': studentData['studentId'] ?? assignmentData['childStudentId'] ?? '',
            'profileImage': studentData['profileImage'] ?? '',
            'relationship': assignmentData['relationship'] ?? 'Parent',
            'emergencyContact': assignmentData['emergencyContact'] ?? false,
            'status': studentData['status'] ?? 'Unknown',
            'approvedAt': assignmentData['approvedAt'],
            'approvedBy': assignmentData['approvedBy'],
          });
        } else {
          // Student document doesn't exist - use childAssignment data as fallback
          debugPrint('   ⚠️ Student document not found - using assignment data');
          childrenList.add({
            'id': studentId,
            'assignmentId': doc.id,
            'name': assignmentData['childName'] ?? 'Unknown',
            'age': 0,
            'grade': assignmentData['childGrade'] ?? 'N/A',
            'class': assignmentData['childGrade'] ?? 'N/A',
            'classRoom': 'N/A',
            'school': 'N/A',
            'schoolId': assignmentData['schoolId'] ?? '',
            'studentId': assignmentData['childStudentId'] ?? studentId,
            'profileImage': '',
            'relationship': assignmentData['relationship'] ?? 'Parent',
            'emergencyContact': assignmentData['emergencyContact'] ?? false,
            'status': 'Unknown',
            'approvedAt': assignmentData['approvedAt'],
            'approvedBy': assignmentData['approvedBy'],
          });
        }
      }

      debugPrint('✅ Total children loaded: ${childrenList.length}');

      setState(() {
        _children = childrenList;
        _childAssignments = assignmentsSnapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      _showSnackBar('Error loading profile: $e', isError: true);
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
      return 0;
    }
  }

  Future<void> _saveParentProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('parents').doc(widget.parentId).set({
        'userId': widget.parentId,
        'fullName': _nameController.text.trim(),
        'name': _nameController.text.trim(), // Keep both for compatibility
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),

        // ✅ Save new credentials
        'ghanaCardNumber': _ghanaCardNumberController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'dateOfBirth': _dateOfBirthController.text.trim(),
        'alternativePhone': _alternativePhoneController.text.trim(),
        'nationality': _nationalityController.text.trim(),
        'workAddress': _workAddressController.text.trim(),

        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _isSaving = false;
        _isEditing = false;
        _profileCompleted = true;
      });

      _loadParentProfile();
      _showSnackBar('Profile updated successfully!', isError: false);
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Error saving profile: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? warningColor : accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? darkBackground : lightBackground,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileStats(isDark),
                const SizedBox(height: 24),
                _buildTabBar(isDark),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(isDark),
                _buildChildrenTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 260,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? darkCard : primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,      // Navy Blue
                secondaryColor,    // Dark Navy
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildProfileAvatar(),
                const SizedBox(height: 16),
                Text(
                  _nameController.text.isEmpty ? 'Complete Your Profile' : _nameController.text,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _emailController.text.isEmpty ? 'Parent' : _emailController.text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!_isEditing)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () => setState(() => _isEditing = true),
            tooltip: 'Edit Profile',
          ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white,
            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
            child: _profileImage == null
                ? Icon(Icons.person, size: 60, color: primaryColor)
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: () async {
              final picker = ImagePicker();
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setState(() => _profileImage = File(image.path));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStats(bool isDark) {
    final isVerified = _ghanaCardNumberController.text.isNotEmpty;
    final hasAllCredentials = _ghanaCardNumberController.text.isNotEmpty &&
        _occupationController.text.isNotEmpty &&
        _dateOfBirthController.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              isDark: isDark,
              icon: Icons.child_care,
              label: 'Children',
              value: '${_children.length}',
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              isDark: isDark,
              icon: hasAllCredentials ? Icons.verified_user : Icons.pending_actions,
              label: 'Verification',
              value: hasAllCredentials ? 'Complete' : 'Pending',
              color: hasAllCredentials ? accentColor : warningColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              isDark: isDark,
              icon: Icons.credit_card,
              label: 'Ghana Card',
              value: isVerified ? 'Added' : 'Missing',
              color: isVerified ? accentColor : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    // Check if value is a number or text
    final isNumeric = int.tryParse(value) != null;
    final fontSize = isNumeric ? 24.0 : 16.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? darkCard : lightCard,
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? darkCard : lightCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: primaryColor,
            width: 3,
          ),
          insets: EdgeInsets.symmetric(horizontal: 16),
        ),
        labelColor: primaryColor,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        tabs: const [
          Tab(icon: Icon(Icons.person), text: 'Profile'),
          Tab(icon: Icon(Icons.family_restroom), text: 'Children'),
        ],
      ),
    );
  }

  Widget _buildProfileTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? darkCard : lightCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Verification Status Banner
              if (_ghanaCardNumberController.text.isEmpty ||
                  _occupationController.text.isEmpty ||
                  _dateOfBirthController.text.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: warningColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: warningColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profile Incomplete',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please provide Ghana Card details and complete all required fields',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, color: accentColor, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Verified',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'All required credentials have been provided',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_outline, color: primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                enabled: _isEditing,
                validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _dateOfBirthController,
                label: 'Date of Birth',
                icon: Icons.cake,
                enabled: _isEditing,
                keyboardType: TextInputType.datetime,
                validator: (value) => value?.isEmpty ?? true ? 'Date of birth is required' : null,
                hint: 'DD/MM/YYYY',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nationalityController,
                label: 'Nationality',
                icon: Icons.flag,
                enabled: _isEditing,
                validator: (value) => value?.isEmpty ?? true ? 'Nationality is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _occupationController,
                label: 'Occupation',
                icon: Icons.work,
                enabled: _isEditing,
                validator: (value) => value?.isEmpty ?? true ? 'Occupation is required' : null,
              ),

              // ✅ Ghana Card Section
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.credit_card, color: accentColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Ghana Card Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _ghanaCardNumberController,
                label: 'Ghana Card Number',
                icon: Icons.badge,
                enabled: _isEditing,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Ghana Card number is required';
                  if (value!.length < 10) return 'Invalid Ghana Card number';
                  return null;
                },
                hint: 'GHA-XXXXXXXXX-X',
              ),
              const SizedBox(height: 16),

              // Ghana Card Image Upload
              if (_isEditing) _buildGhanaCardUpload(),
              if (!_isEditing && _ghanaCardImage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: accentColor, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Ghana Card image uploaded',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // ✅ Contact Information Section
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.contact_phone, color: primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _phoneController,
                label: 'Primary Phone Number',
                icon: Icons.phone,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Phone is required';
                  if (value!.length < 10) return 'Invalid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _alternativePhoneController,
                label: 'Alternative Phone Number',
                icon: Icons.phone_android,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 10) {
                    return 'Invalid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email,
                enabled: _isEditing,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!value!.contains('@')) return 'Invalid email format';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emergencyContactController,
                label: 'Emergency Contact Number',
                icon: Icons.emergency,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Emergency contact is required';
                  if (value!.length < 10) return 'Invalid phone number';
                  return null;
                },
              ),

              // ✅ Address Information Section
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.location_on, color: secondaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Address Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _addressController,
                label: 'Home Address',
                icon: Icons.home,
                enabled: _isEditing,
                maxLines: 2,
                validator: (value) => value?.isEmpty ?? true ? 'Address is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _workAddressController,
                label: 'Work Address (Optional)',
                icon: Icons.business,
                enabled: _isEditing,
                maxLines: 2,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _isEditing = false);
                          _loadParentProfile();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveParentProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text('Save Changes', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildrenTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Children are managed through the dashboard. Use "Add Child" on the main screen.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_children.isEmpty)
            _buildEmptyState(
              isDark: isDark,
              icon: Icons.child_care,
              title: 'No Children Assigned',
              message: 'Go to dashboard and use "Add Child" to search and assign your children',
            )
          else
            ..._children.map((child) => _buildChildCard(child, isDark)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child, bool isDark) {
    final age = child['age'] ?? 0;
    final ageDisplay = age > 0 ? 'Age $age' : 'Age N/A';
    final classInfo = child['class'] ?? child['grade'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? darkCard : lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: const Icon(Icons.child_care, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.cake, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '$ageDisplay • $classInfo',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  child['relationship'] ?? 'Parent',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
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
                _buildInfoRow(Icons.school, 'School', child['school'] ?? 'N/A'),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.class_, 'Class', classInfo),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.meeting_room, 'Classroom', child['classRoom'] ?? 'N/A'),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.badge, 'Student ID', child['studentId'] ?? 'N/A'),
                if (child['emergencyContact'] == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emergency, color: Colors.red, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Emergency Contact',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(child['status'] ?? 'Unknown').withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getStatusColor(child['status'] ?? 'Unknown').withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: _getStatusColor(child['status'] ?? 'Unknown'),
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Status: ${child['status'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(child['status'] ?? 'Unknown'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in transit':
      case 'on bus':
        return Colors.blue;
      case 'at school':
      case 'in class':
        return accentColor;
      case 'at home':
        return warningColor;
      case 'absent':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isDark ? darkCard : lightCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGhanaCardUpload() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          if (_ghanaCardImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _ghanaCardImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() => _ghanaCardImage = File(image.path));
                    }
                  },
                  icon: Icon(Icons.photo_library, color: accentColor),
                  label: Text(
                    _ghanaCardImage != null ? 'Change Image' : 'Upload from Gallery',
                    style: TextStyle(color: accentColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: accentColor, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.camera);
                    if (image != null) {
                      setState(() => _ghanaCardImage = File(image.path));
                    }
                  },
                  icon: Icon(Icons.camera_alt, color: accentColor),
                  label: Text(
                    'Take Photo',
                    style: TextStyle(color: accentColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: accentColor, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upload a clear photo of your Ghana Card (both sides if needed)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = (timestamp as Timestamp).toDate();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();

    // ✅ Dispose new controllers
    _ghanaCardNumberController.dispose();
    _occupationController.dispose();
    _dateOfBirthController.dispose();
    _alternativePhoneController.dispose();
    _nationalityController.dispose();
    _workAddressController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}