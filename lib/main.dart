import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:find_me/screens/splash_screen.dart';
import 'package:find_me/screens/login/login_screen.dart';
import 'package:find_me/screens/create_account.dart';
import 'package:find_me/screens/school_admins/school_AdminPage.dart';
import 'package:find_me/screens/security/security_homepage.dart';
import 'package:find_me/services/firestore_roles_initializer.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ FIXED: Made role initialization optional and more robust
  // Initialize Roles Collection (only if needed and permissions allow)
  await _initializeSystemRoles();

  runApp(const MyApp());
}

/// Initialize roles collection in Firestore
/// This runs automatically on app start but only creates roles if they don't exist
/// ✅ FIXED: Now handles permission errors gracefully and doesn't block app startup
Future<void> _initializeSystemRoles() async {
  try {
    debugPrint('🔍 Checking system roles...');

    final initializer = FirestoreRolesInitializer();

    // ✅ FIXED: Check if roles are already initialized
    // This will fail gracefully if permissions are denied
    final alreadyInitialized = await initializer.areRolesInitialized();

    if (alreadyInitialized) {
      debugPrint('✅ System roles already exist');
      debugPrint('📋 Available roles:');
      debugPrint('   - ROL0001: School Admin');
      debugPrint('   - ROL0002: Teacher');
      debugPrint('   - ROL0003: Parent');
      debugPrint('   - ROL0004: Security Personnel');
      debugPrint('   - ROL0005: Driver');
      debugPrint('   - ROL0006: System Owner');
      return;
    }

    // Roles don't exist, try to create them
    debugPrint('🔄 Initializing system roles...');
    await initializer.initializeRoles();

    debugPrint('✅ System roles initialized successfully!');
    debugPrint('📋 Created roles:');
    debugPrint('   - ROL0001: School Admin');
    debugPrint('   - ROL0002: Teacher');
    debugPrint('   - ROL0003: Parent');
    debugPrint('   - ROL0004: Security Personnel');
    debugPrint('   - ROL0005: Driver');
    debugPrint('   - ROL0006: System Owner');

  } on Exception catch (e) {
    // ✅ FIXED: Improved error handling with specific error types
    final errorString = e.toString().toLowerCase();

    if (errorString.contains('permission') || errorString.contains('denied')) {
      // Permission error - roles probably already exist or need manual setup
      debugPrint('ℹ️ Cannot access roles collection (permission denied)');
      debugPrint('   This is normal if:');
      debugPrint('   1. Roles already exist in Firestore');
      debugPrint('   2. Firebase Security Rules are restrictive');
      debugPrint('   3. Roles need to be created manually');
      debugPrint('');
      debugPrint('💡 The app will work normally if roles exist.');
      debugPrint('   If you encounter role-related errors, check:');
      debugPrint('   - Firebase Console → Firestore → roles collection');
      debugPrint('   - Firebase Console → Firestore → Rules');
    } else if (errorString.contains('network') || errorString.contains('connection')) {
      // Network error
      debugPrint('⚠️ Network error while checking roles: $e');
      debugPrint('   Please check your internet connection.');
      debugPrint('   The app will continue, but may have limited functionality.');
    } else {
      // Other errors
      debugPrint('⚠️ Could not initialize roles: $e');
      debugPrint('   The app will continue, but roles may need manual setup.');
    }

    debugPrint('');
    debugPrint('🚀 Continuing app startup...');

    // ✅ Don't block app startup - let it continue
  } catch (e) {
    // Catch-all for any other errors
    debugPrint('❌ Unexpected error during role initialization: $e');
    debugPrint('🚀 Continuing app startup...');

    // ✅ Still don't block app startup
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FindMe - Smart Student Safety & Tracking System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667eea),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,

      // Initial route
      initialRoute: '/',

      // Named routes
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const SecureLoginScreen(),
        '/signup': (context) => const CreateAccountScreen(),
      },

      // Generate routes for dynamic screens (with parameters)
      onGenerateRoute: (settings) {
        // Handle routes that require parameters
        switch (settings.name) {
          case '/school-admin':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => SchoolAdminPage(
                  userId: args['userId'] as String,
                  userName: args['userName'] as String,
                  schoolId: args['schoolId'] as String,
                ),
              );
            }
            break;

          case '/security-home':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => SecurityHomePage(
                  userId: args['userId'] as String,
                  userName: args['userName'] as String,
                  schoolId: args['schoolId'] as String,
                ),
              );
            }
            break;

          default:
            break;
        }

        // If no route found, show error screen
        return MaterialPageRoute(
          builder: (context) => const RouteErrorScreen(),
        );
      },

      // Handle unknown routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const RouteErrorScreen(),
        );
      },
    );
  }
}

/// Error screen for unknown routes
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Page Not Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The page you are looking for does not exist.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                      (route) => false,
                );
              },
              icon: const Icon(Icons.home),
              label: const Text('Go to Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}