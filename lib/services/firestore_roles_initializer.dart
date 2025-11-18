import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Initialize Firestore Roles Collection
/// Run this ONCE when setting up the app for the first time
class FirestoreRolesInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize all system roles
  Future<void> initializeRoles() async {
    try {
      final roles = _getRolesData();

      // Use batch write for efficiency
      final batch = _firestore.batch();

      for (final role in roles) {
        final docRef = _firestore.collection('roles').doc(role['roleId']);
        batch.set(docRef, role);
      }

      await batch.commit();
      debugPrint('✅ All roles initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing roles: $e');
      rethrow;
    }
  }

  /// Check if roles are already initialized
  Future<bool> areRolesInitialized() async {
    try {
      final snapshot = await _firestore.collection('roles').limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking roles: $e');
      return false;
    }
  }

  /// Get all role definitions
  List<Map<String, dynamic>> _getRolesData() {
    return [
      {
        'roleId': 'ROL0001',
        'name': 'School Admin',
        'description': 'School administrator with full management capabilities',
        'permissions': {
          'users': ['create', 'read', 'update', 'delete'],
          'students': ['create', 'read', 'update', 'delete'],
          'teachers': ['create', 'read', 'update', 'delete'],
          'parents': ['create', 'read', 'update', 'delete'],
          'drivers': ['create', 'read', 'update', 'delete'],
          'security': ['create', 'read', 'update', 'delete'],
          'routes': ['create', 'read', 'update', 'delete'],
          'attendance': ['read', 'update'],
          'reports': ['read', 'export'],
          'settings': ['read', 'update'],
          'notifications': ['create', 'read', 'update', 'delete'],
        },
        'level': 2,
        'isActive': true,
        'canManageSchool': true,
        'canManageUsers': true,
        'canViewReports': true,
        'canManageRoutes': true,
        'requiresSchool': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'roleId': 'ROL0002',
        'name': 'Teacher',
        'description': 'Teacher with student management and attendance capabilities',
        'permissions': {
          'students': ['read', 'update'],
          'attendance': ['create', 'read', 'update'],
          'parents': ['read'],
          'reports': ['read'],
          'notifications': ['create', 'read'],
        },
        'level': 3,
        'isActive': true,
        'canManageSchool': false,
        'canManageUsers': false,
        'canViewReports': true,
        'canManageRoutes': false,
        'requiresSchool': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'roleId': 'ROL0003',
        'name': 'Parent',
        'description': 'Parent/guardian with child tracking capabilities',
        'permissions': {
          'students': ['read'],
          'attendance': ['read'],
          'routes': ['read'],
          'notifications': ['read'],
          'tracking': ['read'],
        },
        'level': 4,
        'isActive': true,
        'canManageSchool': false,
        'canManageUsers': false,
        'canViewReports': false,
        'canManageRoutes': false,
        'requiresSchool': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'roleId': 'ROL0004',
        'name': 'Security Personnel',
        'description': 'Security staff with gate management capabilities',
        'permissions': {
          'students': ['read'],
          'attendance': ['read', 'update'],
          'gate_logs': ['create', 'read'],
          'alerts': ['create', 'read'],
          'notifications': ['read'],
        },
        'level': 3,
        'isActive': true,
        'canManageSchool': false,
        'canManageUsers': false,
        'canViewReports': false,
        'canManageRoutes': false,
        'requiresSchool': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'roleId': 'ROL0005',
        'name': 'Driver',
        'description': 'School bus/van driver with route management',
        'permissions': {
          'students': ['read'],
          'routes': ['read', 'update'],
          'attendance': ['create', 'read', 'update'],
          'tracking': ['create', 'update'],
          'notifications': ['read'],
        },
        'level': 3,
        'isActive': true,
        'canManageSchool': false,
        'canManageUsers': false,
        'canViewReports': false,
        'canManageRoutes': false,
        'requiresSchool': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'roleId': 'ROL0006',
        'name': 'System Owner',
        'description': 'Super administrator with full system access',
        'permissions': {
          'schools': ['create', 'read', 'update', 'delete'],
          'users': ['create', 'read', 'update', 'delete'],
          'students': ['create', 'read', 'update', 'delete'],
          'teachers': ['create', 'read', 'update', 'delete'],
          'parents': ['create', 'read', 'update', 'delete'],
          'drivers': ['create', 'read', 'update', 'delete'],
          'security': ['create', 'read', 'update', 'delete'],
          'routes': ['create', 'read', 'update', 'delete'],
          'attendance': ['create', 'read', 'update', 'delete'],
          'reports': ['read', 'export'],
          'settings': ['create', 'read', 'update', 'delete'],
          'roles': ['create', 'read', 'update', 'delete'],
          'notifications': ['create', 'read', 'update', 'delete'],
          'system': ['read', 'update', 'maintenance'],
        },
        'level': 1,
        'isActive': true,
        'canManageSchool': true,
        'canManageUsers': true,
        'canViewReports': true,
        'canManageRoutes': true,
        'requiresSchool': false,
        'isSuperAdmin': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];
  }

  /// Get role by ID
  Future<Map<String, dynamic>?> getRoleById(String roleId) async {
    try {
      final doc = await _firestore.collection('roles').doc(roleId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error getting role: $e');
      return null;
    }
  }

  /// Check if user has specific permission
  Future<bool> userHasPermission(
      String roleId,
      String resource,
      String action,
      ) async {
    try {
      final role = await getRoleById(roleId);
      if (role == null) return false;

      final permissions = role['permissions'] as Map<String, dynamic>?;
      if (permissions == null) return false;

      final resourcePermissions = permissions[resource] as List<dynamic>?;
      if (resourcePermissions == null) return false;

      return resourcePermissions.contains(action);
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  /// Get all roles
  Future<List<Map<String, dynamic>>> getAllRoles() async {
    try {
      final snapshot = await _firestore
          .collection('roles')
          .orderBy('level')
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'roleId': doc.id})
          .toList();
    } catch (e) {
      debugPrint('Error getting all roles: $e');
      return [];
    }
  }

  /// Get roles by school requirement
  Future<List<Map<String, dynamic>>> getRolesForSchoolAdmin() async {
    try {
      final snapshot = await _firestore
          .collection('roles')
          .where('requiresSchool', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .orderBy('level')
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'roleId': doc.id})
          .toList();
    } catch (e) {
      debugPrint('Error getting school roles: $e');
      return [];
    }
  }
}

/// Widget to initialize roles (call this on first app launch)
class RolesInitializationWidget extends StatefulWidget {
  const RolesInitializationWidget({super.key});

  @override
  State<RolesInitializationWidget> createState() =>
      _RolesInitializationWidgetState();
}

class _RolesInitializationWidgetState
    extends State<RolesInitializationWidget> {
  final FirestoreRolesInitializer _initializer = FirestoreRolesInitializer();
  bool _isInitializing = false;
  String _status = 'Ready to initialize roles';

  Future<void> _initializeRoles() async {
    setState(() {
      _isInitializing = true;
      _status = 'Checking existing roles...';
    });

    try {
      final alreadyInitialized = await _initializer.areRolesInitialized();

      if (alreadyInitialized) {
        setState(() {
          _status = 'Roles already initialized!';
          _isInitializing = false;
        });
        return;
      }

      setState(() {
        _status = 'Creating roles...';
      });

      await _initializer.initializeRoles();

      setState(() {
        _status = '✅ All roles created successfully!';
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initialize Roles'),
        backgroundColor: const Color(0xFF667eea),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shield_rounded,
              size: 80,
              color: Color(0xFF667eea),
            ),
            const SizedBox(height: 24),
            const Text(
              'Role Initialization',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            if (_isInitializing)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _initializeRoles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Initialize Roles',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Roles to be created:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('• ROL0001 - School Admin'),
                    Text('• ROL0002 - Teacher'),
                    Text('• ROL0003 - Parent'),
                    Text('• ROL0004 - Security Personnel'),
                    Text('• ROL0005 - Driver'),
                    Text('• ROL0006 - System Owner'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Updated User Model with Role Reference
class UserModel {
  final String userId;
  final String firebaseUid;
  final String fullName;
  final String email;
  final String phone;
  final String schoolId;
  final String roleId; // Reference to roles collection
  final bool isActive;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.userId,
    required this.firebaseUid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.schoolId,
    required this.roleId,
    this.isActive = true,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'firebaseUid': firebaseUid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'schoolId': schoolId,
      'roleId': roleId, // Reference to roles/{roleId}
      'isActive': isActive,
      'isVerified': isVerified,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      firebaseUid: map['firebaseUid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      schoolId: map['schoolId'] ?? '',
      roleId: map['roleId'] ?? '',
      isActive: map['isActive'] ?? true,
      isVerified: map['isVerified'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Get user's role details
  Future<Map<String, dynamic>?> getRole() async {
    final initializer = FirestoreRolesInitializer();
    return await initializer.getRoleById(roleId);
  }

  /// Check if user has specific permission
  Future<bool> hasPermission(String resource, String action) async {
    final initializer = FirestoreRolesInitializer();
    return await initializer.userHasPermission(roleId, resource, action);
  }
}