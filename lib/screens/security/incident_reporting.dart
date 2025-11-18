import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class IncidentReportingScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String schoolId;

  const IncidentReportingScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.schoolId,
  });

  @override
  State<IncidentReportingScreen> createState() => _IncidentReportingScreenState();
}

class _IncidentReportingScreenState extends State<IncidentReportingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _involvedPartiesController = TextEditingController();

  bool _isLoading = false;
  String _selectedCategory = 'security_breach';
  String _selectedSeverity = 'medium';
  List<File> _photos = [];
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _recentIncidents = [];

  final List<String> _categories = [
    'security_breach',
    'theft',
    'vandalism',
    'fight',
    'bullying',
    'property_damage',
    'unauthorized_access',
    'safety_hazard',
    'other',
  ];

  final List<String> _severityLevels = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _involvedPartiesController.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    try {
      final snapshot = await _firestore
          .collection('incidents')
          .where('schoolId', isEqualTo: widget.schoolId)
          .orderBy('reportedAt', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          _recentIncidents = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading incidents: $e');
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null && _photos.length < 5) {
        setState(() {
          _photos.add(File(photo.path));
        });
      } else if (_photos.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 photos allowed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding photo: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final incidentNumber = 'INC${DateTime.now().millisecondsSinceEpoch}';

      final incidentData = {
        'incidentNumber': incidentNumber,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'severity': _selectedSeverity,
        'location': _locationController.text.trim(),
        'involvedParties': _involvedPartiesController.text.trim(),
        'schoolId': widget.schoolId,
        'reportedBy': widget.userId,
        'reportedByName': widget.userName,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'open',
        'photoCount': _photos.length,
        'photoPaths': _photos.map((f) => f.path).toList(),
        'followUpNotes': [],
      };

      await _firestore.collection('incidents').add(incidentData);

      // Log activity
      await _firestore.collection('securityLogs').add({
        'schoolId': widget.schoolId,
        'securityPersonnelId': widget.userId,
        'securityPersonnelName': widget.userName,
        'activity': 'Reported incident: ${_titleController.text.trim()}',
        'type': 'incident',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Notify administrators
      await _notifyAdministrators(incidentNumber);

      await _loadIncidents();

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incident reported - #$incidentNumber'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting report: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error submitting report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _notifyAdministrators(String incidentNumber) async {
    try {
      final adminsSnapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: widget.schoolId)
          .where('roleId', whereIn: ['ROL0001', 'ROL0006'])
          .get();

      for (var admin in adminsSnapshot.docs) {
        await _firestore.collection('notifications').add({
          'userId': admin.id,
          'title': 'New Incident Report',
          'message':
          'Incident #$incidentNumber reported by ${widget.userName}. Category: ${_formatCategory(_selectedCategory)}',
          'type': 'incident',
          'priority': _selectedSeverity == 'critical' || _selectedSeverity == 'high'
              ? 'high'
              : 'normal',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error notifying administrators: $e');
    }
  }

  void _showReportDialog() {
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _involvedPartiesController.clear();
    _photos.clear();

    setState(() {
      _selectedCategory = 'security_breach';
      _selectedSeverity = 'medium';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 650),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Incident',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Incident Title *',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(_formatCategory(category)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => _selectedCategory = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedSeverity,
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                        prefixIcon: Icon(Icons.warning),
                        border: OutlineInputBorder(),
                      ),
                      items: _severityLevels.map((severity) {
                        return DropdownMenuItem(
                          value: severity,
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 12,
                                color: _getSeverityColor(severity),
                              ),
                              const SizedBox(width: 8),
                              Text(severity.toUpperCase()),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => _selectedSeverity = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location *',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Location is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) =>
                      value?.isEmpty ?? true ? 'Description is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _involvedPartiesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Involved Parties (Optional)',
                        prefixIcon: Icon(Icons.people),
                        border: OutlineInputBorder(),
                        hintText: 'Names of people involved...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Photos (Optional - Max 5)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._photos.asMap().entries.map((entry) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  entry.value,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() => _removePhoto(entry.key));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        if (_photos.length < 5)
                          GestureDetector(
                            onTap: () => _showPhotoOptions(setDialogState),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: const Icon(
                                Icons.add_a_photo,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
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
                            onPressed: _isLoading ? null : _submitReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
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
                                : const Text('Submit'),
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
      ),
    );
  }

  void _showPhotoOptions(StateSetter setDialogState) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.camera).then((_) {
                  setDialogState(() {});
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.gallery).then((_) {
                  setDialogState(() {});
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showIncidentDetails(Map<String, dynamic> incident) {
    final reportedAt = incident['reportedAt'] as Timestamp?;

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
                      color: _getSeverityColor(incident['severity'] ?? 'medium')
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.report,
                      size: 32,
                      color: _getSeverityColor(incident['severity'] ?? 'medium'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident['title'] ?? 'Unknown Incident',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#${incident['incidentNumber'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(incident['status'] ?? 'open')
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (incident['status'] ?? 'open').toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(incident['status'] ?? 'open'),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow(
                'Category',
                _formatCategory(incident['category'] ?? 'Unknown'),
                Icons.category,
              ),
              _buildInfoRow(
                'Severity',
                (incident['severity'] ?? 'Unknown').toUpperCase(),
                Icons.warning,
              ),
              _buildInfoRow(
                'Location',
                incident['location'] ?? 'Unknown',
                Icons.location_on,
              ),
              _buildInfoRow(
                'Reported By',
                incident['reportedByName'] ?? 'Unknown',
                Icons.person,
              ),
              _buildInfoRow(
                'Reported At',
                reportedAt != null
                    ? DateFormat('MMM d, yyyy hh:mm a').format(reportedAt.toDate())
                    : 'Unknown',
                Icons.access_time,
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  incident['description'] ?? 'No description',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (incident['involvedParties']?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text(
                  'Involved Parties',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    incident['involvedParties'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              if ((incident['photoCount'] ?? 0) > 0) ...[
                const SizedBox(height: 16),
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${incident['photoCount']} photo(s) attached',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
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

  String _formatCategory(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red[900]!;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'investigating':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Reports'),
        backgroundColor: Colors.red,
      ),
      body: _recentIncidents.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No incidents reported',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recentIncidents.length,
        itemBuilder: (context, index) {
          final incident = _recentIncidents[index];
          final reportedAt = incident['reportedAt'] as Timestamp?;
          final severity = incident['severity'] ?? 'medium';
          final status = incident['status'] ?? 'open';

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
                  color: _getSeverityColor(severity).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.report,
                  color: _getSeverityColor(severity),
                ),
              ),
              title: Text(
                incident['title'] ?? 'Unknown Incident',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('#${incident['incidentNumber'] ?? 'N/A'}'),
                  Text(
                    'Category: ${_formatCategory(incident['category'] ?? 'Unknown')}',
                  ),
                  if (reportedAt != null)
                    Text(
                      DateFormat('MMM d, hh:mm a').format(reportedAt.toDate()),
                    ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              onTap: () => _showIncidentDetails(incident),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportDialog,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.report),
        label: const Text('Report Incident'),
      ),
    );
  }
}