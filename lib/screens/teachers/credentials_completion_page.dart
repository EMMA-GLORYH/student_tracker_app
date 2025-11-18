import 'package:flutter/material.dart';
import 'dart:io';

class CredentialsCompletionPage extends StatefulWidget {
  final String teacherId;
  final bool isForced;

  const CredentialsCompletionPage({
    super.key,
    required this.teacherId,
    required this.isForced,
  });

  @override
  State<CredentialsCompletionPage> createState() =>
      _CredentialsCompletionPageState();
}

class _CredentialsCompletionPageState
    extends State<CredentialsCompletionPage> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _ghanaCardController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyNameController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _yearsExpController = TextEditingController();

  String? selectedBloodGroup;
  File? ghanaCardPhoto;
  File? certificatePhoto;
  File? policeReportPhoto;

  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _ghanaCardController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _qualificationController.dispose();
    _yearsExpController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    // TODO: Implement image picker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$type image picker will be implemented here')),
    );
  }

  void _submitCredentials() {
    if (_formKey.currentState!.validate()) {
      if (ghanaCardPhoto == null ||
          certificatePhoto == null ||
          policeReportPhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload all required documents'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // TODO: Save to database
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text(
            'Your credentials have been submitted successfully. '
                'They will be reviewed by the administration.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.isForced) {
                  // TODO: Navigate back to login or dashboard
                  Navigator.pop(context);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.isForced) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must complete your credentials to continue'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Credentials'),
          backgroundColor: Colors.blue,
          automaticallyImplyLeading: !widget.isForced,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isForced)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Deactivated',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your account has been deactivated due to incomplete credentials. '
                                    'Please complete all required information to reactivate your account.',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name (as on Ghana Card)',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _ghanaCardController,
                  decoration: InputDecoration(
                    labelText: 'Ghana Card Number *',
                    prefixIcon: const Icon(Icons.credit_card),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    helperText: 'Format: GHA-XXXXXXXXX-X',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ghana Card Number is required';
                    }
                    if (!RegExp(r'^GHA-\d{9}-\d$').hasMatch(value)) {
                      return 'Invalid Ghana Card format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixText: '+233 ',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Residential Address',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: selectedBloodGroup,
                  decoration: InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: const Icon(Icons.bloodtype),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: bloodGroups.map((group) {
                    return DropdownMenuItem(
                      value: group,
                      child: Text(group),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedBloodGroup = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select your blood group';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                const Text(
                  'Emergency Contact',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emergencyNameController,
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter emergency contact name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emergencyPhoneController,
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact Phone',
                    prefixIcon: const Icon(Icons.phone_in_talk),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixText: '+233 ',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter emergency contact phone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                const Text(
                  'Professional Qualifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _qualificationController,
                  decoration: InputDecoration(
                    labelText: 'Highest Qualification',
                    prefixIcon: const Icon(Icons.school),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your qualification';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _yearsExpController,
                  decoration: InputDecoration(
                    labelText: 'Years of Teaching Experience',
                    prefixIcon: const Icon(Icons.work),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your years of experience';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                const Text(
                  'Required Documents *',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'These documents are critical for child safety verification',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),

                _buildDocumentUpload(
                  'Ghana Card Photo (Front & Back)',
                  'Upload clear photo of your Ghana Card',
                  Icons.credit_card,
                  ghanaCardPhoto,
                      () => _pickImage('Ghana Card'),
                ),
                const SizedBox(height: 12),

                _buildDocumentUpload(
                  'Teaching Certificate',
                  'Upload your teaching qualification certificate',
                  Icons.workspace_premium,
                  certificatePhoto,
                      () => _pickImage('Certificate'),
                ),
                const SizedBox(height: 12),

                _buildDocumentUpload(
                  'Police Clearance Report',
                  'Required for child protection verification',
                  Icons.security,
                  policeReportPhoto,
                      () => _pickImage('Police Report'),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitCredentials,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Submit Credentials',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentUpload(
      String title,
      String subtitle,
      IconData icon,
      File? file,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: file == null ? Colors.red.shade300 : Colors.green,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: file == null
              ? Colors.red.shade50
              : Colors.green.shade50,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: file == null
                    ? Colors.red.shade100
                    : Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: file == null ? Colors.red.shade700 : Colors.green.shade700,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file == null ? subtitle : 'Document uploaded ✓',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              file == null ? Icons.upload_file : Icons.check_circle,
              color: file == null ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}