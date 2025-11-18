import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class VisitorManagementScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String schoolId;

  const VisitorManagementScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.schoolId,
  });

  @override
  State<VisitorManagementScreen> createState() => _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _purposeController = TextEditingController();
  final _personToMeetController = TextEditingController();

  bool _isLoading = false;
  String _selectedIdType = 'National ID';
  File? _visitorPhoto;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _todayVisitors = [];
  List<Map<String, dynamic>> _activeVisitors = [];

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _purposeController.dispose();
    _personToMeetController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitors() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get today's visitors
      final todaySnapshot = await _firestore
          .collection('visitors')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('visitDate', descending: true)
          .get();

      // Get active visitors (not yet checked out)
      final activeSnapshot = await _firestore
          .collection('visitors')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('status', isEqualTo: 'active')
          .get();

      if (mounted) {
        setState(() {
          _todayVisitors = todaySnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _activeVisitors = activeSnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading visitors: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _visitorPhoto = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error capturing photo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _registerVisitor() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_visitorPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a photo of the visitor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate visitor badge number
      final badgeNumber = 'VIS${DateTime.now().millisecondsSinceEpoch}';

      final visitorData = {
        'badgeNumber': badgeNumber,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'idType': _selectedIdType,
        'idNumber': _idNumberController.text.trim(),
        'purpose': _purposeController.text.trim(),
        'personToMeet': _personToMeetController.text.trim(),
        'schoolId': widget.schoolId,
        'registeredBy': widget.userId,
        'registeredByName': widget.userName,
        'visitDate': FieldValue.serverTimestamp(),
        'checkInTime': FieldValue.serverTimestamp(),
        'checkOutTime': null,
        'status': 'active',
        'photoPath': _visitorPhoto?.path ?? '',
      };

      await _firestore.collection('visitors').add(visitorData);

      // Log activity
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity': 'Registered visitor: ${_nameController.text.trim()}',
        'type': 'visitor',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Notify person to meet
      await _notifyPersonToMeet();

      await _loadVisitors();

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visitor registered - Badge: $badgeNumber'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error registering visitor: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error registering visitor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _notifyPersonToMeet() async {
    try {
      final personName = _personToMeetController.text.trim();

      // Search for the person in users collection
      final usersSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('fullName', isEqualTo: personName)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isNotEmpty) {
        final userId = usersSnapshot.docs.first.id;

        await _firestore.collection('notifications').add({
          'userId': userId,
          'title': 'Visitor Arrival',
          'message': '${_nameController.text.trim()} is here to meet you. Purpose: ${_purposeController.text.trim()}',
          'type': 'visitor',
          'priority': 'normal',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error notifying person: $e');
    }
  }

  Future<void> _checkOutVisitor(Map<String, dynamic> visitor) async {
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('visitors').doc(visitor['id']).update({
        'checkOutTime': FieldValue.serverTimestamp(),
        'status': 'completed',
        'checkedOutBy': widget.userId,
        'checkedOutByName': widget.userName,
      });

      // Log activity
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity': 'Checked out visitor: ${visitor['name']}',
        'type': 'visitor',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _loadVisitors();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitor checked out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking out visitor: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error checking out visitor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRegisterVisitorDialog() {
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _idNumberController.clear();
    _purposeController.clear();
    _personToMeetController.clear();
    _visitorPhoto = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Register Visitor',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Photo capture
                  Center(
                    child: GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: _visitorPhoto != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _visitorPhoto!,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Take Photo',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value?.isEmpty ?? true ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value?.isEmpty ?? true ? 'Phone is required' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _selectedIdType,
                    decoration: const InputDecoration(
                      labelText: 'ID Type',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'National ID', child: Text('National ID')),
                      DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                      DropdownMenuItem(value: 'Driver License', child: Text('Driver License')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedIdType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _idNumberController,
                    decoration: const InputDecoration(
                      labelText: 'ID Number *',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value?.isEmpty ?? true ? 'ID number is required' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _purposeController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Purpose of Visit *',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value?.isEmpty ?? true ? 'Purpose is required' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _personToMeetController,
                    decoration: const InputDecoration(
                      labelText: 'Person to Meet *',
                      prefixIcon: Icon(Icons.person_search),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value?.isEmpty ?? true ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registerVisitor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('Register'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showVisitorDetails(Map<String, dynamic> visitor) {
    final checkInTime = visitor['checkInTime'] as Timestamp?;
    final checkOutTime = visitor['checkOutTime'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.badge,
                      size: 32,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visitor['name'] ?? 'Unknown Visitor',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Badge: ${visitor['badgeNumber'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: visitor['status'] == 'active'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      visitor['status'] == 'active' ? 'IN' : 'OUT',
                      style: TextStyle(
                        color: visitor['status'] == 'active' ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Phone', visitor['phone'] ?? 'N/A', Icons.phone),
              _buildInfoRow('Email', visitor['email'] ?? 'N/A', Icons.email),
              _buildInfoRow('ID Type', visitor['idType'] ?? 'N/A', Icons.badge),
              _buildInfoRow('ID Number', visitor['idNumber'] ?? 'N/A', Icons.credit_card),
              _buildInfoRow('Purpose', visitor['purpose'] ?? 'N/A', Icons.description),
              _buildInfoRow('Meeting', visitor['personToMeet'] ?? 'N/A', Icons.person),
              _buildInfoRow(
                'Check In',
                checkInTime != null
                    ? DateFormat('hh:mm a').format(checkInTime.toDate())
                    : 'N/A',
                Icons.login,
              ),
              if (checkOutTime != null)
                _buildInfoRow(
                  'Check Out',
                  DateFormat('hh:mm a').format(checkOutTime.toDate()),
                  Icons.logout,
                ),
              const SizedBox(height: 24),
              if (visitor['status'] == 'active')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _checkOutVisitor(visitor);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Check Out Visitor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Management'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Today',
                    _todayVisitors.length.toString(),
                    Icons.today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Active',
                    _activeVisitors.length.toString(),
                    Icons.people,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _todayVisitors.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.badge, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No visitors today',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _todayVisitors.length,
              itemBuilder: (context, index) {
                final visitor = _todayVisitors[index];
                final isActive = visitor['status'] == 'active';
                final checkInTime = visitor['checkInTime'] as Timestamp?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.badge,
                        color: Colors.purple,
                      ),
                    ),
                    title: Text(
                      visitor['name'] ?? 'Unknown Visitor',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Badge: ${visitor['badgeNumber'] ?? 'N/A'}'),
                        Text('Purpose: ${visitor['purpose'] ?? 'N/A'}'),
                        if (checkInTime != null)
                          Text(
                            'Time: ${DateFormat('hh:mm a').format(checkInTime.toDate())}',
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'IN' : 'OUT',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () => _showVisitorDetails(visitor),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterVisitorDialog,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add),
        label: const Text('Register Visitor'),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}