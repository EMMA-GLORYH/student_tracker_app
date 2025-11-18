import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// ✅ PROFESSIONAL STUDENT ASSIGNMENT VERIFICATION PAGE
/// - Review parent-child assignment requests
/// - Verify parent identity and relationship
/// - Approve or reject assignments
/// - Background checks and documentation review
/// - Navy blue color scheme matching admin dashboard

class VerifyStudentAssignmentPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final String adminId;
  final String adminName;

  const VerifyStudentAssignmentPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.adminId,
    required this.adminName,
  });

  @override
  State<VerifyStudentAssignmentPage> createState() =>
      _VerifyStudentAssignmentPageState();
}

class _VerifyStudentAssignmentPageState
    extends State<VerifyStudentAssignmentPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _dotsController;

  bool _isLoading = false;
  String _selectedFilter = 'pending'; // pending, approved, rejected, all

  // Navy Blue Colors (matching admin dashboard)
  static const Color navyDark = Color(0xFF0A1929);
  static const Color navyBlue = Color(0xFF1A2F3F);
  static const Color navyButton = Color(0xFF667eea);

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [navyDark, navyBlue],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildFilterTabs(),
                      Expanded(child: _buildRequestsList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assignment Verification',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verify parent-student relationships',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFilterTab('Pending', 'pending', Icons.pending_actions),
          _buildFilterTab('Approved', 'approved', Icons.check_circle),
          _buildFilterTab('Rejected', 'rejected', Icons.cancel),
          _buildFilterTab('All', 'all', Icons.list),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
              colors: [navyDark, navyBlue],
            )
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    Query query = _firestore
        .collection('childAssignments')
        .where('schoolId', isEqualTo: widget.schoolId);

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    // ✅ REMOVED: orderBy to avoid Firestore composite index requirement
    // Documents will appear in natural order (still functional)

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: navyButton,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading requests...',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: navyDark.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 64,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading requests',
                  style: TextStyle(
                    color: navyDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your connection',
                  style: TextStyle(
                    color: navyDark.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: navyDark.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getEmptyStateIcon(),
                    size: 64,
                    color: navyDark.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyStateTitle(),
                  style: TextStyle(
                    color: navyDark.withOpacity(0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getEmptyStateSubtitle(),
                  style: TextStyle(
                    color: navyDark.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildRequestCard(doc.id, data);
          },
        );
      },
    );
  }

  IconData _getEmptyStateIcon() {
    switch (_selectedFilter) {
      case 'pending':
        return Icons.pending_actions;
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.inbox;
    }
  }

  String _getEmptyStateTitle() {
    switch (_selectedFilter) {
      case 'pending':
        return 'No pending requests';
      case 'approved':
        return 'No approved requests';
      case 'rejected':
        return 'No rejected requests';
      default:
        return 'No requests found';
    }
  }

  String _getEmptyStateSubtitle() {
    switch (_selectedFilter) {
      case 'pending':
        return 'All assignment requests have been processed';
      case 'approved':
        return 'No assignments have been approved yet';
      case 'rejected':
        return 'No assignments have been rejected';
      default:
        return 'There are no assignment requests in the system';
    }
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'pending';
    final parentName = data['parentName'] as String? ?? 'Unknown Parent';
    final parentEmail = data['parentEmail'] as String? ?? 'N/A';
    final parentPhone = data['parentPhone'] as String? ?? 'N/A';
    final childName = data['childName'] as String? ?? 'Unknown Student';
    final childStudentId = data['childStudentId'] as String? ?? 'N/A';
    final childGrade = data['childGrade'] as String? ?? 'N/A';
    final relationship = data['relationship'] as String? ?? 'N/A';
    final requestedAt = data['requestedAt'] as Timestamp?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10b981);
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = const Color(0xFFef4444);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFf59e0b);
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            navyDark.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    statusIcon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assignment Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: navyDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        requestedAt != null
                            ? _formatDateTime(requestedAt.toDate())
                            : 'Date unknown',
                        style: TextStyle(
                          fontSize: 12,
                          color: navyDark.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Parent and Student Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: navyDark.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: navyDark.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Parent Section
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [navyDark, navyBlue],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            parentName.isNotEmpty ? parentName[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 14,
                                  color: navyButton,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'PARENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: navyButton,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              parentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: navyDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              parentEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: navyDark.withOpacity(0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              parentPhone,
                              style: TextStyle(
                                fontSize: 12,
                                color: navyDark.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: navyDark.withOpacity(0.1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: navyButton.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  size: 12,
                                  color: navyButton,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  relationship,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: navyButton,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: navyDark.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Student Section
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF06b6d4),
                              const Color(0xFF06b6d4).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            childName.isNotEmpty ? childName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.school,
                                  size: 14,
                                  color: Color(0xFF06b6d4),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'STUDENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF06b6d4),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              childName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: navyDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  'ID: $childStudentId',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: navyDark.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF06b6d4).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    childGrade,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF06b6d4),
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
                ],
              ),
            ),

            // Action Buttons (only for pending requests)
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showVerificationDialog(requestId, data),
                      icon: Icon(Icons.verified_user, size: 16, color: navyButton),
                      label: Text('Verify', style: TextStyle(color: navyButton)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navyButton,
                        side: BorderSide(color: navyButton, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10b981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10b981).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _approveAssignment(requestId, data),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectAssignment(requestId, data),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFef4444),
                        side: const BorderSide(
                          color: Color(0xFFef4444),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              _buildStatusInfo(status, data),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusInfo(String status, Map<String, dynamic> data) {
    final actionBy = status == 'approved'
        ? data['approvedBy'] as String?
        : data['rejectedBy'] as String?;
    final actionAt = status == 'approved'
        ? data['approvedAt'] as Timestamp?
        : data['rejectedAt'] as Timestamp?;
    final notes = data['verificationNotes'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: navyDark.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: navyDark.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: navyDark.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                status == 'approved' ? 'Approved by admin' : 'Rejected by admin',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: navyDark.withOpacity(0.8),
                ),
              ),
            ],
          ),
          if (actionAt != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatDateTime(actionAt.toDate()),
              style: TextStyle(
                fontSize: 12,
                color: navyDark.withOpacity(0.6),
              ),
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: $notes',
              style: TextStyle(
                fontSize: 12,
                color: navyDark.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showVerificationDialog(String requestId, Map<String, dynamic> data) {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [navyDark, navyBlue],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Verification Checklist',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: navyDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Info Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: navyDark.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: navyDark.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVerificationInfoRow(
                        Icons.person,
                        'Parent',
                        data['parentName'] ?? 'Unknown',
                      ),
                      const SizedBox(height: 8),
                      _buildVerificationInfoRow(
                        Icons.school,
                        'Student',
                        data['childName'] ?? 'Unknown',
                      ),
                      const SizedBox(height: 8),
                      _buildVerificationInfoRow(
                        Icons.family_restroom,
                        'Relationship',
                        data['relationship'] ?? 'N/A',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Verification Checklist
                const Text(
                  'Background Checks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 12),
                _buildChecklistItem('✓ Verify parent identity documents'),
                _buildChecklistItem('✓ Confirm student enrollment'),
                _buildChecklistItem('✓ Verify relationship claim'),
                _buildChecklistItem('✓ Check emergency contact authorization'),
                _buildChecklistItem('✓ Review tracking permissions'),
                const SizedBox(height: 20),

                // Notes
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Verification Notes (Optional)',
                    hintText: 'Add any observations or concerns...',
                    prefixIcon: Icon(Icons.note, color: navyButton),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: navyButton, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [navyDark, navyBlue],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: navyDark.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _approveAssignment(requestId, data, notesController.text);
                          },
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('Complete & Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
      ),
    );
  }

  Widget _buildVerificationInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: navyDark.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: navyDark.withOpacity(0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: navyDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: navyButton,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: navyDark.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveAssignment(
      String requestId,
      Map<String, dynamic> data, [
        String? notes,
      ]) async {
    try {
      setState(() => _isLoading = true);

      // Update assignment status
      await _firestore.collection('childAssignments').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': widget.adminId,
        'verificationNotes': notes ?? '',
      });

      // Send notification to parent
      await _firestore.collection('notifications').add({
        'userId': data['parentId'],
        'userType': 'parent',
        'type': 'assignment_approved',
        'title': 'Assignment Approved',
        'message':
        'Your request to assign ${data['childName']} has been approved. You can now track your child.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'assignmentId': requestId,
          'studentId': data['studentId'],
        },
      });

      // Send email notification
      await _firestore.collection('mail').add({
        'to': [data['parentEmail']],
        'message': {
          'subject': 'Child Assignment Approved - ${widget.schoolName}',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #10b981;">Assignment Approved!</h2>
              <p>Hello ${data['parentName']},</p>
              <p>Great news! Your request to assign ${data['childName']} has been approved by the school administrator.</p>
              <p>You can now:</p>
              <ul>
                <li>View your child's real-time location</li>
                <li>Receive safety notifications</li>
                <li>Access attendance records</li>
              </ul>
              <br>
              <p>Best regards,<br>${widget.schoolName}</p>
            </div>
          ''',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Assignment approved successfully',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error approving assignment: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFef4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _rejectAssignment(
      String requestId, Map<String, dynamic> data) async {
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFef4444).withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFef4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reject Assignment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Reject ${data['parentName']}\'s request to assign ${data['childName']}?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for rejection',
                  hintText: 'Provide a reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFef4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      // Update assignment status
      await _firestore.collection('childAssignments').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': widget.adminId,
        'rejectionReason': reasonController.text.trim(),
      });

      // Send notification to parent
      await _firestore.collection('notifications').add({
        'userId': data['parentId'],
        'userType': 'parent',
        'type': 'assignment_rejected',
        'title': 'Assignment Request Rejected',
        'message':
        'Your request to assign ${data['childName']} was not approved. Please contact school administration for more information.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'assignmentId': requestId,
          'studentId': data['studentId'],
        },
      });

      // Send email notification
      await _firestore.collection('mail').add({
        'to': [data['parentEmail']],
        'message': {
          'subject': 'Assignment Request Update - ${widget.schoolName}',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #ef4444;">Assignment Request Not Approved</h2>
              <p>Hello ${data['parentName']},</p>
              <p>We regret to inform you that your request to assign ${data['childName']} was not approved.</p>
              ${reasonController.text.trim().isNotEmpty ? '<p><strong>Reason:</strong> ${reasonController.text.trim()}</p>' : ''}
              <p>If you believe this is an error or have questions, please contact the school administration.</p>
              <br>
              <p>Best regards,<br>${widget.schoolName}</p>
            </div>
          ''',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(
                  'Assignment request rejected',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFf59e0b),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error rejecting assignment: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFef4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
  }
}