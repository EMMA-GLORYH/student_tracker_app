import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:find_me/screens/create_account.dart';
import 'package:find_me/screens/school_admins/school_AdminPage.dart';
import 'package:find_me/screens/security/security_homepage.dart';
import 'package:find_me/screens/teachers/teachers_page.dart';
import 'package:find_me/screens/parents/parents_screen.dart';

class SecureLoginScreen extends StatefulWidget {
  const SecureLoginScreen({super.key});

  @override
  State<SecureLoginScreen> createState() => _SecureLoginScreenState();
}

class _SecureLoginScreenState extends State<SecureLoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _dotsController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _canCheckBiometrics = false;
  bool _hasSavedBiometricCredentials = false;
  bool _hasLoggedInBefore = false;
  bool _showEmailField = false;
  String _savedEmail = '';

  // Track available biometric types
  List<BiometricType> _availableBiometrics = [];
  bool _hasFaceRecognition = false;
  bool _hasFingerprint = false;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _checkBiometrics();
    _checkPreviousLogin();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      _canCheckBiometrics = await _localAuth.canCheckBiometrics;

      if (_canCheckBiometrics) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();

        // Check for face recognition
        _hasFaceRecognition = _availableBiometrics.contains(BiometricType.face);

        // Check for fingerprint
        _hasFingerprint = _availableBiometrics.contains(BiometricType.fingerprint) ||
            _availableBiometrics.contains(BiometricType.strong) ||
            _availableBiometrics.contains(BiometricType.weak);
      }

      final prefs = await SharedPreferences.getInstance();
      final hasBiometric = prefs.getBool('biometric_enabled') ?? false;
      final savedEmail = prefs.getString('saved_biometric_email') ?? '';

      _hasSavedBiometricCredentials = hasBiometric && savedEmail.isNotEmpty;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
    }
  }

  Future<void> _checkPreviousLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';

    if (mounted && savedEmail.isNotEmpty) {
      setState(() {
        _hasLoggedInBefore = true;
        _savedEmail = savedEmail;
        _emailController.text = savedEmail;
        _showEmailField = false;
      });
    } else {
      setState(() {
        _hasLoggedInBefore = false;
        _savedEmail = '';
        _showEmailField = true;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      // Check if we have saved credentials first
      if (!_hasSavedBiometricCredentials) {
        _showErrorDialog(
          'No Saved Credentials',
          'Please login with your password first to enable biometric authentication.',
        );
        return;
      }

      // Determine authentication message based on available biometrics
      String authMessage = 'Authenticate to access your account';
      if (_hasFaceRecognition && _hasFingerprint) {
        authMessage = 'Use Face ID or Fingerprint to sign in';
      } else if (_hasFaceRecognition) {
        authMessage = 'Use Face ID to sign in';
      } else if (_hasFingerprint) {
        authMessage = 'Use Fingerprint to sign in';
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: authMessage,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        setState(() => _isLoading = true);

        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString('saved_biometric_email') ?? '';

        if (savedEmail.isEmpty) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorDialog('Error', 'No saved credentials found.');
          }
          return;
        }

        final currentUser = _auth.currentUser;

        if (currentUser != null && currentUser.email == savedEmail) {
          await _navigateToUserDashboard(currentUser.uid);
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorDialog(
              'Session Expired',
              'Please sign in with your password.',
            );
            _emailController.text = savedEmail;
          }
        }
      } else {
        // ✅ FIXED: User cancelled authentication - just return silently
        debugPrint('Biometric authentication cancelled by user');
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: ${e.code} - ${e.message}');

      // ✅ FIXED: Handle all Huawei/Android biometric error codes
      if (mounted) {
        if (e.code == 'NotEnrolled' || e.code == 'PasscodeNotSet') {
          _showBiometricSetupDialog();
        } else if (e.code == 'NotAvailable') {
          _showErrorDialog(
            'Biometric Not Available',
            'Biometric authentication is not available on this device.',
          );
        } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
          _showErrorDialog(
            'Too Many Attempts',
            'Biometric authentication is temporarily locked. Please try again later or use your password.',
          );
        } else if (e.code != 'AuthenticationCanceled' &&
            e.code != 'UserCanceled' &&
            e.code != 'SystemCanceled') {
          // Only show error for actual failures, not cancellations
          _showErrorDialog(
            'Authentication Failed',
            'Biometric authentication failed. Please try again or use your password.',
          );
        }
        // If it's a cancellation, do nothing (don't show error or close app)
      }
    } catch (e) {
      // ✅ FIXED: Catch any other unexpected errors
      debugPrint('Unexpected biometric error: $e');
      if (mounted) {
        _showErrorDialog(
          'Authentication Error',
          'An unexpected error occurred. Please use your password to sign in.',
        );
      }
    }
  }

  void _showBiometricSetupDialog() {
    String biometricType = 'biometric authentication';
    IconData biometricIcon = Icons.fingerprint_rounded;

    if (_hasFaceRecognition && !_hasFingerprint) {
      biometricType = 'Face ID';
      biometricIcon = Icons.face_rounded;
    } else if (_hasFingerprint && !_hasFaceRecognition) {
      biometricType = 'Fingerprint';
      biometricIcon = Icons.fingerprint_rounded;
    } else if (_hasFaceRecognition && _hasFingerprint) {
      biometricType = 'Face ID or Fingerprint';
      biometricIcon = Icons.security_rounded;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A1929).withOpacity(0.1),
                ),
                child: Icon(
                  biometricIcon,
                  color: const Color(0xFF0A1929),
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Biometric Not Set Up',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You need to set up $biometricType on your device first.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0A1929)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF0A1929),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // ✅ FIXED: Just show a message, don't close the app
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please go to Settings > Security to set up biometric authentication'),
                            duration: Duration(seconds: 4),
                            backgroundColor: Color(0xFF0A1929),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A1929),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                ),
                child: const Icon(Icons.error_outline,
                    color: Colors.red, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A1929), // ✅ FIXED: Changed from Colors.red to navy blue
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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

  Future<void> _navigateToUserDashboard(String firebaseUid) async {
    try {
      debugPrint('🔍 Starting navigation for firebaseUid: $firebaseUid');

      final userQuery = await _firestore
          .collection('users')
          .where('firebaseUid', isEqualTo: firebaseUid)
          .limit(1)
          .get();

      debugPrint('📊 Query returned ${userQuery.docs.length} documents');

      if (userQuery.docs.isEmpty) {
        debugPrint('❌ No user document found');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(
            'Account Not Found',
            'No account data found for this user. Please contact support.',
          );
        }
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();

      debugPrint('📄 User document ID: ${userDoc.id}');
      debugPrint('📄 User data keys: ${userData.keys.toList()}');

      // ✅ FIXED: Handle userId - use document ID if field is missing
      String userId = userData['userId'] as String? ?? '';
      if (userId.isEmpty) {
        userId = userDoc.id; // Use Firestore document ID as fallback
        debugPrint('⚠️ userId field missing, using document ID: $userId');
      }

      // ✅ FIXED: Handle schoolId - allow empty for some roles
      String schoolId = userData['schoolId'] as String? ?? '';
      if (schoolId.isEmpty) {
        debugPrint('⚠️ schoolId field missing or empty');
        // For roles that don't need schoolId, use a default
        schoolId = 'DEFAULT';
      }

      final userName = userData['fullName'] as String? ?? 'User';
      final roleId = userData['roleId'] as String? ?? '';
      final isActive = userData['isActive'] as bool? ?? false;
      final isVerified = userData['isVerified'] as bool? ?? false;

      debugPrint('✅ Extracted data:');
      debugPrint('   - userId: $userId');
      debugPrint('   - userName: $userName');
      debugPrint('   - roleId: $roleId');
      debugPrint('   - schoolId: $schoolId');
      debugPrint('   - isActive: $isActive');
      debugPrint('   - isVerified: $isVerified');

      // Validate that roleId exists
      if (roleId.isEmpty) {
        debugPrint('❌ roleId is empty');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(
            'Incomplete Data',
            'Your account is missing role information. Please contact your administrator.',
          );
        }
        return;
      }

      if (!isActive) {
        debugPrint('❌ Account is not active');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(
            'Account Inactive',
            'Your account is not active. Please contact your administrator.',
          );
        }
        return;
      }

      if (!isVerified) {
        debugPrint('❌ Account is not verified');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(
            'Account Not Verified',
            'Please verify your email address first.',
          );
        }
        return;
      }

      debugPrint('🔍 Fetching role document: $roleId');
      final roleDoc = await _firestore.collection('roles').doc(roleId).get();

      if (!roleDoc.exists) {
        debugPrint('❌ Role document not found: $roleId');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(
            'Role Not Found',
            'Your account role ($roleId) could not be found. Please contact support.',
          );
        }
        return;
      }

      final roleData = roleDoc.data()!;
      debugPrint('📄 Role data keys: ${roleData.keys.toList()}');

      // ✅ FIXED: Try both 'roleName' and 'name' fields to match your database
      String roleName = '';
      if (roleData.containsKey('roleName')) {
        roleName = roleData['roleName'] as String? ?? 'Unknown';
        debugPrint('✅ Found roleName: $roleName');
      } else if (roleData.containsKey('name')) {
        roleName = roleData['name'] as String? ?? 'Unknown';
        debugPrint('✅ Found name (using as roleName): $roleName');
      } else {
        // Fallback: check if it's stored on the user document
        roleName = userData['roleName'] as String? ?? 'Unknown';
        debugPrint('⚠️ roleName not in role doc, using from user doc: $roleName');
      }

      debugPrint('✅ Final roleName: $roleName');

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('user_roleId', roleId);
      await prefs.setString('school_id', schoolId);
      await prefs.setString('user_name', userName);
      await prefs.setString('role_name', roleName);

      debugPrint('✅ Saved to SharedPreferences');

      if (mounted) {
        setState(() => _isLoading = false);

        debugPrint('🚀 Navigating to dashboard for role: $roleId');
        Widget destination = _getDestinationForRole(
          roleId,
          userId,
          userName,
          schoolId,
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => destination),
        );

        debugPrint('✅ Navigation complete');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error navigating to dashboard: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog(
          'Error Loading Account',
          'Failed to load your account data.\n\nError: ${e.toString()}\n\nPlease try again or contact support.',
        );
      }
    }
  }

  Widget _getDestinationForRole(
      String roleId,
      String userId,
      String userName,
      String schoolId,
      ) {
    debugPrint('🎯 Getting destination for roleId: $roleId');

    switch (roleId.toUpperCase()) {
      case 'ROL0001':
        debugPrint('→ Navigating to SchoolAdminPage');
        return SchoolAdminPage(
          userId: userId,
          userName: userName,
          schoolId: schoolId,
        );

      case 'ROL0002':
        debugPrint('→ Navigating to TeachersPage');
        return TeachersPage(
          teacherId: userId,
          userName: userName,
        );

      case 'ROL0003':
        debugPrint('→ Navigating to ParentHomepage');
        return ParentHomepage(
          parentId: userId,
        );

      case 'ROL0004':
        debugPrint('→ Navigating to SecurityHomePage');
        return SecurityHomePage(
          userId: userId,
          userName: userName,
          schoolId: schoolId,
        );

      case 'ROL0005':
        debugPrint('→ Navigating to Driver Dashboard');
        return Scaffold(
          appBar: AppBar(title: const Text('Driver Dashboard')),
          body: Center(child: Text('Welcome $userName')),
        );

      case 'ROL0006':
        debugPrint('→ Navigating to System Owner Dashboard');
        return Scaffold(
          appBar: AppBar(title: const Text('System Owner Dashboard')),
          body: Center(child: Text('Welcome $userName')),
        );

      default:
        debugPrint('❌ Unknown role: $roleId');
        return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Unknown role: $roleId'),
                const SizedBox(height: 8),
                const Text('Please contact your administrator.'),
              ],
            ),
          ),
        );
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      String email;
      if (_showEmailField) {
        email = _emailController.text.trim().toLowerCase();
      } else if (_savedEmail.isNotEmpty) {
        email = _savedEmail.toLowerCase();
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog('Error', 'Please enter your email address.');
        }
        return;
      }

      final password = _passwordController.text.trim();

      debugPrint('🔐 Attempting login for: $email');

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUid = userCredential.user!.uid;
      debugPrint('✅ Firebase Auth successful. UID: $firebaseUid');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', email);

      if (_canCheckBiometrics) {
        await prefs.setString('saved_biometric_email', email);
        await prefs.setBool('biometric_enabled', true);
      }

      await _navigateToUserDashboard(firebaseUid);
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');

      if (mounted) {
        setState(() => _isLoading = false);

        String message;
        switch (e.code) {
          case 'user-not-found':
            message = 'No account found with this email.';
            break;
          case 'wrong-password':
            message = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            message = 'Invalid email address.';
            break;
          case 'user-disabled':
            message = 'This account has been disabled.';
            break;
          case 'too-many-requests':
            message = 'Too many failed attempts. Please try again later.';
            break;
          default:
            message = 'Login failed: ${e.message}';
        }

        _showErrorDialog('Login Failed', message);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected Error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Error', 'An unexpected error occurred: $e');
      }
    }
  }

  void _handleSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
    );
  }

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController();
    if (!_showEmailField && _savedEmail.isNotEmpty) {
      emailController.text = _savedEmail;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A1929).withOpacity(0.1),
                ),
                child: const Icon(Icons.lock_reset,
                    color: Color(0xFF0A1929), size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your email address and we\'ll send you a password reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0A1929)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF0A1929),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter your email address'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          await _auth.sendPasswordResetEmail(email: email);
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } on FirebaseAuthException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.message ?? 'Error sending reset email'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A1929),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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

    emailController.dispose();

    if (result == true && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 50),
              SizedBox(height: 12),
              Text(
                'Link Sent',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'A password reset link has been sent to your email.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _switchToFullLogin() {
    setState(() {
      _showEmailField = true;
      _savedEmail = '';
      _emailController.clear();
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background with logo image (ROTATED 180°) and navy blue overlay
          Transform.rotate(
            angle: 3.14159265359, // Exactly 180 degrees (π radians)
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/logo.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    const Color(0xFF0A1929).withOpacity(0.50),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),

          // Additional gradient overlay on top
          Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A1929).withOpacity(0.85),
                  const Color(0xFF1A2F3F).withOpacity(0.80),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App name with glow effect
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.15),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Text(
                        'find_me',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2.5,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.2,
                        ),
                      ),
                      child: const Text(
                        'Smart Student Safety & Tracking',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Login form card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.98),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Biometric login section - SHOWS FOR ALL USERS WITH BIOMETRIC CAPABILITY
                            if (_canCheckBiometrics && (_hasFaceRecognition || _hasFingerprint))
                              Column(
                                children: [
                                  const Text(
                                    'Quick Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0A1929),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _hasFaceRecognition && _hasFingerprint
                                        ? 'Use Face ID or Fingerprint'
                                        : _hasFaceRecognition
                                        ? 'Use Face ID to sign in'
                                        : 'Use Fingerprint to sign in',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),

                                  // Biometric button(s)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Face Recognition button
                                      if (_hasFaceRecognition)
                                        GestureDetector(
                                          onTap: _authenticateWithBiometrics,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFF0A1929).withOpacity(0.12),
                                                  const Color(0xFF1A2F3F).withOpacity(0.08),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF0A1929).withOpacity(0.25),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.face_rounded,
                                              size: 32,
                                              color: Color(0xFF0A1929),
                                            ),
                                          ),
                                        ),

                                      // Spacing between icons
                                      if (_hasFaceRecognition && _hasFingerprint)
                                        const SizedBox(width: 20),

                                      // Fingerprint button
                                      if (_hasFingerprint)
                                        GestureDetector(
                                          onTap: _authenticateWithBiometrics,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFF0A1929).withOpacity(0.12),
                                                  const Color(0xFF1A2F3F).withOpacity(0.08),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF0A1929).withOpacity(0.25),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.fingerprint_rounded,
                                              size: 32,
                                              color: Color(0xFF0A1929),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),
                                  Divider(color: Colors.grey[300], thickness: 1),
                                  const SizedBox(height: 16),
                                ],
                              ),

                            // Welcome back message for returning users
                            if (!_showEmailField && _hasLoggedInBefore)
                              Column(
                                children: [
                                  const Text(
                                    'Welcome Back!',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0A1929),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A1929).withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _savedEmail,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF0A1929),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ),

                            // Email field (shown only if needed)
                            if (_showEmailField)
                              Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: _validateEmail,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText: 'Email Address',
                                      labelStyle: const TextStyle(fontSize: 13),
                                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Password field (always shown)
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              validator: _validatePassword,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Switch account button (for returning users)
                            if (!_showEmailField && _hasLoggedInBefore)
                              TextButton(
                                onPressed: _switchToFullLogin,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                ),
                                child: const Text(
                                  'Login with different account',
                                  style: TextStyle(
                                    color: Color(0xFF0A1929),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 14),

                            // Sign In button
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0A1929),
                                    Color(0xFF1A2F3F),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0A1929).withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Sign Up and Forgot Password row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _handleSignUp,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                  ),
                                  child: const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      color: Color(0xFF0A1929),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _handleForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay with jumping dots
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.60),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _dotsController,
                      builder: (context, child) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            final delay = index * 0.2;
                            final value = (_dotsController.value + delay) % 1.0;
                            final offset = (value < 0.5
                                ? value * 2
                                : (1 - value) * 2) * 18;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Transform.translate(
                                offset: Offset(0, -offset),
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index == 1
                                        ? const Color(0xFF0A1929) // Middle dot: Navy dark blue
                                        : Colors.white, // Outer dots: White
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Signing in...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}