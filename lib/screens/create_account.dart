import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:find_me/services/firestore_roles_initializer.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';

/// SECURE Create Account Screen with Firebase Authentication
/// Enhanced with professional features and dark blue theme matching login
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with TickerProviderStateMixin {
  // Constants
  static const int totalSteps = 6;
  static const int otpLength = 6;
  static const Duration otpValidityDuration = Duration(minutes: 10);
  static const Duration networkTimeout = Duration(seconds: 15);
  static const int maxOTPAttempts = 3;
  static const Duration otpResendCooldown = Duration(seconds: 30);

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  int _currentStep = 0;
  String? registrationType;
  String? _generatedOTP;
  DateTime? _otpGeneratedTime;
  int _otpAttempts = 0;
  DateTime? _lastOtpResendTime;
  bool _canResendOTP = true;
  Timer? _resendTimer;
  int _resendCountdown = 0;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreRolesInitializer _rolesInitializer = FirestoreRolesInitializer();

  // School registration controllers
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _schoolAddressController = TextEditingController();
  final TextEditingController _schoolEmailController = TextEditingController();
  final TextEditingController _schoolPhoneController = TextEditingController();
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPhoneController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();
  final TextEditingController _adminConfirmPasswordController = TextEditingController();

  // User registration controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // Form Keys for validation
  final GlobalKey<FormState> _schoolInfoFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _adminAccountFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _personalDetailsFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  // User registration data
  List<Map<String, dynamic>> availableRoles = [];
  String? selectedUserRole;
  String? selectedRoleId;
  String? selectedSchoolId;
  String? selectedSchoolName;
  List<Map<String, dynamic>> approvedSchools = [];
  Map<String, dynamic>? selectedRolePermissions;

  // UI state flags
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isLoadingSchools = false;
  bool _isLoadingRoles = false;
  bool _agreedToTerms = false;
  bool _subscribedToNewsletter = false;

  // ✅ Enhanced validation state
  Map<String, String?> _fieldErrors = {};
  String? _generalError;
  bool _hasAttemptedNext = false; // Track if user has tried to proceed

  // Password strength indicator
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  // Session data for analytics
  final DateTime _sessionStartTime = DateTime.now();
  final Map<String, dynamic> _analyticsData = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAvailableRoles();
    _trackSessionStart();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _resendTimer?.cancel();

    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _schoolEmailController.dispose();
    _schoolPhoneController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _adminPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();

    _trackSessionEnd();
    super.dispose();
  }

  // ============================================================================
  // ENHANCED VALIDATION METHODS
  // ============================================================================

  void _clearAllErrors() {
    setState(() {
      _fieldErrors.clear();
      _generalError = null;
    });
  }

  void _setFieldError(String fieldName, String? error) {
    setState(() {
      if (error == null) {
        _fieldErrors.remove(fieldName);
      } else {
        _fieldErrors[fieldName] = error;
      }
    });
  }

  void _setGeneralError(String? error) {
    setState(() {
      _generalError = error;
    });
  }

  // ✅ NEW: Check if field is required and empty (for visual feedback)
  bool _isFieldRequired(String fieldKey) {
    if (!_hasAttemptedNext) return false;

    final requiredFields = _getRequiredFieldsForCurrentStep();
    return requiredFields.contains(fieldKey);
  }

  // ✅ NEW: Get required fields for current step
  List<String> _getRequiredFieldsForCurrentStep() {
    switch (_currentStep) {
      case 1:
        if (registrationType == 'school') {
          return ['schoolName', 'schoolAddress', 'schoolEmail', 'schoolPhone'];
        } else {
          return []; // Role selection is handled differently
        }
      case 2:
        if (registrationType == 'school') {
          return ['adminName', 'adminEmail', 'adminPhone'];
        } else {
          return []; // School selection is handled differently
        }
      case 3:
        if (registrationType == 'school') {
          return ['password', 'confirmPassword'];
        } else {
          return ['fullName', 'email', 'phone'];
        }
      case 4:
        if (registrationType == 'user') {
          return ['password', 'confirmPassword'];
        }
        return [];
      case 5:
        return ['otp'];
      default:
        return [];
    }
  }

  // ✅ NEW: Check if field is empty and should show red
  bool _shouldShowFieldAsRequired(String fieldKey, String value) {
    return _isFieldRequired(fieldKey) && value.trim().isEmpty;
  }

  // ✅ Enhanced validation with visual feedback
  bool _validateCurrentStep() {
    _clearAllErrors();
    bool isValid = true;

    if (_currentStep == 0) {
      if (registrationType == null) {
        _setGeneralError('Please select a registration type to continue.');
        return false;
      }
      return true;
    }

    if (_currentStep == 1) {
      if (registrationType == 'school') {
        isValid = _validateSchoolInfoStrict();
      } else {
        if (selectedRoleId == null) {
          _setGeneralError('Please select your role to continue.');
          return false;
        }
      }
    }

    if (_currentStep == 2) {
      if (registrationType == 'school') {
        isValid = _validateAdminAccountStrict();
      } else {
        if (selectedSchoolId == null) {
          _setGeneralError('Please select your school to continue.');
          return false;
        }
      }
    }

    if (_currentStep == 3) {
      if (registrationType == 'school') {
        isValid = _validatePasswordFieldsStrict(_adminPasswordController, _adminConfirmPasswordController);
      } else {
        isValid = _validatePersonalDetailsStrict();
      }
    }

    if (_currentStep == 4) {
      if (registrationType == 'user') {
        isValid = _validatePasswordFieldsStrict(_passwordController, _confirmPasswordController);
      }

      if (!_agreedToTerms) {
        _setGeneralError('Please agree to the terms and conditions to continue.');
        isValid = false;
      }
    }

    if (_currentStep == 5) {
      if (_otpController.text.trim().length != otpLength) {
        _setFieldError('otp', 'Please enter a valid 6-digit OTP');
        _setGeneralError('Please enter a valid 6-digit OTP to complete registration.');
        return false;
      }
    }

    return isValid;
  }

  // ✅ Strict validation methods with required field checking
  bool _validateSchoolInfoStrict() {
    bool isValid = true;

    if (_schoolNameController.text.trim().isEmpty) {
      _setFieldError('schoolName', 'School name is required');
      isValid = false;
    }

    if (_schoolAddressController.text.trim().isEmpty) {
      _setFieldError('schoolAddress', 'School address is required');
      isValid = false;
    }

    if (_schoolEmailController.text.trim().isEmpty) {
      _setFieldError('schoolEmail', 'School email is required');
      isValid = false;
    } else if (!_isValidEmail(_schoolEmailController.text.trim())) {
      _setFieldError('schoolEmail', 'Please enter a valid email address');
      isValid = false;
    }

    if (_schoolPhoneController.text.trim().isEmpty) {
      _setFieldError('schoolPhone', 'School phone is required');
      isValid = false;
    } else if (!_isValidPhone(_schoolPhoneController.text.trim())) {
      _setFieldError('schoolPhone', 'Please enter a valid phone number');
      isValid = false;
    }

    if (!isValid) {
      _setGeneralError('Please fill in all required fields to continue.');
    }

    return isValid;
  }

  bool _validateAdminAccountStrict() {
    bool isValid = true;

    if (_adminNameController.text.trim().isEmpty) {
      _setFieldError('adminName', 'Administrator name is required');
      isValid = false;
    }

    if (_adminEmailController.text.trim().isEmpty) {
      _setFieldError('adminEmail', 'Administrator email is required');
      isValid = false;
    } else if (!_isValidEmail(_adminEmailController.text.trim())) {
      _setFieldError('adminEmail', 'Please enter a valid email address');
      isValid = false;
    }

    if (_adminPhoneController.text.trim().isEmpty) {
      _setFieldError('adminPhone', 'Administrator phone is required');
      isValid = false;
    } else if (!_isValidPhone(_adminPhoneController.text.trim())) {
      _setFieldError('adminPhone', 'Please enter a valid phone number');
      isValid = false;
    }

    if (!isValid) {
      _setGeneralError('Please fill in all required fields to continue.');
    }

    return isValid;
  }

  bool _validatePersonalDetailsStrict() {
    bool isValid = true;

    if (_nameController.text.trim().isEmpty) {
      _setFieldError('fullName', 'Full name is required');
      isValid = false;
    }

    if (_emailController.text.trim().isEmpty) {
      _setFieldError('email', 'Email is required');
      isValid = false;
    } else if (!_isValidEmail(_emailController.text.trim())) {
      _setFieldError('email', 'Please enter a valid email address');
      isValid = false;
    }

    if (_phoneController.text.trim().isEmpty) {
      _setFieldError('phone', 'Phone number is required');
      isValid = false;
    } else if (!_isValidPhone(_phoneController.text.trim())) {
      _setFieldError('phone', 'Please enter a valid phone number');
      isValid = false;
    }

    if (!isValid) {
      _setGeneralError('Please fill in all required fields to continue.');
    }

    return isValid;
  }

  bool _validatePasswordFieldsStrict(
      TextEditingController passwordController,
      TextEditingController confirmController
      ) {
    bool isValid = true;

    if (passwordController.text.isEmpty) {
      _setFieldError('password', 'Password is required');
      isValid = false;
    } else {
      final validation = _validatePasswordStrength(passwordController.text);
      if (validation != null) {
        _setFieldError('password', validation);
        isValid = false;
      } else if (_passwordStrength < 0.5) {
        _setFieldError('password', 'Please create a stronger password for better security');
        isValid = false;
      }
    }

    if (confirmController.text.isEmpty) {
      _setFieldError('confirmPassword', 'Please confirm your password');
      isValid = false;
    } else if (passwordController.text != confirmController.text) {
      _setFieldError('confirmPassword', 'Passwords do not match');
      isValid = false;
    }

    if (!isValid) {
      _setGeneralError('Please fill in all required fields and ensure passwords match.');
    }

    return isValid;
  }

  // ============================================================================
  // INITIALIZATION METHODS
  // ============================================================================

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadAvailableRoles() async {
    setState(() => _isLoadingRoles = true);

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final QuerySnapshot rolesSnapshot = await _firestore
            .collection('roles')
            .where('isActive', isEqualTo: true)
            .orderBy('level')
            .get()
            .timeout(const Duration(seconds: 10));

        final List<Map<String, dynamic>> loadedRoles = [];

        for (var doc in rolesSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;

          final roleMap = {
            'roleId': doc.id,
            'name': data['name'] ?? 'Unknown Role',
            'description': data['description'] ?? '',
            'level': data['level'] ?? 0,
            'canManageUsers': data['canManageUsers'] ?? false,
            'canManageSchool': data['canManageSchool'] ?? false,
            'canManageRoutes': data['canManageRoutes'] ?? false,
            'canViewReports': data['canViewReports'] ?? false,
            'permissions': data['permissions'] ?? {},
            'icon': _getRoleIcon(doc.id),
            'color': _getRoleColor(doc.id),
          };

          loadedRoles.add(roleMap);
        }

        setState(() {
          availableRoles = loadedRoles.where((role) {
            final roleId = role['roleId'] as String;
            return roleId != 'ROL0001' && roleId != 'ROL0006';
          }).toList();
          _isLoadingRoles = false;
        });

        debugPrint('✅ Successfully loaded ${availableRoles.length} roles');
        break;

      } on FirebaseException catch (e) {
        retryCount++;
        debugPrint('❌ Firebase error (attempt $retryCount): ${e.code} - ${e.message}');

        if (e.code == 'permission-denied') {
          debugPrint('⚠️ Permission denied - using fallback roles');
          setState(() => _isLoadingRoles = false);
          _setFallbackRoles();

          if (mounted) {
            _showSnackBar(
              'Loading roles from cache. Some features may be limited.',
              isError: false,
            );
          }
          break;
        }

        if (retryCount >= maxRetries) {
          setState(() => _isLoadingRoles = false);
          _setFallbackRoles();

          if (mounted) {
            _showSnackBar(
              'Unable to load roles. Using offline data.',
              isError: true,
            );
          }
        } else {
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      } catch (e) {
        retryCount++;
        debugPrint('❌ Attempt $retryCount failed loading roles: $e');

        if (retryCount >= maxRetries) {
          setState(() => _isLoadingRoles = false);
          _setFallbackRoles();

          if (mounted) {
            _showSnackBar(
              'Using offline role data. Some features may be limited.',
              isError: true,
            );
          }
        } else {
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    }
  }

  IconData _getRoleIcon(String roleId) {
    switch (roleId) {
      case 'ROL0001':
        return Icons.admin_panel_settings;
      case 'ROL0002':
        return Icons.school;
      case 'ROL0003':
        return Icons.family_restroom;
      case 'ROL0004':
        return Icons.security;
      case 'ROL0005':
        return Icons.directions_bus;
      case 'ROL0006':
        return Icons.business;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String roleId) {
    switch (roleId) {
      case 'ROL0001':
        return Colors.red;
      case 'ROL0002':
        return const Color(0xFF0A1929);
      case 'ROL0003':
        return Colors.green;
      case 'ROL0004':
        return Colors.orange;
      case 'ROL0005':
        return Colors.purple;
      case 'ROL0006':
        return Colors.indigo;
      default:
        return const Color(0xFF0A1929);
    }
  }

  void _setFallbackRoles() {
    setState(() {
      availableRoles = [
        {
          'roleId': 'ROL0002',
          'name': 'Teacher',
          'description': 'Manage classes, take attendance, and track students',
          'level': 3,
          'icon': Icons.school,
          'color': const Color(0xFF0A1929),
          'canManageUsers': false,
          'canManageSchool': false,
          'canManageRoutes': false,
          'canViewReports': true,
        },
        {
          'roleId': 'ROL0003',
          'name': 'Parent',
          'description': 'Track your child\'s location, attendance, and receive notifications',
          'level': 4,
          'icon': Icons.family_restroom,
          'color': Colors.green,
          'canManageUsers': false,
          'canManageSchool': false,
          'canManageRoutes': false,
          'canViewReports': false,
        },
        {
          'roleId': 'ROL0004',
          'name': 'Security Personnel',
          'description': 'Monitor school premises and manage entry/exit points',
          'level': 5,
          'icon': Icons.security,
          'color': Colors.orange,
          'canManageUsers': false,
          'canManageSchool': false,
          'canManageRoutes': false,
          'canViewReports': false,
        },
        {
          'roleId': 'ROL0005',
          'name': 'Driver',
          'description': 'Manage bus routes and student transportation',
          'level': 5,
          'icon': Icons.directions_bus,
          'color': Colors.purple,
          'canManageUsers': false,
          'canManageSchool': false,
          'canManageRoutes': true,
          'canViewReports': false,
        },
      ];
    });
  }

  // ============================================================================
// ENHANCED SCHOOL LOADING WITH BETTER ERROR HANDLING
// ============================================================================

  Future<void> _loadApprovedSchools() async {
    if (!mounted) return;

    setState(() {
      _isLoadingSchools = true;
      _generalError = null;
    });

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        debugPrint('🔍 Loading approved schools (attempt ${retryCount + 1})...');

        final snapshot = await _firestore
            .collection('schools')
            .where('verified', isEqualTo: true)
            .where('isActive', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 15));

        debugPrint('✅ Retrieved ${snapshot.docs.length} school documents');

        final schoolsList = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['schoolName'] ?? 'Unknown',
            'address': data['address'] ?? '',
            'email': data['contactEmail'] ?? '',
            'phone': data['contactPhone'] ?? '',
            'logoUrl': data['logoUrl'] ?? '',
            'studentCount': data['studentCount'] ?? 0,
            'district': data['district'] ?? '',
            'region': data['region'] ?? '',
          };
        }).toList();

        // Sort alphabetically
        schoolsList.sort((a, b) =>
            (a['name'] as String).compareTo(b['name'] as String)
        );

        if (mounted) {
          setState(() {
            approvedSchools = schoolsList;
            _isLoadingSchools = false;
          });

          debugPrint('✅ Successfully loaded ${approvedSchools.length} approved schools');

          if (approvedSchools.isEmpty) {
            _setGeneralError('No approved schools found. Please contact support for assistance.');
            _showSnackBar('No approved schools available yet.', isError: true);
          } else {
            _showSnackBar('✓ Loaded ${approvedSchools.length} schools', isSuccess: true);
          }
        }

        break; // Success, exit retry loop

      } on FirebaseException catch (e) {
        retryCount++;
        debugPrint('❌ Firebase error (attempt $retryCount): ${e.code} - ${e.message}');

        if (e.code == 'permission-denied') {
          // Permission error - check security rules
          if (mounted) {
            setState(() => _isLoadingSchools = false);
            _setGeneralError('Unable to load schools. Please check Firebase security rules.');
            _showSnackBar('Permission denied: Check Firestore security rules', isError: true);
          }
          break;
        } else if (e.code == 'failed-precondition') {
          // Missing index
          if (mounted) {
            setState(() => _isLoadingSchools = false);
            _setGeneralError('Database configuration error. Please contact support.');
            _showSnackBar('Missing Firestore index. Check console for index creation link.', isError: true);
          }
          break;
        }

        if (retryCount >= maxRetries) {
          if (mounted) {
            setState(() => _isLoadingSchools = false);
            _setGeneralError('Failed to load schools after multiple attempts. Please try again later.');
            _showSnackBar('Unable to load schools. Please try again.', isError: true);
          }
        } else {
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(seconds: retryCount * 2));
        }

      } catch (e) {
        retryCount++;
        debugPrint('❌ Unexpected error (attempt $retryCount): $e');

        if (retryCount >= maxRetries) {
          if (mounted) {
            setState(() => _isLoadingSchools = false);

            if (_isNetworkError(e)) {
              _setGeneralError('Unable to load schools. Please check your internet connection and try again.');
              _showSnackBar('No internet connection', isError: true);
            } else {
              _setGeneralError('An unexpected error occurred. Please try again or contact support.');
              _showSnackBar('Failed to load schools', isError: true);
            }
          }
        } else {
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    }
  }

// ============================================================================
// ENHANCED SCHOOL SELECTION UI WITH SEARCH
// ============================================================================

// Add these state variables at the top with other state variables (around line 90)
  final TextEditingController _schoolSearchController = TextEditingController();
  String _schoolSearchQuery = '';
  bool _showSchoolSearch = false;


// Replace the existing _buildSchoo.lSelection method with this enhanced version:
  Widget _buildSchoolSelection(bool isDark) {
    // Filter schools based on search query
    final filteredSchools = _schoolSearchQuery.isEmpty
        ? approvedSchools
        : approvedSchools.where((school) {
      final name = (school['name'] as String).toLowerCase();
      final address = (school['address'] as String).toLowerCase();
      final district = (school['district'] as String? ?? '').toLowerCase();
      final region = (school['region'] as String? ?? '').toLowerCase();
      final query = _schoolSearchQuery.toLowerCase();

      return name.contains(query) ||
          address.contains(query) ||
          district.contains(query) ||
          region.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Your School',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose the school you are affiliated with',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (_isLoadingSchools)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // ✅ LOADING STATE
        if (_isLoadingSchools)
          Container(
            padding: const EdgeInsets.all(32),
            child: const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF0A1929),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading schools...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )

        // ✅ EMPTY STATE
        else if (approvedSchools.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[300]!, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Approved Schools Found',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your school needs to be registered and approved first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadApprovedSchools,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          )

        // ✅ SCHOOL SELECTION WITH SEARCH
        else ...[
            // Search Toggle Button
            if (approvedSchools.length > 5)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showSchoolSearch = !_showSchoolSearch;
                      if (!_showSchoolSearch) {
                        _schoolSearchController.clear();
                        _schoolSearchQuery = '';
                      }
                    });
                  },
                  icon: Icon(
                    _showSchoolSearch ? Icons.close : Icons.search,
                    size: 18,
                  ),
                  label: Text(
                    _showSchoolSearch ? 'Hide Search' : 'Search Schools',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A1929),
                    side: const BorderSide(
                      color: Color(0xFF0A1929),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),

            // Search Field
            if (_showSchoolSearch || approvedSchools.length > 10) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: _schoolSearchController,
                  onChanged: (value) {
                    setState(() => _schoolSearchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by school name, address, or region...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF0A1929),
                    ),
                    suffixIcon: _schoolSearchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _schoolSearchController.clear();
                        setState(() => _schoolSearchQuery = '');
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0A1929),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[400]!,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0A1929),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Search Results Count
              if (_schoolSearchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${filteredSchools.length} school${filteredSchools.length == 1 ? '' : 's'} found',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],

            // No Results from Search
            if (filteredSchools.isEmpty && _schoolSearchQuery.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No schools match "$_schoolSearchQuery"',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try a different search term or clear the search',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )

            // School Dropdown (Compact) - For 5 or fewer schools
            else if (!_showSchoolSearch && approvedSchools.length <= 5)
              DropdownButtonFormField<String>(
                value: selectedSchoolId,
                decoration: InputDecoration(
                  hintText: 'Choose your school',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.school,
                    color: Color(0xFF0A1929),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0A1929),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0A1929),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: filteredSchools.map<DropdownMenuItem<String>>((school) {
                  return DropdownMenuItem<String>(
                    value: school['id'] as String,
                    child: Text(
                      school['name'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    final school = approvedSchools.firstWhere((s) => s['id'] == value);
                    setState(() {
                      selectedSchoolId = value;
                      selectedSchoolName = school['name'] as String;
                    });
                    HapticFeedback.lightImpact();
                  }
                },
              )

            // School List (Scrollable Cards) - For many schools or when searching
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredSchools.length,
                  itemBuilder: (context, index) {
                    final school = filteredSchools[index];
                    final schoolId = school['id'] as String;
                    final schoolName = school['name'] as String;
                    final schoolAddress = school['address'] as String;
                    final isSelected = selectedSchoolId == schoolId;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedSchoolId = schoolId;
                            selectedSchoolName = schoolName;
                          });
                          HapticFeedback.lightImpact();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0A1929).withOpacity(0.05)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0A1929).withOpacity(0.1)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.school,
                                  color: isSelected
                                      ? const Color(0xFF0A1929)
                                      : Colors.grey[600],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      schoolName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFF0A1929)
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (schoolAddress.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        schoolAddress,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? const Color(0xFF0A1929)
                                      : Colors.grey[400],
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ✅ SELECTED SCHOOL DETAILS
            if (selectedSchoolId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0A1929).withOpacity(0.05),
                      const Color(0xFF1A2F3F).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0A1929).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF10b981),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Selected School',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A1929),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.school,
                          size: 16,
                          color: Color(0xFF0A1929),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            approvedSchools.firstWhere(
                                  (s) => s['id'] == selectedSchoolId,
                            )['name'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A1929),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            approvedSchools.firstWhere(
                                  (s) => s['id'] == selectedSchoolId,
                            )['address'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
      ],
    );
  }

  void _calculatePasswordStrength(String password) {
    double strength = 0.0;
    String strengthText = '';
    Color strengthColor = Colors.grey;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.1;
    if (password.length >= 16) strength += 0.1;

    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.1;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.15;

    if (strength <= 0.3) {
      strengthText = 'Weak';
      strengthColor = Colors.red;
    } else if (strength <= 0.5) {
      strengthText = 'Fair';
      strengthColor = Colors.orange;
    } else if (strength <= 0.7) {
      strengthText = 'Good';
      strengthColor = Colors.yellow[700]!;
    } else if (strength <= 0.9) {
      strengthText = 'Strong';
      strengthColor = Colors.lightGreen;
    } else {
      strengthText = 'Very Strong';
      strengthColor = Colors.green;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthText = strengthText;
      _passwordStrengthColor = strengthColor;
    });
  }

  // ============================================================================
  // VALIDATION METHODS
  // ============================================================================

  String? _validatePasswordStrength(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.length >= 10 && cleaned.length <= 15;
  }

  bool _isOTPExpired() {
    if (_otpGeneratedTime == null) return true;
    final now = DateTime.now();
    final difference = now.difference(_otpGeneratedTime!);
    return difference > otpValidityDuration;
  }

  // ============================================================================
  // NETWORK & EXISTENCE CHECK METHODS
  // ============================================================================

  Future<bool> _checkNetworkConnection() async {
    try {
      await _firestore
          .collection('_healthCheck')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('❌ Network check failed: $e');
      if (mounted) {
        _showSnackBar('No internet connection. Please check your network.',
            isError: true);
      }
      return false;
    }
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking email: $e');
      return false;
    }
  }

  Future<bool> _checkPhoneExists(String phone) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking phone: $e');
      return false;
    }
  }

  Future<bool> _checkSchoolExists(String schoolName) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .where('schoolName', isEqualTo: schoolName.trim())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking school: $e');
      return false;
    }
  }

  Future<bool> _checkSchoolEmailExists(String email) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .where('contactEmail', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking school email: $e');
      return false;
    }
  }

  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('failed host lookup') ||
        errorString.contains('network') ||
        errorString.contains('timeout');
  }

  // ============================================================================
  // COUNTER & ID GENERATION
  // ============================================================================

  Future<String> _getNextCounterId(String entity) async {
    try {
      final counterRef = _firestore.collection('counters').doc('systemCounters');

      return await _firestore.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);
        int nextId;

        if (!counterDoc.exists) {
          nextId = 1;
          transaction.set(counterRef, {entity: nextId});
        } else {
          nextId = (counterDoc.data()?[entity] ?? 0) + 1;
          transaction.update(counterRef, {entity: nextId});
        }

        return nextId.toString().padLeft(4, '0');
      }).timeout(networkTimeout);
    } catch (e) {
      debugPrint('❌ Error getting counter: $e');
      return DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    }
  }

  // ============================================================================
  // OTP METHODS
  // ============================================================================

  String _generateOTP() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _generateAndSendOTP() async {
    if (!_canResendOTP) {
      _showSnackBar('Please wait $_resendCountdown seconds before requesting a new code.');
      return;
    }

    final otpCode = _generateOTP();
    _generatedOTP = otpCode;
    _otpGeneratedTime = DateTime.now();
    _otpAttempts = 0;

    final email = registrationType == 'school'
        ? _adminEmailController.text.trim()
        : _emailController.text.trim();
    final phone = registrationType == 'school'
        ? _adminPhoneController.text.trim()
        : _phoneController.text.trim();
    final name = registrationType == 'school'
        ? _adminNameController.text.trim()
        : _nameController.text.trim();

    await Future.wait([
      _sendEmailNotification(email, name, otpCode),
      _sendSMSNotification(phone, name, otpCode),
      _storeOTPForTesting(email, otpCode),
    ]);

    _startResendCooldown();

    debugPrint('========================================');
    debugPrint('🔐 OTP GENERATED: $otpCode');
    debugPrint('📧 For: $email');
    debugPrint('⏰ Valid until: ${DateTime.now().add(otpValidityDuration)}');
    debugPrint('========================================');

    _showSnackBar('Verification code sent to your email and phone!', isSuccess: true);
  }

  void _startResendCooldown() {
    setState(() {
      _canResendOTP = false;
      _resendCountdown = 30;
    });

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        setState(() => _canResendOTP = true);
        timer.cancel();
      }
    });
  }

  Future<void> _sendEmailNotification(String email, String name, String otpCode) async {
    try {
      await _firestore.collection('mail').add({
        'to': [email.toLowerCase().trim()],
        'message': {
          'subject': 'S3TS Account Registration - Verification Code',
          'html': _buildEmailTemplate(name, otpCode),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      }).timeout(const Duration(seconds: 10));

      debugPrint('✅ Email queued for: $email');
    } catch (e) {
      debugPrint('❌ Error sending email: $e');
    }
  }

  String _buildEmailTemplate(String name, String otpCode) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
      </head>
      <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
        <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff;">
          <div style="background: linear-gradient(135deg, #0A1929 0%, #1A2F3F 100%); padding: 30px; text-align: center;">
            <h1 style="color: #ffffff; margin: 0; font-size: 28px;">S3TS</h1>
            <p style="color: #ffffff; margin: 10px 0 0 0; font-size: 14px;">School Safety & Security Tracking System</p>
          </div>
          
          <div style="padding: 40px 30px;">
            <h2 style="color: #333333; margin: 0 0 20px 0; font-size: 24px;">Welcome, $name!</h2>
            
            <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
              Thank you for registering with S3TS. To complete your registration, please use the verification code below:
            </p>
            
            <div style="background-color: #f8f9fa; padding: 30px; text-align: center; border-radius: 10px; margin: 30px 0;">
              <div style="font-size: 36px; font-weight: bold; letter-spacing: 10px; color: #0A1929; font-family: 'Courier New', monospace;">
                $otpCode
              </div>
            </div>
            
            <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="margin: 0; color: #856404; font-size: 14px;">
                <strong>⚠️ Important:</strong> This code will expire in 10 minutes.
              </p>
            </div>
            
            <p style="color: #666666; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
              If you didn't request this code, please ignore this email or contact our support team if you have concerns.
            </p>
          </div>
          
          <div style="background-color: #f8f9fa; padding: 20px 30px; border-top: 1px solid #e9ecef;">
            <p style="margin: 0; color: #999999; font-size: 12px; text-align: center;">
              © 2024 S3TS. All rights reserved.<br>
              This is an automated message, please do not reply.
            </p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  Future<void> _sendSMSNotification(String phone, String name, String otpCode) async {
    try {
      await _firestore.collection('sms').add({
        'to': phone.trim(),
        'message': 'Hello $name, your S3TS verification code is: $otpCode. Valid for 10 minutes. Do not share this code.',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      }).timeout(const Duration(seconds: 10));

      debugPrint('✅ SMS queued for: $phone');
    } catch (e) {
      debugPrint('❌ Error sending SMS: $e');
    }
  }

  Future<void> _storeOTPForTesting(String email, String otpCode) async {
    try {
      await _firestore.collection('otpCodes').add({
        'email': email.toLowerCase().trim(),
        'code': otpCode,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(otpValidityDuration)),
        'used': false,
      }).timeout(const Duration(seconds: 10));

      debugPrint('✅ OTP stored for testing: $otpCode');
    } catch (e) {
      debugPrint('❌ Error storing OTP: $e');
    }
  }

  // ============================================================================
  // ANALYTICS METHODS
  // ============================================================================

  void _trackSessionStart() {
    _analyticsData['sessionStart'] = DateTime.now();
    _analyticsData['device'] = defaultTargetPlatform.name;
  }

  void _trackSessionEnd() {
    final duration = DateTime.now().difference(_sessionStartTime);
    _analyticsData['sessionDuration'] = duration.inSeconds;
    _analyticsData['completedRegistration'] = _currentStep == totalSteps - 1;
    _analyticsData['registrationType'] = registrationType;
    _sendAnalytics();
  }

  Future<void> _sendAnalytics() async {
    try {
      await _firestore.collection('analytics').add({
        ..._analyticsData,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to send analytics: $e');
    }
  }

  // ============================================================================
  // NAVIGATION METHODS
  // ============================================================================

  void _nextStep() async {
    // ✅ Mark that user has attempted to proceed
    setState(() => _hasAttemptedNext = true);

    // ✅ Validate current step strictly
    if (!_validateCurrentStep()) {
      return; // Stop here if validation fails
    }

    // Reset animations for new step
    _fadeController.reset();
    _slideController.reset();

    // Additional checks for specific steps
    if (_currentStep == 1 && registrationType == 'school') {
      setState(() => _isLoading = true);
      bool schoolExists = await _checkSchoolExists(_schoolNameController.text);
      setState(() => _isLoading = false);

      if (schoolExists) {
        _setFieldError('schoolName', 'A school with this name already exists in our system.');
        return;
      }

      setState(() => _isLoading = true);
      bool schoolEmailExists = await _checkSchoolEmailExists(_schoolEmailController.text);
      setState(() => _isLoading = false);

      if (schoolEmailExists) {
        _setFieldError('schoolEmail', 'This email address is already registered with another school.');
        return;
      }
    }

    if (_currentStep == 2 && registrationType == 'school') {
      setState(() => _isLoading = true);
      bool emailExists = await _checkEmailExists(_adminEmailController.text);
      setState(() => _isLoading = false);

      if (emailExists) {
        _setFieldError('adminEmail', 'This email address is already registered.');
        return;
      }

      setState(() => _isLoading = true);
      bool phoneExists = await _checkPhoneExists(_adminPhoneController.text);
      setState(() => _isLoading = false);

      if (phoneExists) {
        _setFieldError('adminPhone', 'This phone number is already registered.');
        return;
      }
    }

    if (_currentStep == 3 && registrationType == 'user') {
      setState(() => _isLoading = true);
      bool emailExists = await _checkEmailExists(_emailController.text);
      setState(() => _isLoading = false);

      if (emailExists) {
        _setFieldError('email', 'This email address is already registered.');
        return;
      }

      setState(() => _isLoading = true);
      bool phoneExists = await _checkPhoneExists(_phoneController.text);
      setState(() => _isLoading = false);

      if (phoneExists) {
        _setFieldError('phone', 'This phone number is already registered.');
        return;
      }
    }

    // Load schools if needed
    if (_currentStep == 0 && registrationType == 'user') {
      _loadApprovedSchools();
    }

    // Generate OTP if at step 4
    if (_currentStep == 4) {
      if (mounted) {
        setState(() => _isLoading = true);
        await _generateAndSendOTP();

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep++;
            _hasAttemptedNext = false; // Reset for next step
          });
          _fadeController.forward();
          _slideController.forward();
        }
        return;
      }
    }

    // Proceed to next step
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentStep++;
        _hasAttemptedNext = false; // Reset for next step
      });
      _fadeController.forward();
      _slideController.forward();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _fadeController.reset();
      _slideController.reset();
      setState(() {
        _currentStep--;
        _hasAttemptedNext = false; // Reset validation state
      });
      _clearAllErrors();
      _fadeController.forward();
      _slideController.forward();
    }
  }

  // ============================================================================
  // REGISTRATION METHODS
  // ============================================================================

  Future<void> _completeRegistration() async {
    _clearAllErrors();

    if (_otpController.text.trim().length != otpLength) {
      _setGeneralError('Please enter a valid 6-digit OTP.');
      return;
    }

    _otpAttempts++;

    if (_otpAttempts > maxOTPAttempts) {
      _setGeneralError('You have exceeded the maximum number of attempts. Please request a new code.');
      return;
    }

    if (_otpController.text.trim() != _generatedOTP) {
      _setGeneralError('The OTP you entered is incorrect. ${maxOTPAttempts - _otpAttempts} attempts remaining.');
      return;
    }

    if (_isOTPExpired()) {
      _setGeneralError('Your verification code has expired. Please request a new code.');
      return;
    }

    if (!await _checkNetworkConnection()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (registrationType == 'school') {
        await _registerSchoolWithAdmin();
      } else {
        await _registerUser();
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth error: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() => _isLoading = false);
        _setGeneralError(_getFirebaseAuthErrorMessage(e.code));
      }
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      if (mounted) {
        setState(() => _isLoading = false);

        if (_isNetworkError(e)) {
          _showNetworkErrorDialog();
        } else {
          _setGeneralError('An unexpected error occurred. Please try again.');
        }
      }
    }
  }

  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered in our system. Please use a different email or try logging in.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password with uppercase, lowercase, numbers, and special characters.';
      case 'invalid-email':
        return 'Invalid email address format. Please enter a valid email.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes before trying again.';
      default:
        return 'Registration failed. Please try again or contact support if the problem persists.';
    }
  }

  Future<void> _registerSchoolWithAdmin() async {
    final email = _adminEmailController.text.trim().toLowerCase();
    final password = _adminPasswordController.text.trim();
    final fullName = _adminNameController.text.trim();
    final phone = _adminPhoneController.text.trim();

    debugPrint('🔐 Creating Firebase Auth account for school admin...');

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUid = userCredential.user!.uid;
    debugPrint('✅ Firebase Auth account created: $firebaseUid');

    await userCredential.user!.updateDisplayName(fullName);

    final schoolId = 'SCHL${await _getNextCounterId('schools')}';
    debugPrint('📚 Creating school with ID: $schoolId');

    await _firestore.collection('schools').doc(schoolId).set({
      'schoolId': schoolId,
      'schoolName': _schoolNameController.text.trim(),
      'address': _schoolAddressController.text.trim(),
      'contactEmail': email,
      'contactPhone': phone,
      'isActive': false,
      'verified': false,
      'registeredBy': firebaseUid,
      'subscribedToNewsletter': _subscribedToNewsletter,
      'agreedToTerms': _agreedToTerms,
      'agreedToTermsAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(networkTimeout);

    final adminId = 'USER${await _getNextCounterId('users')}';
    debugPrint('👤 Creating admin user with ID: $adminId');

    await _firestore.collection('users').doc(adminId).set({
      'userId': adminId,
      'firebaseUid': firebaseUid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'schoolId': schoolId,
      'roleId': 'ROL0006',
      'roleName': 'School Administrator',
      'isVerified': true,
      'isActive': false,
      'status': 'pending',
      'profileCompleted': false,
      'lastLogin': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(networkTimeout);

    await _firestore.collection('auth_lookup').doc(firebaseUid).set({
      'userId': adminId,
      'email': email,
      'roleId': 'ROL0006',
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(networkTimeout);

    await _firestore.collection('pendingAccounts').add({
      'userId': adminId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'roleId': 'ROL0006',
      'roleName': 'School Administrator',
      'schoolId': schoolId,
      'schoolName': _schoolNameController.text.trim(),
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'type': 'school_registration',
    }).timeout(networkTimeout);

    await _auth.signOut();

    debugPrint('✅ School registration completed successfully');
  }

  Future<void> _registerUser() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (selectedRoleId == null || selectedSchoolId == null) {
      throw Exception('Invalid role or school selected');
    }

    debugPrint('🔐 Creating Firebase Auth account for user...');
    debugPrint('👤 Role: $selectedUserRole ($selectedRoleId)');
    debugPrint('🏫 School: $selectedSchoolName ($selectedSchoolId)');

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUid = userCredential.user!.uid;
    debugPrint('✅ Firebase Auth account created: $firebaseUid');

    await userCredential.user!.updateDisplayName(fullName);

    final userId = 'USER${await _getNextCounterId('users')}';
    debugPrint('👤 Creating user with ID: $userId');

    await _firestore.collection('users').doc(userId).set({
      'userId': userId,
      'firebaseUid': firebaseUid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'schoolId': selectedSchoolId,
      'schoolName': selectedSchoolName,
      'roleId': selectedRoleId,
      'roleName': selectedUserRole,
      'rolePermissions': selectedRolePermissions,
      'isVerified': true,
      'isActive': false,
      'status': 'pending',
      'profileCompleted': false,
      'subscribedToNewsletter': _subscribedToNewsletter,
      'agreedToTerms': _agreedToTerms,
      'agreedToTermsAt': FieldValue.serverTimestamp(),
      'lastLogin': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(networkTimeout);

    await _firestore.collection('auth_lookup').doc(firebaseUid).set({
      'userId': userId,
      'email': email,
      'roleId': selectedRoleId,
      'schoolId': selectedSchoolId,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(networkTimeout);

    await _createRoleSpecificDocument(userId, selectedRoleId!, selectedUserRole!);

    await _firestore.collection('pendingAccounts').add({
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'roleId': selectedRoleId,
      'roleName': selectedUserRole,
      'schoolId': selectedSchoolId,
      'schoolName': selectedSchoolName,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'type': 'user_registration',
    }).timeout(networkTimeout);

    await _auth.signOut();

    debugPrint('✅ User registration completed successfully');
  }

  Future<void> _createRoleSpecificDocument(
      String userId,
      String roleId,
      String roleName
      ) async {
    try {
      final baseData = {
        'userId': userId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': _phoneController.text.trim(),
        'schoolId': selectedSchoolId,
        'schoolName': selectedSchoolName,
        'isActive': false,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (roleId) {
        case 'ROL0003':
          debugPrint('👨‍👩‍👧 Creating parent document...');
          await _firestore.collection('parents').doc(userId).set({
            ...baseData,
            'children': [],
            'emergencyContact': '',
            'relationship': '',
            'notificationPreferences': {
              'email': true,
              'sms': true,
              'push': true,
              'attendance': true,
              'location': true,
              'emergency': true,
            },
          }).timeout(networkTimeout);
          break;

        case 'ROL0002':
          debugPrint('👨‍🏫 Creating teacher document...');
          await _firestore.collection('teachers').doc(userId).set({
            ...baseData,
            'subjects': [],
            'classes': [],
            'employeeId': '',
            'qualification': '',
            'joinDate': null,
            'specializations': [],
          }).timeout(networkTimeout);
          break;

        case 'ROL0005':
          debugPrint('🚌 Creating driver document...');
          await _firestore.collection('drivers').doc(userId).set({
            ...baseData,
            'busNumber': '',
            'route': '',
            'licenseNumber': '',
            'licenseExpiry': null,
            'assignedBusId': '',
            'vehicleType': '',
            'experience': 0,
          }).timeout(networkTimeout);
          break;

        case 'ROL0004':
          debugPrint('🔒 Creating security document...');
          await _firestore.collection('security').doc(userId).set({
            ...baseData,
            'shift': '',
            'badgeNumber': '',
            'assignedGate': '',
            'clearanceLevel': 'basic',
            'certifications': [],
          }).timeout(networkTimeout);
          break;

        default:
          debugPrint('ℹ️ No role-specific document needed for roleId: $roleId');
      }

      debugPrint('✅ Role-specific document created successfully');
    } catch (e) {
      debugPrint('❌ Error creating role-specific document: $e');
      throw Exception('Failed to create role-specific document: $e');
    }
  }

  // ============================================================================
  // UI HELPER METHODS
  // ============================================================================

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;

    Color backgroundColor = Colors.grey[800]!;
    if (isError) backgroundColor = Colors.red;
    if (isSuccess) backgroundColor = Colors.green;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.1),
                ),
                child: const Icon(Icons.info_outline, color: Colors.orange, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showContactSupportDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        'Contact Support',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.1),
                ),
                child: const Icon(Icons.wifi_off, color: Colors.orange, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please check your internet connection and try again. A stable connection is required to complete the registration process.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        bool hasConnection = await _checkNetworkConnection();
                        setState(() => _isLoading = false);

                        if (hasConnection && mounted) {
                          _showSnackBar('✓ Connection restored!', isSuccess: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A1929).withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Color(0xFF0A1929),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Contact Support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Need help with your account? Our support team is here to assist you.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.email, color: Color(0xFF0A1929), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('support@s3ts.com', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Color(0xFF0A1929), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('+233 XX XXX XXXX', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Color(0xFF0A1929), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Mon - Fri: 8:00 AM - 5:00 PM',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A1929),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Registration Submitted!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  registrationType == 'school'
                      ? 'Your school registration has been submitted successfully. A system administrator will review and approve your school. You will receive a notification once approved.'
                      : 'Your account has been submitted for approval by your school administrator. You will be notified via email and SMS once your account is approved.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            children: [
              const Text(
                'Terms and Conditions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    '''
TERMS AND CONDITIONS

1. ACCEPTANCE OF TERMS
By registering for S3TS, you agree to these Terms and Conditions.

2. PRIVACY & DATA PROTECTION
We are committed to protecting your privacy and handling your data in accordance with GDPR and applicable laws.

3. USER RESPONSIBILITIES
- Provide accurate information
- Maintain account security
- Use the system responsibly

4. SCHOOL RESPONSIBILITIES
- Verify user accounts appropriately
- Maintain data accuracy
- Ensure proper system usage

5. PROHIBITED ACTIVITIES
- Unauthorized access attempts
- Data manipulation
- Sharing credentials
- Malicious activities

6. LIABILITY
S3TS is provided "as is" without warranties. We are not liable for indirect damages.

7. TERMINATION
Accounts may be terminated for violations of these terms.

8. MODIFICATIONS
We reserve the right to modify these terms with notice.

9. GOVERNING LAW
These terms are governed by the laws of Ghana.

10. CONTACT
For questions, contact support@s3ts.com
                    ''',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _agreedToTerms = true);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A1929),
                    ),
                    child: const Text(
                      'I Agree',
                      style: TextStyle(color: Colors.white),
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

  // ============================================================================
  // UI BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]
                    : const [Color(0xFF0A1929), Color(0xFF1A2F3F)],
              ),
            ),
            child: SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: screenHeight -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeader(),
                          _buildProgressIndicator(),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildStepContent(isDark),
                            ),
                          ),
                          _buildNavigationButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ✅ Only loading overlay - no error overlay
          if (_isLoading) _buildJumpingDotsOverlay(),
        ],
      ),
    );
  }

  // ✅ Jumping Dots Loading Overlay (like login screen)
  Widget _buildJumpingDotsOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    final delay = index * 0.2;
                    final animationValue = (value - delay).clamp(0.0, 1.0);
                    final offset = sin(animationValue * pi * 2) * 10;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Transform.translate(
                        offset: Offset(0, -offset),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    if (_isLoading && mounted) {
                      setState(() {});
                    }
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
            const Text(
              'Processing...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Enhanced general error display widget
  Widget _buildGeneralError() {
    if (_generalError == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Required Fields Missing',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _generalError!,
                  style: const TextStyle(
                    color: Colors.red,
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps, (index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index <= _currentStep
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of $totalSteps',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Show general errors at top of step
            _buildGeneralError(),

            if (_currentStep == 0) _buildRegistrationTypeSelection(isDark),
            if (_currentStep == 1 && registrationType == 'school')
              _buildSchoolInfo(isDark),
            if (_currentStep == 1 && registrationType == 'user')
              _buildEnhancedUserRoleSelection(isDark),
            if (_currentStep == 2 && registrationType == 'school')
              _buildAdminAccount(isDark),
            if (_currentStep == 2 && registrationType == 'user')
              _buildSchoolSelection(isDark),
            if (_currentStep == 3 && registrationType == 'school')
              _buildPasswordConfirmation(isDark, isSchool: true),
            if (_currentStep == 3 && registrationType == 'user')
              _buildPersonalDetails(isDark),
            if (_currentStep == 4 && registrationType == 'school')
              _buildSchoolRegistrationSummary(isDark),
            if (_currentStep == 4 && registrationType == 'user')
              _buildPasswordConfirmation(isDark, isSchool: false),
            if (_currentStep == 5) _buildVerification(isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationTypeSelection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registration Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose how you want to register',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        _buildSelectionCard(
          'Register Your School',
          'Register your school to use the S3TS system',
          Icons.school,
          registrationType == 'school',
              () => setState(() => registrationType = 'school'),
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          'Join as a User',
          'Register as teacher, parent, driver, or security personnel',
          Icons.person,
          registrationType == 'user',
              () => setState(() => registrationType = 'user'),
        ),
      ],
    );
  }

  Widget _buildSelectionCard(
      String title,
      String desc,
      IconData icon,
      bool selected,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.lightImpact();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF0A1929).withOpacity(0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFF0A1929) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 40, color: const Color(0xFF0A1929)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? const Color(0xFF0A1929) : Colors.grey,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolInfo(bool isDark) {
    return Form(
      key: _schoolInfoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'School Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please provide your school details',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'School Name',
            _schoolNameController,
            Icons.school_outlined,
            hint: 'e.g., Accra International School',
            fieldKey: 'schoolName',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Address',
            _schoolAddressController,
            Icons.location_on_outlined,
            hint: 'School address',
            maxLines: 2,
            fieldKey: 'schoolAddress',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Email',
            _schoolEmailController,
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            hint: 'school@example.com',
            fieldKey: 'schoolEmail',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Phone',
            _schoolPhoneController,
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            hint: '+233 XX XXX XXXX',
            fieldKey: 'schoolPhone',
            isRequired: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccount(bool isDark) {
    return Form(
      key: _adminAccountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Administrator Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'This will be the primary administrator account',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Full Name',
            _adminNameController,
            Icons.person_outline,
            hint: 'Administrator full name',
            fieldKey: 'adminName',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Email',
            _adminEmailController,
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            hint: 'admin@example.com',
            fieldKey: 'adminEmail',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Phone',
            _adminPhoneController,
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            hint: '+233 XX XXX XXXX',
            fieldKey: 'adminPhone',
            isRequired: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedUserRoleSelection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Your Role',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose the role that best describes you',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (_isLoadingRoles)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_isLoadingRoles)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading available roles...',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else if (availableRoles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'No Roles Available',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please contact your school administrator for assistance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadAvailableRoles,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ],
            ),
          )
        else
          ...availableRoles.map((role) {
            final roleId = role['roleId'] as String;
            final roleName = role['name'] as String;
            final roleDesc = role['description'] as String;
            final roleIcon = role['icon'] as IconData;
            final roleColor = role['color'] as Color;
            final isSelected = selectedRoleId == roleId;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedRoleId = roleId;
                      selectedUserRole = roleName;
                      selectedRolePermissions = role['permissions'] as Map<String, dynamic>?;
                    });
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? roleColor.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? roleColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(roleIcon, color: roleColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roleName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSelected ? roleColor : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                roleDesc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSelected ? roleColor : Colors.grey,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }


  Widget _buildPersonalDetails(bool isDark) {
    return Form(
      key: _personalDetailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us about yourself',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Full Name',
            _nameController,
            Icons.person_outline,
            hint: 'Your full name',
            fieldKey: 'fullName',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Email',
            _emailController,
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            hint: 'your.email@example.com',
            fieldKey: 'email',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Phone',
            _phoneController,
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            hint: '+233 XX XXX XXXX',
            fieldKey: 'phone',
            isRequired: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordConfirmation(bool isDark, {required bool isSchool}) {
    final pwdController =
    isSchool ? _adminPasswordController : _passwordController;
    final confirmController = isSchool
        ? _adminConfirmPasswordController
        : _confirmPasswordController;

    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Password',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a strong password for your account',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildPasswordField(
            'Password',
            pwdController,
            _obscurePassword,
                () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            onChanged: _calculatePasswordStrength,
            fieldKey: 'password',
            isRequired: true,
          ),
          if (pwdController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Password Strength: $_passwordStrengthText',
                      style: TextStyle(
                        fontSize: 12,
                        color: _passwordStrengthColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(_passwordStrength * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: _passwordStrengthColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _passwordStrength,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                  minHeight: 6,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildPasswordField(
            'Confirm Password',
            confirmController,
            _obscureConfirmPassword,
                () {
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
            },
            fieldKey: 'confirmPassword',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue, size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Password Requirements:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• At least 8 characters long',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
                Text(
                  '• Contains uppercase letter (A-Z)',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
                Text(
                  '• Contains lowercase letter (a-z)',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
                Text(
                  '• Contains number (0-9)',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
                Text(
                  '• Contains special character (!@#\$%^&*)',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ],
            ),
          ),
          if (!isSchool) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _agreedToTerms,
              onChanged: (value) {
                setState(() => _agreedToTerms = value ?? false);
                HapticFeedback.lightImpact();
              },
              title: const Text(
                'I agree to the Terms and Conditions',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: GestureDetector(
                onTap: () => _showTermsDialog(),
                child: const Text(
                  'Read Terms and Conditions',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0A1929),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _subscribedToNewsletter,
              onChanged: (value) {
                setState(() => _subscribedToNewsletter = value ?? false);
                HapticFeedback.lightImpact();
              },
              title: const Text(
                'Subscribe to newsletter (optional)',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Get updates about new features and school safety tips',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSchoolRegistrationSummary(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Your Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please review all information before proceeding',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.school, color: Color(0xFF0A1929), size: 24),
                  SizedBox(width: 12),
                  Text(
                    'School Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A1929),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1),
              _buildSummaryRow(
                'School Name',
                _schoolNameController.text,
                Icons.school_outlined,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Address',
                _schoolAddressController.text,
                Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Email',
                _schoolEmailController.text,
                Icons.email_outlined,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Phone',
                _schoolPhoneController.text,
                Icons.phone_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFF1A2F3F),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Administrator Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2F3F),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1),
              _buildSummaryRow(
                'Full Name',
                _adminNameController.text,
                Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Email',
                _adminEmailController.text,
                Icons.email_outlined,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Phone',
                _adminPhoneController.text,
                Icons.phone_outlined,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Password',
                '••••••••',
                Icons.lock_outline,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          value: _agreedToTerms,
          onChanged: (value) {
            setState(() => _agreedToTerms = value ?? false);
            HapticFeedback.lightImpact();
          },
          title: const Text(
            'I agree to the Terms and Conditions',
            style: TextStyle(fontSize: 14),
          ),
          subtitle: GestureDetector(
            onTap: () => _showTermsDialog(),
            child: const Text(
              'Read Terms and Conditions',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF0A1929),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[300]!),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please review all information carefully before proceeding to verification.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerification(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verify Your Account',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[300]!),
          ),
          child: Column(
            children: const [
              Icon(Icons.mark_email_read, color: Colors.green, size: 48),
              SizedBox(height: 16),
              Text(
                'Verification Code Sent',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'A 6-digit OTP has been sent to your email and phone number',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Contact Information',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.email_outlined, color: Colors.grey, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      registrationType == 'school'
                          ? _adminEmailController.text
                          : _emailController.text,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, color: Colors.grey, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      registrationType == 'school'
                          ? _adminPhoneController.text
                          : _phoneController.text,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Enter OTP Code',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        // ✅ Enhanced OTP field with validation
        _buildTextField(
          'OTP Code',
          _otpController,
          Icons.lock_outline,
          keyboardType: TextInputType.number,
          hint: '000000',
          fieldKey: 'otp',
          isRequired: true,
          maxLength: 6,
        ),
        if (_otpAttempts > 0 && _otpAttempts < maxOTPAttempts) ...[
          const SizedBox(height: 8),
          Text(
            '${maxOTPAttempts - _otpAttempts} attempts remaining',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Didn't receive code? ",
              style: TextStyle(fontSize: 12),
            ),
            if (_canResendOTP)
              GestureDetector(
                onTap: () async {
                  _otpController.clear();
                  await _generateAndSendOTP();
                },
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    color: Color(0xFF0A1929),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Text(
                'Resend in $_resendCountdown seconds',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        if (_isOTPExpired())
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your OTP has expired. Please request a new code.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_currentStep == 5 ? _completeRegistration : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A1929),
                disabledBackgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep == 5 ? 'Complete' : 'Next',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Enhanced text field with required indicator and better validation
  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
        String? hint,
        int maxLines = 1,
        int? maxLength,
        void Function(String)? onChanged,
        String? fieldKey,
        bool isRequired = false,
      }) {
    final hasError = fieldKey != null && _fieldErrors.containsKey(fieldKey);
    final errorText = hasError ? _fieldErrors[fieldKey] : null;
    final isEmpty = controller.text.trim().isEmpty;
    final shouldShowRequired = isRequired && _hasAttemptedNext && isEmpty && !hasError;

    // Determine border color and fill color
    Color borderColor = Colors.grey;
    Color fillColor = Colors.grey[100]!;

    if (hasError) {
      borderColor = Colors.red;
      fillColor = Colors.red.withOpacity(0.05);
    } else if (shouldShowRequired) {
      borderColor = Colors.red;
      fillColor = Colors.red.withOpacity(0.05);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Enhanced label with required indicator
        if (isRequired) ...[
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              children: [
                TextSpan(text: label),
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: (value) {
            // ✅ Clear error when user starts typing
            if (fieldKey != null && hasError) {
              _setFieldError(fieldKey, null);
            }
            onChanged?.call(value);
          },
          decoration: InputDecoration(
            labelText: !isRequired ? label : null,
            hintText: hint,
            prefixIcon: Icon(icon),
            counterText: '', // Hide character counter
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: borderColor,
                width: (hasError || shouldShowRequired) ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: borderColor,
                width: (hasError || shouldShowRequired) ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (hasError || shouldShowRequired) ? Colors.red : const Color(0xFF0A1929),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: fillColor,
          ),
        ),

        // ✅ Show error text or required message
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ] else if (shouldShowRequired) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'This field is required',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ✅ Enhanced password field with required indicator
  Widget _buildPasswordField(
      String label,
      TextEditingController controller,
      bool obscure,
      VoidCallback onToggle, {
        void Function(String)? onChanged,
        String? fieldKey,
        bool isRequired = false,
      }) {
    final hasError = fieldKey != null && _fieldErrors.containsKey(fieldKey);
    final errorText = hasError ? _fieldErrors[fieldKey] : null;
    final isEmpty = controller.text.trim().isEmpty;
    final shouldShowRequired = isRequired && _hasAttemptedNext && isEmpty && !hasError;

    // Determine border color and fill color
    Color borderColor = Colors.grey;
    Color fillColor = Colors.grey[100]!;

    if (hasError) {
      borderColor = Colors.red;
      fillColor = Colors.red.withOpacity(0.05);
    } else if (shouldShowRequired) {
      borderColor = Colors.red;
      fillColor = Colors.red.withOpacity(0.05);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Enhanced label with required indicator
        if (isRequired) ...[
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              children: [
                TextSpan(text: label),
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: (value) {
            // ✅ Clear error when user starts typing
            if (fieldKey != null && hasError) {
              _setFieldError(fieldKey, null);
            }
            onChanged?.call(value);
          },
          decoration: InputDecoration(
            labelText: !isRequired ? label : null,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggle,
              tooltip: obscure ? 'Show password' : 'Hide password',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: borderColor,
                width: (hasError || shouldShowRequired) ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: borderColor,
                width: (hasError || shouldShowRequired) ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (hasError || shouldShowRequired) ? Colors.red : const Color(0xFF0A1929),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: fillColor,
          ),
        ),

        // ✅ Show error text or required message
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ] else if (shouldShowRequired) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'This field is required',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}