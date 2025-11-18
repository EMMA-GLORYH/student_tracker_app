import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';


class DriverProfilePage extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String schoolId;

  const DriverProfilePage({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.schoolId,
  });

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  final PageController _pageController = PageController();
  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  int _currentStep = 0;
  bool _isTransitioning = false;

  final _ghanaCardController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  File? _profilePicture;
  File? _ghanaCardFront;
  File? _ghanaCardBack;
  File? _licenseImage;

  String? _profilePictureBase64;
  String? _ghanaCardFrontBase64;
  String? _ghanaCardBackBase64;
  String? _licenseImageBase64;

  bool _isLoading = false;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  double get _completionProgress => (_currentStep + 1) / 4;

  Color get _progressColor {
    if (_completionProgress < 0.50) {
      return Colors.red;
    } else if (_completionProgress < 0.75) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ghanaCardController.dispose();
    _licenseNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('driver_profiles')
          .doc(widget.driverId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _ghanaCardController.text = data['ghanaCardNumber'] ?? '';
        _licenseNumberController.text = data['licenseNumber'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _emergencyContactController.text = data['emergencyContact'] ?? '';
        _emergencyPhoneController.text = data['emergencyPhone'] ?? '';

        _profilePictureBase64 = data['profilePicture'];
        _ghanaCardFrontBase64 = data['ghanaCardFront'];
        _ghanaCardBackBase64 = data['ghanaCardBack'];
        _licenseImageBase64 = data['licenseImage'];
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _nextStep() async {
    if (_formKeys[_currentStep].currentState?.validate() ?? false) {
      // Special validation for step 0 (Personal Info)
      if (_currentStep == 0) {
        // Profile picture is not required, just move forward
      }

      // Special validation for step 1 (Ghana Card)
      if (_currentStep == 1) {
        if (_ghanaCardFront == null && _ghanaCardFrontBase64 == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please upload Ghana Card Front image'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        if (_ghanaCardBack == null && _ghanaCardBackBase64 == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please upload Ghana Card Back image'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Show transition loading
      setState(() => _isTransitioning = true);

      await Future.delayed(const Duration(seconds: 4));

      setState(() => _isTransitioning = false);

      if (_currentStep < 3) {
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _saveProfile();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickImage(String imageType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: imageType == 'profile' ? 512 : 1024,
        maxHeight: imageType == 'profile' ? 512 : 1024,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          switch (imageType) {
            case 'profile':
              _profilePicture = File(image.path);
              break;
            case 'ghana_front':
              _ghanaCardFront = File(image.path);
              break;
            case 'ghana_back':
              _ghanaCardBack = File(image.path);
              break;
            case 'license':
              _licenseImage = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _takePicture(String imageType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: imageType == 'profile' ? 512 : 1024,
        maxHeight: imageType == 'profile' ? 512 : 1024,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          switch (imageType) {
            case 'profile':
              _profilePicture = File(image.path);
              break;
            case 'ghana_front':
              _ghanaCardFront = File(image.path);
              break;
            case 'ghana_back':
              _ghanaCardBack = File(image.path);
              break;
            case 'license':
              _licenseImage = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog(String imageType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF1E88E5)),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePicture(imageType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF1E88E5)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(imageType);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _convertImageToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      // Convert images to base64 if new ones were selected
      String? profilePicBase64 = _profilePictureBase64;
      String? ghanaFrontBase64 = _ghanaCardFrontBase64;
      String? ghanaBackBase64 = _ghanaCardBackBase64;
      String? licenseBase64 = _licenseImageBase64;

      if (_profilePicture != null) {
        profilePicBase64 = await _convertImageToBase64(_profilePicture!);
      }

      if (_ghanaCardFront != null) {
        ghanaFrontBase64 = await _convertImageToBase64(_ghanaCardFront!);
      }

      if (_ghanaCardBack != null) {
        ghanaBackBase64 = await _convertImageToBase64(_ghanaCardBack!);
      }

      if (_licenseImage != null) {
        licenseBase64 = await _convertImageToBase64(_licenseImage!);
      }

      // Save to Firestore - Profile remains PENDING
      await FirebaseFirestore.instance
          .collection('driver_profiles')
          .doc(widget.driverId)
          .set({
        'driverId': widget.driverId,
        'driverName': widget.driverName,
        'schoolId': widget.schoolId,
        'profilePicture': profilePicBase64,
        'ghanaCardNumber': _ghanaCardController.text.trim(),
        'licenseNumber': _licenseNumberController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'ghanaCardFront': ghanaFrontBase64,
        'ghanaCardBack': ghanaBackBase64,
        'licenseImage': licenseBase64,
        'profileComplete': true,
        'verificationStatus': 'pending', // Pending admin verification
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update user status to pending verification
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.driverId)
          .update({
        'isActive': false, // Still inactive - waiting for admin
        'profileComplete': true,
        'verificationStatus': 'pending',
        'profilePicture': profilePicBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to school admin for verification
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'driver_verification_pending',
        'schoolId': widget.schoolId,
        'driverId': widget.driverId,
        'driverName': widget.driverName,
        'title': 'New Driver Profile Verification Required',
        'message': '${widget.driverName} has completed their driver profile. Please review and verify the submitted credentials.',
        'priority': 'high',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'actionRequired': true,
        'actionType': 'verify_driver',
      });

      // Also create a verification request document
      await FirebaseFirestore.instance.collection('verification_requests').add({
        'type': 'driver_profile',
        'schoolId': widget.schoolId,
        'driverId': widget.driverId,
        'driverName': widget.driverName,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'profileData': {
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'ghanaCardNumber': _ghanaCardController.text.trim(),
          'licenseNumber': _licenseNumberController.text.trim(),
          'emergencyContact': _emergencyContactController.text.trim(),
          'emergencyPhone': _emergencyPhoneController.text.trim(),
        },
      });

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: Icon(Icons.check_circle, size: 64, color: Colors.green[600]),
            title: const Text(
              'Profile Submitted Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Your driver profile has been submitted for verification. The school administrator will review your credentials and activate your account once approved.\n\nYou will receive a notification when your account is activated.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // Return to dashboard
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Complete Profile'),
          backgroundColor: const Color(0xFF1E88E5),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of 4'),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        )
            : null,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1PersonalInfo(),
                    _buildStep2GhanaCard(),
                    _buildStep3License(),
                    _buildStep4EmergencyContact(),
                  ],
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
          if (_isTransitioning) _buildTransitionOverlay(),
          if (_isSaving) _buildSavingOverlay(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _completionProgress;
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Processing...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Submitting your profile...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1PersonalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Let\'s start with your basic details',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            _buildProfilePictureSection(),
            const SizedBox(height: 32),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF1E88E5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Phone number is required';
                }
                if (value.length < 10) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _addressController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Residential Address *',
                prefixIcon: const Icon(Icons.home, color: Color(0xFF1E88E5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Address is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2GhanaCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ghana Card Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your official identification details',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _ghanaCardController,
              decoration: InputDecoration(
                labelText: 'Ghana Card Number *',
                prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF1E88E5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'GHA-XXXXXXXXX-X',
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ghana Card number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildImageUploadCard(
              title: 'Ghana Card - Front Side *',
              imageFile: _ghanaCardFront,
              imageBase64: _ghanaCardFrontBase64,
              onTap: () => _showImageSourceDialog('ghana_front'),
            ),
            const SizedBox(height: 16),
            _buildImageUploadCard(
              title: 'Ghana Card - Back Side *',
              imageFile: _ghanaCardBack,
              imageBase64: _ghanaCardBackBase64,
              onTap: () => _showImageSourceDialog('ghana_back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3License() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver\'s License',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optional but recommended',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _licenseNumberController,
              decoration: InputDecoration(
                labelText: 'License Number',
                prefixIcon: const Icon(Icons.badge, color: Color(0xFF1E88E5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 24),
            _buildImageUploadCard(
              title: 'Driver\'s License Image',
              imageFile: _licenseImage,
              imageBase64: _licenseImageBase64,
              onTap: () => _showImageSourceDialog('license'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4EmergencyContact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKeys[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Contact',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Who should we contact in case of emergency?',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emergencyContactController,
              decoration: InputDecoration(
                labelText: 'Emergency Contact Name *',
                prefixIcon: const Icon(Icons.person, color: Color(0xFF1E88E5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Emergency contact name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emergencyPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Emergency Contact Phone *',
                prefixIcon: const Icon(Icons.phone_in_talk, color: Color(0xFF1E88E5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Emergency contact phone is required';
                }
                if (value.length < 10) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your profile will be reviewed by the school administrator before activation.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    final hasProfilePic = _profilePicture != null ||
        (_profilePictureBase64 != null && _profilePictureBase64!.isNotEmpty);

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showImageSourceDialog('profile'),
            child: Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    border: Border.all(
                      color: hasProfilePic ? Colors.green : Colors.grey[400]!,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: hasProfilePic
                        ? (_profilePicture != null
                        ? Image.file(_profilePicture!, fit: BoxFit.cover)
                        : Image.memory(
                      base64Decode(_profilePictureBase64!),
                      fit: BoxFit.cover,
                    ))
                        : Icon(Icons.person, size: 70, color: Colors.grey[400]),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasProfilePic ? 'Tap to change photo' : 'Add Profile Photo',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    File? imageFile,
    String? imageBase64,
    required VoidCallback onTap,
  }) {
    final hasImage = imageFile != null || (imageBase64 != null && imageBase64.isNotEmpty);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? Colors.green : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: hasImage
            ? Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageFile != null
                  ? Image.file(imageFile, width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                  : Image.memory(base64Decode(imageBase64!), width: double.infinity, height: double.infinity, fit: BoxFit.cover),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 18),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Uploaded', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Tap to upload', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back', style: TextStyle(fontSize: 16)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep == 3 ? Colors.green : const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentStep == 3 ? 'Submit Profile' : 'Continue',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(_currentStep == 3 ? Icons.check_circle_outline : Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}