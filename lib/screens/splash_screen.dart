import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  double _loadingProgress = 0.0;
  String _loadingMessage = 'Initializing...';
  bool _navigated = false;

  final List<String> _loadingMessages = [
    'Initializing...',
    'Loading Security Modules...',
    'Connecting to Server...',
    'Authenticating System...',
    'Preparing Dashboard...',
    'Loading Student Data...',
    'Setting up Safety Protocols...',
    'Configuring Tracking System...',
    'Finalizing Setup...',
    'Ready to Launch...',
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Fade animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      _simulateLoading();
      _navigateToLogin();
    });
  }

  void _simulateLoading() {
    int step = 0;

    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (step < _loadingMessages.length) {
          _loadingMessage = _loadingMessages[step];
        }

        _loadingProgress = (step + 1) / _loadingMessages.length;
        step++;

        if (step >= _loadingMessages.length) {
          timer.cancel();
        }
      });
    });
  }

  void _navigateToLogin() {
    Timer(const Duration(seconds: 10), () {
      if (!mounted || _navigated) return;
      _navigated = true;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          const SecureLoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1929), // Dark blue
              Color(0xFF1A2F3F), // Slightly lighter dark blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo with circular loading
              _buildLogoWithCircularLoading(),

              const Spacer(flex: 2),

              // App name + tagline
              _buildAppName(),

              const Spacer(flex: 3),

              // Loading message section
              _buildLoadingSection(),

              const SizedBox(height: 60),

              // Footer icons
              _buildFooter(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoWithCircularLoading() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Transform.translate(
        offset: Offset(0, _slideAnimation.value * 30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular progress indicator
            SizedBox(
              width: 160,
              height: 160,
              child: CircularProgressIndicator(
                value: _loadingProgress,
                strokeWidth: 4,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

            // Logo background circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              // Logo image or icon
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: _buildLogoContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoContent() {
    // TRY TO LOAD CUSTOM LOGO IMAGE FIRST
    // If image not found, fallback to icon
    return Image.asset(
      'assets/images/logo.png', // Your custom logo path
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if image not found
        return Container(
          color: Colors.white,
          child: const Center(
            child: Icon(
              Icons.security_rounded,
              size: 65,
              color: Color(0xFF0A1929), // Dark blue
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppName() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Transform.translate(
        offset: Offset(0, _slideAnimation.value * 20),
        child: Column(
          children: [
            const Text(
              'find_me',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Text(
                'Smart Student Safety & Tracking System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            // Loading message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                _loadingMessage,
                key: ValueKey<String>(_loadingMessage),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Progress percentage
            Text(
              '${(_loadingProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureIcon(Icons.shield_rounded, 'Secure'),
              const SizedBox(width: 20),
              _buildFeatureIcon(Icons.track_changes_rounded, 'Track'),
              const SizedBox(width: 20),
              _buildFeatureIcon(Icons.notifications_active_rounded, 'Alert'),
              const SizedBox(width: 20),
              _buildFeatureIcon(Icons.location_on_rounded, 'Location'),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2025 find_me - Hour of Code TGAC',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
