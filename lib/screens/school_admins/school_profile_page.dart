import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

class SchoolProfilePage extends StatefulWidget {
  final String userId;
  final String schoolId;
  final String userName;

  const SchoolProfilePage({
    super.key,
    required this.userId,
    required this.schoolId,
    required this.userName,
  });

  @override
  State<SchoolProfilePage> createState() => _SchoolProfilePageState();
}

class _SchoolProfilePageState extends State<SchoolProfilePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _showSchoolProfile = false;
  Map<String, dynamic> _schoolProfile = {};
  Map<String, dynamic> _adminProfile = {};

  final ImagePicker _picker = ImagePicker();
  bool _isUploadingSchoolLogo = false;
  bool _isUploadingAdminPhoto = false;
  double _uploadProgress = 0.0;

  late AnimationController _dotsController;

  // 🎨 CONSISTENT NAVY BLUE COLOR SCHEME
  static const Color navyDark = Color(0xFF0A1929);
  static const Color navyPrimary = Color(0xFF1e3a5f);
  static const Color navyBlue = Color(0xFF2563eb);
  static const Color navyLight = Color(0xFF3b82f6);
  static const Color accentGreen = Color(0xFF10b981);
  static const Color accentRed = Color(0xFFef4444);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color cardWhite = Colors.white;
  static const Color textSecondary = Color(0xFF64748b);

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _loadProfiles();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('========================================');
      debugPrint('📥 Loading profiles...');
      debugPrint('🏫 School ID: ${widget.schoolId}');
      debugPrint('👤 User ID: ${widget.userId}');

      // Load school data from 'schools' collection
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();

      // Load admin data from 'users' collection
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      debugPrint('📋 School doc exists: ${schoolDoc.exists}');
      debugPrint('📋 Admin doc exists: ${adminDoc.exists}');

      if (schoolDoc.exists) {
        final schoolData = schoolDoc.data() ?? {};
        debugPrint('🏫 School data loaded: ${schoolData.keys.toList()}');
        debugPrint('🖼️ School logo URL: ${schoolData['schoolLogoUrl']}');
      }

      if (adminDoc.exists) {
        final adminData = adminDoc.data() ?? {};
        debugPrint('👤 Admin data loaded: ${adminData.keys.toList()}');
        debugPrint('📸 Admin photo URL: ${adminData['profilePhotoUrl']}');
      }

      if (mounted) {
        setState(() {
          _schoolProfile = schoolDoc.data() ?? {};
          _adminProfile = adminDoc.data() ?? {};
          _isLoading = false;
        });
        debugPrint('✅ Profiles loaded successfully');
        debugPrint('========================================');
      }
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('❌ Error loading profiles: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('========================================');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackbar('Failed to load profiles: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _showSchoolProfile ? 'School Profile' : 'My Profile',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                _showSchoolProfile ? Icons.person : Icons.school,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showSchoolProfile = !_showSchoolProfile;
                });
              },
              tooltip: _showSchoolProfile
                  ? 'View Admin Profile'
                  : 'View School Profile',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isLoading) _buildContent(),

          // ✅ PROFESSIONAL 3-DOT LOADING OVERLAY
          if (_isLoading)
            Container(
              color: lightBg,
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
                                    gradient: LinearGradient(
                                      colors: index == 1
                                          ? [navyDark, navyBlue]
                                          : [navyBlue, navyLight],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: navyBlue.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
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
                      'Loading profile...',
                      style: TextStyle(
                        fontSize: 14,
                        color: navyDark,
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

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadProfiles,
      color: navyBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: _showSchoolProfile
            ? _buildSchoolProfileSection()
            : _buildAdminProfileSection(),
      ),
    );
  }

  Widget _buildAdminProfileSection() {
    final adminPhotoUrl = _adminProfile['profilePhotoUrl'] as String?;
    final fullName = _adminProfile['fullName'] as String? ?? widget.userName;
    final email = _adminProfile['email'] as String? ?? 'Not set';
    final phone = _adminProfile['phone'] as String? ?? 'Not set';
    final title = _adminProfile['title'] as String? ?? 'School Administrator';
    final employeeId = _adminProfile['employeeId'] as String? ?? 'Not set';
    final department =
        _adminProfile['department'] as String? ?? 'Administration';
    final dateJoined = _adminProfile['dateJoined'] as String? ?? 'Not set';
    final emergencyContact =
        _adminProfile['emergencyContact'] as String? ?? 'Not set';
    final qualifications =
        _adminProfile['qualifications'] as String? ?? 'Not set';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Card
        Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: navyDark.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Photo
              Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: navyBlue, width: 3),
                      color: navyBlue.withOpacity(0.1),
                    ),
                    child: ClipOval(
                      child: _isUploadingAdminPhoto
                          ? _buildUploadProgress()
                          : (adminPhotoUrl != null && adminPhotoUrl.isNotEmpty
                          ? Image.network(
                        adminPhotoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder:
                            (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress
                                  .expectedTotalBytes !=
                                  null
                                  ? loadingProgress
                                  .cumulativeBytesLoaded /
                                  loadingProgress
                                      .expectedTotalBytes!
                                  : null,
                              strokeWidth: 3,
                              color: navyBlue,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAdminPhoto(fullName);
                        },
                      )
                          : _buildDefaultAdminPhoto(fullName)),
                    ),
                  ),
                  if (!_isUploadingAdminPhoto)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploadAdminPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: navyBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardWhite, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: navyDark.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: navyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: navyBlue.withOpacity(0.3)),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: navyBlue,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _editAdminProfile,
                  icon: const Icon(Icons.edit, size: 18, color: navyBlue),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: navyBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Information Card
        Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: navyDark.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.badge, 'Employee ID', employeeId),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.business, 'Department', department),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.email, 'Email', email),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.phone, 'Phone', phone),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.calendar_month, 'Date Joined', dateJoined),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.emergency, 'Emergency Contact', emergencyContact),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.school, 'Qualifications', qualifications),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // School Profile Button
        InkWell(
          onTap: () {
            setState(() {
              _showSchoolProfile = true;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [navyDark, navyPrimary],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: navyDark.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View School Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'School information and settings',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchoolProfileSection() {
    // Map database field names to display names
    final schoolLogoUrl = _schoolProfile['schoolLogoUrl'] as String?;
    final schoolName = _schoolProfile['schoolName'] as String? ?? 'School Name';
    final address = _schoolProfile['address'] as String? ?? 'Not set';
    final phone = _schoolProfile['contactPhone'] as String? ?? 'Not set';
    final email = _schoolProfile['contactEmail'] as String? ?? 'Not set';
    final website = _schoolProfile['website'] as String? ?? 'Not set';
    final establishedYear = _schoolProfile['establishedYear'] as String? ?? 'Not set';
    final motto = _schoolProfile['motto'] as String? ?? 'Not set';
    final studentCapacity = _schoolProfile['studentCapacity'] as String? ?? 'Not set';

    // Security settings
    final safeZoneRadius = (_schoolProfile['safeZoneRadius'] as num?)?.toDouble() ?? 200.0;
    final latitude = (_schoolProfile['latitude'] as num?)?.toDouble();
    final longitude = (_schoolProfile['longitude'] as num?)?.toDouble();

    debugPrint('📊 Displaying school data:');
    debugPrint('  School Name: $schoolName');
    debugPrint('  Safe Zone: $safeZoneRadius meters');
    debugPrint('  GPS: ${latitude ?? 'N/A'}, ${longitude ?? 'N/A'}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // School Logo & Name Card
        Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: navyDark.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: navyBlue, width: 3),
                      color: navyBlue.withOpacity(0.1),
                    ),
                    child: ClipOval(
                      child: _isUploadingSchoolLogo
                          ? _buildUploadProgress()
                          : (schoolLogoUrl != null && schoolLogoUrl.isNotEmpty
                          ? Image.network(
                        schoolLogoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder:
                            (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress
                                  .expectedTotalBytes !=
                                  null
                                  ? loadingProgress
                                  .cumulativeBytesLoaded /
                                  loadingProgress
                                      .expectedTotalBytes!
                                  : null,
                              strokeWidth: 3,
                              color: navyBlue,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultSchoolLogo();
                        },
                      )
                          : _buildDefaultSchoolLogo()),
                    ),
                  ),
                  if (!_isUploadingSchoolLogo)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploadSchoolLogo,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: navyBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardWhite, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: navyDark.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                schoolName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                ),
              ),
              if (motto != 'Not set') ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: navyBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: navyBlue.withOpacity(0.2)),
                  ),
                  child: Text(
                    '"$motto"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _editSchoolProfile,
                  icon: const Icon(Icons.edit, size: 18, color: navyBlue),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: navyBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // School Information Card
        Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: navyDark.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'School Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.location_on, 'Address', address),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.phone, 'Phone', phone),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.email, 'Email', email),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.language, 'Website', website),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.calendar_today, 'Established', establishedYear),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.people, 'Student Capacity', studentCapacity),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Security Settings Card
        Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: navyDark.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: accentGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Security Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _editSecuritySettings,
                    icon: const Icon(Icons.edit, size: 18, color: navyBlue),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        color: navyBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSecurityRow(
                Icons.radar,
                'Safe Zone Radius',
                '${safeZoneRadius.toInt()} meters',
                accentGreen,
              ),
              const SizedBox(height: 16),
              _buildSecurityRow(
                Icons.location_on,
                'School GPS Location',
                latitude != null && longitude != null
                    ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
                    : 'Not configured',
                navyBlue,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: navyBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: navyBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: navyBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'These settings protect students by monitoring their location relative to the school.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      color: navyDark.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: _uploadProgress,
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Colors.white.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(_uploadProgress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultSchoolLogo() {
    return Container(
      color: navyBlue.withOpacity(0.1),
      child: const Center(
        child: Icon(
          Icons.school,
          size: 60,
          color: navyBlue,
        ),
      ),
    );
  }

  Widget _buildDefaultAdminPhoto(String name) {
    return Container(
      color: navyBlue.withOpacity(0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: navyBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: navyBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: navyBlue,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: navyDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _uploadSchoolLogo() async {
    await _showImagePickerDialog(true);
  }

  Future<void> _uploadAdminPhoto() async {
    await _showImagePickerDialog(false);
  }

  Future<void> _showImagePickerDialog(bool isSchoolLogo) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: navyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSchoolLogo ? Icons.school : Icons.person,
                  size: 40,
                  color: navyBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSchoolLogo ? 'Update School Logo' : 'Update Profile Photo',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildImageSourceButton(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera, isSchoolLogo);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildImageSourceButton(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery, isSchoolLogo);
                      },
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

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: navyBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: navyBlue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: navyBlue),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: navyBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, bool isSchoolLogo) async {
    try {
      debugPrint('========================================');
      debugPrint('🎯 Starting image selection from: $source');
      debugPrint('Type: ${isSchoolLogo ? "School Logo" : "Admin Photo"}');

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        debugPrint('❌ User cancelled image selection');
        return;
      }

      debugPrint('✅ Image picked successfully: ${pickedFile.path}');
      debugPrint('📁 Image name: ${pickedFile.name}');

      if (mounted) {
        setState(() {
          if (isSchoolLogo) {
            _isUploadingSchoolLogo = true;
          } else {
            _isUploadingAdminPhoto = true;
          }
          _uploadProgress = 0.0;
        });
      }

      debugPrint('📖 Reading image bytes...');
      final Uint8List imageBytes = await pickedFile.readAsBytes();
      debugPrint('📦 Image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');

      if (imageBytes.isEmpty) {
        throw Exception('Image file is empty');
      }

      if (imageBytes.length > 5 * 1024 * 1024) {
        throw Exception('Image size exceeds 5MB limit. Please choose a smaller image.');
      }

      await _uploadImageBytes(imageBytes, pickedFile.name, isSchoolLogo);

      debugPrint('========================================');

    } on PlatformException catch (e) {
      debugPrint('❌ Platform error: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _isUploadingSchoolLogo = false;
          _isUploadingAdminPhoto = false;
          _uploadProgress = 0.0;
        });

        String message = 'Failed to access camera/gallery';
        if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
          message = 'Permission denied. Please enable camera/photos in device settings.';
        }
        _showErrorSnackbar(message);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error selecting image: $e');
      debugPrint('Stack: $stackTrace');
      if (mounted) {
        setState(() {
          _isUploadingSchoolLogo = false;
          _isUploadingAdminPhoto = false;
          _uploadProgress = 0.0;
        });
        _showErrorSnackbar('Failed to select image: ${e.toString()}');
      }
    }
  }

  Future<void> _uploadImageBytes(
      Uint8List imageBytes, String fileName, bool isSchoolLogo) async {
    try {
      debugPrint('========================================');
      debugPrint('🚀 Starting Firebase Upload');
      debugPrint('📦 Image size: ${imageBytes.length} bytes');
      debugPrint('🎯 Type: ${isSchoolLogo ? "School Logo" : "Admin Photo"}');
      debugPrint('👤 User ID: ${widget.userId}');
      debugPrint('🏫 School ID: ${widget.schoolId}');

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String storagePath = isSchoolLogo
          ? 'school_logos/${widget.schoolId}/$timestamp.jpg'
          : 'admin_photos/${widget.userId}/$timestamp.jpg';

      debugPrint('📂 Storage path: $storagePath');

      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      debugPrint('✅ Storage reference created');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': widget.userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'fileName': fileName,
          'type': isSchoolLogo ? 'school_logo' : 'admin_photo',
        },
      );

      debugPrint('⬆️ Starting upload...');
      final uploadTask = storageRef.putData(imageBytes, metadata);

      uploadTask.snapshotEvents.listen(
            (snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
          debugPrint('📊 Progress: ${(progress * 100).toStringAsFixed(1)}% (${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes)');
        },
        onError: (error) {
          debugPrint('❌ Upload stream error: $error');
        },
      );

      final TaskSnapshot snapshot = await uploadTask;
      debugPrint('✅ Upload state: ${snapshot.state}');
      debugPrint('📊 Total bytes transferred: ${snapshot.bytesTransferred}');

      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      debugPrint('🔗 Getting download URL...');
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Download URL obtained: $downloadUrl');

      // Save to Firestore with correct collection and field names
      debugPrint('💾 Saving to Firestore...');
      if (isSchoolLogo) {
        // Save to 'schools' collection
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .update({
          'schoolLogoUrl': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ School logo saved to schools/${widget.schoolId}');
      } else {
        // Save to 'users' collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update({
          'profilePhotoUrl': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Admin photo saved to users/${widget.userId}');
      }

      debugPrint('⏳ Waiting for Firestore consistency...');
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('🔄 Reloading profiles...');
      await _loadProfiles();

      if (mounted) {
        setState(() {
          if (isSchoolLogo) {
            _isUploadingSchoolLogo = false;
          } else {
            _isUploadingAdminPhoto = false;
          }
          _uploadProgress = 0.0;
        });

        _showSuccessSnackbar(
          isSchoolLogo
              ? '🎉 School logo updated successfully!'
              : '🎉 Profile photo updated successfully!',
        );
      }

      debugPrint('========================================');
      debugPrint('✅ UPLOAD COMPLETED SUCCESSFULLY');
      debugPrint('========================================');

    } on FirebaseException catch (e) {
      debugPrint('========================================');
      debugPrint('❌ FIREBASE ERROR');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      debugPrint('Plugin: ${e.plugin}');
      debugPrint('========================================');

      if (mounted) {
        setState(() {
          if (isSchoolLogo) {
            _isUploadingSchoolLogo = false;
          } else {
            _isUploadingAdminPhoto = false;
          }
          _uploadProgress = 0.0;
        });

        String errorMessage = 'Failed to upload image';

        switch (e.code) {
          case 'object-not-found':
            errorMessage = '📁 Upload path issue. Retrying might help.';
            break;
          case 'unauthorized':
            errorMessage = '🔒 Permission denied.\n\nFirebase Storage Rules needed:\nallow read, write: if request.auth != null;';
            break;
          case 'canceled':
            errorMessage = '⏹️ Upload was cancelled.';
            break;
          case 'unknown':
            errorMessage = '❓ Unknown error. Check internet connection.';
            break;
          case 'bucket-not-found':
            errorMessage = '🪣 Storage bucket not configured in Firebase.';
            break;
          case 'project-not-found':
            errorMessage = '🚫 Firebase project not found.';
            break;
          case 'quota-exceeded':
            errorMessage = '💾 Storage quota exceeded.';
            break;
          case 'unauthenticated':
            errorMessage = '🔐 User not authenticated. Please login again.';
            break;
          case 'retry-limit-exceeded':
            errorMessage = '🔄 Upload timeout. Check your connection.';
            break;
          case 'invalid-checksum':
            errorMessage = '❌ File corrupted. Please try again.';
            break;
          default:
            errorMessage = '❌ Firebase error: ${e.message ?? e.code}';
        }

        _showErrorSnackbar(errorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('❌ GENERAL ERROR');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('========================================');

      if (mounted) {
        setState(() {
          if (isSchoolLogo) {
            _isUploadingSchoolLogo = false;
          } else {
            _isUploadingAdminPhoto = false;
          }
          _uploadProgress = 0.0;
        });

        String errorMessage = 'Failed to upload image';
        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('permission') || errorStr.contains('unauthorized')) {
          errorMessage = '🔒 Permission denied. Check Firebase Storage rules.';
        } else if (errorStr.contains('network') || errorStr.contains('connection')) {
          errorMessage = '📡 Network error. Check your internet connection.';
        } else if (errorStr.contains('timeout')) {
          errorMessage = '⏱️ Upload timeout. Please try again.';
        } else {
          errorMessage = '❌ Upload failed: ${e.toString()}';
        }

        _showErrorSnackbar(errorMessage);
      }
    }
  }

  void _editSchoolProfile() {
    // Use correct field names from database
    final nameController = TextEditingController(text: _schoolProfile['schoolName']);
    final addressController = TextEditingController(text: _schoolProfile['address']);
    final phoneController = TextEditingController(text: _schoolProfile['contactPhone']);
    final emailController = TextEditingController(text: _schoolProfile['contactEmail']);
    final websiteController = TextEditingController(text: _schoolProfile['website']);
    final yearController = TextEditingController(text: _schoolProfile['establishedYear']);
    final mottoController = TextEditingController(text: _schoolProfile['motto']);
    final capacityController = TextEditingController(text: _schoolProfile['studentCapacity']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: navyDark.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: navyBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school, color: navyBlue, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Edit School Profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: navyDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: navyDark),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(nameController, 'School Name', Icons.school),
                      const SizedBox(height: 18),
                      _buildTextField(mottoController, 'Motto', Icons.format_quote),
                      const SizedBox(height: 18),
                      _buildTextField(addressController, 'Address', Icons.location_on, maxLines: 2),
                      const SizedBox(height: 18),
                      _buildTextField(phoneController, 'Phone', Icons.phone),
                      const SizedBox(height: 18),
                      _buildTextField(emailController, 'Email', Icons.email),
                      const SizedBox(height: 18),
                      _buildTextField(websiteController, 'Website', Icons.language),
                      const SizedBox(height: 18),
                      _buildTextField(yearController, 'Established Year', Icons.calendar_today),
                      const SizedBox(height: 18),
                      _buildTextField(capacityController, 'Student Capacity', Icons.people),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardWhite,
                  boxShadow: [
                    BoxShadow(
                      color: navyDark.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: navyDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Use correct field names for database
                          await _saveSchoolProfile({
                            'schoolName': nameController.text.trim(),
                            'address': addressController.text.trim(),
                            'contactPhone': phoneController.text.trim(),
                            'contactEmail': emailController.text.trim(),
                            'website': websiteController.text.trim(),
                            'establishedYear': yearController.text.trim(),
                            'motto': mottoController.text.trim(),
                            'studentCapacity': capacityController.text.trim(),
                          });
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editAdminProfile() {
    final nameController = TextEditingController(text: _adminProfile['fullName']);
    final emailController = TextEditingController(text: _adminProfile['email']);
    final phoneController = TextEditingController(text: _adminProfile['phone']);
    final titleController = TextEditingController(text: _adminProfile['title']);
    final employeeIdController = TextEditingController(text: _adminProfile['employeeId']);
    final departmentController = TextEditingController(text: _adminProfile['department']);
    final emergencyController = TextEditingController(text: _adminProfile['emergencyContact']);
    final qualificationsController = TextEditingController(text: _adminProfile['qualifications']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: navyDark.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: navyBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person, color: navyBlue, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Edit Admin Profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: navyDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: navyDark),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(nameController, 'Full Name', Icons.person),
                      const SizedBox(height: 18),
                      _buildTextField(titleController, 'Job Title', Icons.work),
                      const SizedBox(height: 18),
                      _buildTextField(employeeIdController, 'Employee ID', Icons.badge),
                      const SizedBox(height: 18),
                      _buildTextField(departmentController, 'Department', Icons.business),
                      const SizedBox(height: 18),
                      _buildTextField(emailController, 'Email', Icons.email),
                      const SizedBox(height: 18),
                      _buildTextField(phoneController, 'Phone', Icons.phone),
                      const SizedBox(height: 18),
                      _buildTextField(emergencyController, 'Emergency Contact', Icons.emergency),
                      const SizedBox(height: 18),
                      _buildTextField(qualificationsController, 'Qualifications', Icons.school, maxLines: 2),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardWhite,
                  boxShadow: [
                    BoxShadow(
                      color: navyDark.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: navyDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _saveAdminProfile({
                            'fullName': nameController.text.trim(),
                            'email': emailController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'title': titleController.text.trim(),
                            'employeeId': employeeIdController.text.trim(),
                            'department': departmentController.text.trim(),
                            'emergencyContact': emergencyController.text.trim(),
                            'qualifications': qualificationsController.text.trim(),
                          });
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        int maxLines = 1,
      }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: navyDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: navyBlue, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyBlue, width: 2),
        ),
        filled: true,
        fillColor: lightBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Future<void> _saveSchoolProfile(Map<String, String> data) async {
    try {
      debugPrint('💾 Saving school profile to schools/${widget.schoolId}');
      debugPrint('Data: $data');

      // Save to 'schools' collection
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ School profile saved successfully');
      await _loadProfiles();

      if (mounted) {
        _showSuccessSnackbar('✅ School profile updated!');
      }
    } catch (e) {
      debugPrint('❌ Error saving school profile: $e');
      if (mounted) {
        _showErrorSnackbar('Failed to update profile: ${e.toString()}');
      }
    }
  }

  Future<void> _saveAdminProfile(Map<String, String> data) async {
    try {
      debugPrint('💾 Saving admin profile to users/${widget.userId}');
      debugPrint('Data: $data');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Admin profile saved successfully');
      await _loadProfiles();

      if (mounted) {
        _showSuccessSnackbar('✅ Profile updated!');
      }
    } catch (e) {
      debugPrint('❌ Error saving admin profile: $e');
      if (mounted) {
        _showErrorSnackbar('Failed to update profile: ${e.toString()}');
      }
    }
  }

  void _editSecuritySettings() {
    // Load existing values with proper type casting
    final safeZoneRadius = (_schoolProfile['safeZoneRadius'] as num?)?.toDouble() ?? 200.0;
    final latitude = (_schoolProfile['latitude'] as num?)?.toDouble();
    final longitude = (_schoolProfile['longitude'] as num?)?.toDouble();

    final radiusController = TextEditingController(text: safeZoneRadius.toInt().toString());
    final latitudeController = TextEditingController(text: latitude?.toString() ?? '');
    final longitudeController = TextEditingController(text: longitude?.toString() ?? '');

    debugPrint('🔒 Opening security settings');
    debugPrint('  Current radius: $safeZoneRadius');
    debugPrint('  Current GPS: $latitude, $longitude');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: navyDark.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.security, color: accentGreen, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Edit Security Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: navyDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: navyDark),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Safe Zone Radius',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: navyDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: radiusController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: navyDark,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Radius in meters',
                          hintText: 'e.g., 500',
                          labelStyle: const TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.radar, color: accentGreen, size: 22),
                          suffixText: 'meters',
                          suffixStyle: const TextStyle(color: textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentGreen, width: 2),
                          ),
                          filled: true,
                          fillColor: lightBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: accentGreen, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'The safe zone radius defines the perimeter around the school. Students outside this zone will trigger alerts.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'School GPS Coordinates',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: navyDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: navyDark,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          hintText: 'e.g., 5.6037',
                          labelStyle: const TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.location_on, color: navyBlue, size: 22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: navyBlue, width: 2),
                          ),
                          filled: true,
                          fillColor: lightBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: navyDark,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          hintText: 'e.g., -0.1870',
                          labelStyle: const TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.place, color: navyBlue, size: 22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: navyBlue, width: 2),
                          ),
                          filled: true,
                          fillColor: lightBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: navyBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: navyBlue.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: navyBlue, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Enter the exact GPS coordinates of your school. You can get these from Google Maps.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardWhite,
                  boxShadow: [
                    BoxShadow(
                      color: navyDark.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: navyDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _saveSecuritySettings({
                            'safeZoneRadius': double.tryParse(radiusController.text.trim()) ?? 200.0,
                            'latitude': double.tryParse(latitudeController.text.trim()),
                            'longitude': double.tryParse(longitudeController.text.trim()),
                          });
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSecuritySettings(Map<String, dynamic> data) async {
    try {
      debugPrint('💾 Saving security settings to schools/${widget.schoolId}');
      debugPrint('Data: $data');

      // Save to 'schools' collection
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Security settings saved successfully');
      await _loadProfiles();

      if (mounted) {
        _showSuccessSnackbar('🔒 Security settings updated successfully!');
      }
    } catch (e) {
      debugPrint('❌ Error saving security settings: $e');
      if (mounted) {
        _showErrorSnackbar('Failed to update security settings: ${e.toString()}');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}