import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'device_student.dart';
import 'upload_bulk_students.dart';

class AddStudentsPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final String adminId;

  const AddStudentsPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.adminId,
  });

  @override
  State<AddStudentsPage> createState() => _AddStudentsPageState();
}

class _AddStudentsPageState extends State<AddStudentsPage> {
  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  int _currentStep = 0;
  bool _isLoading = false;
  bool _isGeneratingId = false;
  bool _isCheckingConnectivity = false;

  // Controllers
  final _studentIdController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _classController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _guardianEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _medicalInfoController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _selectedParentId;
  List<Map<String, dynamic>> _availableParents = [];

  final List<String> _stepTitles = [
    'Student Info',
    'Guardian Info',
    'Medical Info',
  ];

  @override
  void initState() {
    super.initState();
    _loadParents();
    _generateStudentId();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    _classController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianEmailController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _medicalInfoController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      try {
        await FirebaseFirestore.instance
            .collection('students')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _showConnectivityCheckAndProceed(VoidCallback onSuccess) async {
    setState(() => _isCheckingConnectivity = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    return Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 6,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF667eea),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.wifi_find,
                              size: 40,
                              color: Color(0xFF667eea).withOpacity(value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Checking Connection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF667eea),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));

    final isConnected = await _checkInternetConnection();

    if (mounted) {
      Navigator.pop(context);
      setState(() => _isCheckingConnectivity = false);

      if (isConnected) {
        onSuccess();
      } else {
        _showNoInternetDialog();
      }
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('No Internet Connection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please check your internet connection and try again.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Make sure Wi-Fi or mobile data is enabled',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (_currentStep < 2) {
                _nextStep();
              } else {
                _saveStudent();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSchoolInitials(String schoolName) {
    final words = schoolName.trim().split(' ');
    if (words.isEmpty) return 'XX';

    String initials = '';
    for (var word in words.take(2)) {
      if (word.isNotEmpty) {
        initials += word[0].toUpperCase();
      }
    }

    if (initials.length == 1) {
      initials = initials + (words[0].length > 1 ? words[0][1].toUpperCase() : 'X');
    }
    if (initials.isEmpty) {
      initials = 'XX';
    }

    return initials.substring(0, 2);
  }

  Future<void> _generateStudentId() async {
    setState(() => _isGeneratingId = true);

    try {
      final initials = _getSchoolInitials(widget.schoolName);
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('schoolId', isEqualTo: widget.schoolId)
          .get();

      int nextNumber = 1;

      if (studentsSnapshot.docs.isNotEmpty) {
        int highestNumber = 0;

        for (var doc in studentsSnapshot.docs) {
          final data = doc.data();
          final studentId = data['studentId'] as String?;

          if (studentId != null && studentId.contains('STUD')) {
            final numberPart = studentId.split('STUD').last;
            final number = int.tryParse(numberPart) ?? 0;
            if (number > highestNumber) {
              highestNumber = number;
            }
          }
        }

        nextNumber = highestNumber + 1;
      }

      final studentId = '${initials}STUD${nextNumber.toString().padLeft(4, '0')}';

      setState(() {
        _studentIdController.text = studentId;
        _isGeneratingId = false;
      });
    } catch (e) {
      debugPrint('Error generating student ID: $e');
      setState(() => _isGeneratingId = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating ID: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadParents() async {
    try {
      final parentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('roleId', isEqualTo: 'ROL0003')
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _availableParents = parentsSnapshot.docs
            .map((doc) => {
          'id': doc.id,
          'name': doc.data()['fullName'] ?? 'Unknown',
          'email': doc.data()['email'] ?? '',
          'phone': doc.data()['phone'] ?? '',
        })
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading parents: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667eea),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirthController.text =
        '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  void _nextStep() {
    if (_formKeys[_currentStep].currentState!.validate()) {
      _showConnectivityCheckAndProceed(() {
        setState(() {
          if (_currentStep < 2) {
            _currentStep++;
          }
        });
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKeys[_currentStep].currentState!.validate()) {
      return;
    }

    _showConnectivityCheckAndProceed(() async {
      setState(() => _isLoading = true);

      try {
        final studentId = _studentIdController.text.trim();
        final fullName =
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

        final existingStudent = await FirebaseFirestore.instance
            .collection('students')
            .where('studentId', isEqualTo: studentId)
            .where('schoolId', isEqualTo: widget.schoolId)
            .get();

        if (existingStudent.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Student ID already exists!'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        final studentRef =
        await FirebaseFirestore.instance.collection('students').add({
          'studentId': studentId,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'fullName': fullName,
          'dateOfBirth': _dateOfBirthController.text.trim(),
          'gender': _selectedGender,
          'bloodGroup': _selectedBloodGroup,
          'class': _classController.text.trim(),
          'address': _addressController.text.trim(),
          'guardianName': _guardianNameController.text.trim(),
          'guardianPhone': _guardianPhoneController.text.trim(),
          'guardianEmail': _guardianEmailController.text.trim(),
          'emergencyContact': _emergencyContactController.text.trim(),
          'medicalInfo': _medicalInfoController.text.trim(),
          'parentId': _selectedParentId == '' || _selectedParentId == null
              ? null
              : _selectedParentId,
          'schoolId': widget.schoolId,
          'schoolName': widget.schoolName,
          'isActive': true,
          'isOnCompound': false,
          'hasDevice': false,
          'deviceId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('studentTracking').add({
          'studentId': studentId,
          'studentDocId': studentRef.id,
          'studentName': fullName,
          'schoolId': widget.schoolId,
          'isOnCompound': false,
          'latitude': null,
          'longitude': null,
          'accuracy': null,
          'speed': null,
          'lastUpdate': null,
          'deviceId': null,
          'hasDevice': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (_selectedParentId != null &&
            _selectedParentId!.isNotEmpty &&
            _selectedParentId != '') {
          final parentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_selectedParentId)
              .get();

          if (parentDoc.exists) {
            final parentEmail = parentDoc.data()?['email'];
            if (parentEmail != null) {
              await FirebaseFirestore.instance.collection('mail').add({
                'to': [parentEmail],
                'message': {
                  'subject': 'Student Added to School System',
                  'html': '''
                    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                      <h2 style="color: #667eea;">Student Registration Successful</h2>
                      <p>Hello ${parentDoc.data()?['fullName']},</p>
                      <p>Your child <strong>$fullName</strong> (ID: $studentId) has been successfully added to the ${widget.schoolName} tracking system.</p>
                      <p>You can now track your child's location and receive updates through the parent portal.</p>
                      <br>
                      <p>Best regards,<br>${widget.schoolName}</p>
                    </div>
                  ''',
                },
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        if (mounted) {
          setState(() => _isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student added successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceStudentPage(
                schoolId: widget.schoolId,
                schoolName: widget.schoolName,
                adminId: widget.adminId,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _navigateToBulkUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadBulkStudentsPage(
          schoolId: widget.schoolId,
          schoolName: widget.schoolName,
          adminId: widget.adminId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Add New Student'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Bulk Upload Students',
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: _navigateToBulkUpload,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: Form(
              key: _formKeys[_currentStep],
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Bulk Upload Suggestion Card
                  if (_currentStep == 0) _buildBulkUploadSuggestion(),
                  _buildStepContent(),
                  const SizedBox(height: 32),
                  _buildNavigationButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkUploadSuggestion() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.1),
            const Color(0xFF764ba2).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_upload,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need to add multiple students?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use bulk upload for faster registration',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _navigateToBulkUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Bulk Upload'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(_stepTitles.length, (index) {
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: index <= _currentStep
                                  ? const Color(0xFF667eea)
                                  : Colors.grey[300],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: index == _currentStep
                                    ? const Color(0xFF667eea)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: index < _currentStep
                                  ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                                  : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: index <= _currentStep
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _stepTitles[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: index == _currentStep
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: index <= _currentStep
                                  ? const Color(0xFF667eea)
                                  : Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (index < _stepTitles.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 28),
                          color: index < _currentStep
                              ? const Color(0xFF667eea)
                              : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _stepTitles.length,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF667eea),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStudentInfoStep();
      case 1:
        return _buildGuardianInfoStep();
      case 2:
        return _buildMedicalInfoStep();
      default:
        return Container();
    }
  }

  Widget _buildStudentInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Student Information', Icons.person),
        const SizedBox(height: 20),
        _buildInfoCard([
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _studentIdController,
                  label: 'Student ID',
                  hint: 'Auto-generated ID',
                  icon: Icons.badge,
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Student ID is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                  ),
                ),
                child: IconButton(
                  onPressed: _isGeneratingId ? null : _generateStudentId,
                  icon: _isGeneratingId
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF667eea),
                    ),
                  )
                      : const Icon(
                    Icons.refresh,
                    color: Color(0xFF667eea),
                  ),
                  tooltip: 'Generate new ID',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _firstNameController,
            label: 'First Name',
            hint: 'Enter first name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _lastNameController,
            label: 'Last Name',
            hint: 'Enter last name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildDateField(),
          const SizedBox(height: 20),
          _buildDropdown(
            label: 'Gender',
            value: _selectedGender,
            items: ['Male', 'Female'],
            onChanged: (value) {
              setState(() => _selectedGender = value);
            },
            icon: Icons.wc,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _classController,
            label: 'Class',
            hint: 'e.g., Grade 5A',
            icon: Icons.class_,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildDropdown(
            label: 'Blood Group',
            value: _selectedBloodGroup,
            items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
            onChanged: (value) {
              setState(() => _selectedBloodGroup = value);
            },
            icon: Icons.bloodtype,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _addressController,
            label: 'Home Address',
            hint: 'Enter complete address',
            icon: Icons.home,
            maxLines: 2,
          ),
        ]),
      ],
    );
  }

  Widget _buildGuardianInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Guardian Information', Icons.family_restroom),
        const SizedBox(height: 20),
        _buildInfoCard([
          _buildParentSelector(),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _guardianNameController,
            label: 'Guardian Name',
            hint: 'Enter guardian full name',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter guardian name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _guardianPhoneController,
            label: 'Guardian Phone',
            hint: 'Phone number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _emergencyContactController,
            label: 'Emergency Contact',
            hint: 'Alternative phone',
            icon: Icons.emergency,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _guardianEmailController,
            label: 'Guardian Email (Optional)',
            hint: 'Enter email address',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
        ]),
      ],
    );
  }

  Widget _buildMedicalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Medical Information', Icons.medical_services),
        const SizedBox(height: 20),
        _buildInfoCard([
          _buildTextField(
            controller: _medicalInfoController,
            label: 'Medical Conditions / Allergies (Optional)',
            hint: 'Enter any medical conditions or allergies',
            icon: Icons.health_and_safety,
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This information helps us provide better care and respond appropriately in emergencies.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF667eea)),
                foregroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 16),
        Expanded(
          flex: _currentStep == 0 ? 1 : 1,
          child: ElevatedButton.icon(
            onPressed: (_isLoading || _isCheckingConnectivity)
                ? null
                : (_currentStep < 2 ? _nextStep : _saveStudent),
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Icon(_currentStep < 2 ? Icons.arrow_forward : Icons.save),
            label: Text(
              _isLoading
                  ? 'Saving...'
                  : _currentStep < 2
                  ? 'Next'
                  : 'Add Student',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF667eea), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
      ),
      validator: validator,
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateOfBirthController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Date of Birth',
        hintText: 'Select date',
        prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF667eea)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
      ),
      onTap: () => _selectDate(context),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select';
        }
        return null;
      },
    );
  }

  Widget _buildParentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Link to Parent Account (Optional)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedParentId ?? '',
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'Select parent from registered users',
            prefixIcon: const Icon(Icons.person_add, color: Color(0xFF667eea)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('No parent selected'),
            ),
            ..._availableParents.map((parent) {
              return DropdownMenuItem<String>(
                value: parent['id'] as String,
                child: Text(
                  parent['name'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() => _selectedParentId = value == '' ? null : value);
          },
          selectedItemBuilder: (BuildContext context) {
            return [
              const Text('No parent selected'),
              ..._availableParents.map((parent) {
                return Text(
                  parent['name'],
                  overflow: TextOverflow.ellipsis,
                );
              }).toList(),
            ];
          },
        ),
        if (_selectedParentId != null &&
            _selectedParentId!.isNotEmpty &&
            _selectedParentId != '')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF667eea).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _availableParents.firstWhere(
                            (p) => p['id'] == _selectedParentId)['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.email,
                          size: 14, color: Color(0xFF667eea)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _availableParents.firstWhere(
                                  (p) => p['id'] == _selectedParentId)['email'],
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone,
                          size: 14, color: Color(0xFF667eea)),
                      const SizedBox(width: 6),
                      Text(
                        _availableParents.firstWhere(
                                (p) => p['id'] == _selectedParentId)['phone'],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}