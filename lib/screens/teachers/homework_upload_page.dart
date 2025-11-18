import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class HomeworkUploadPage extends StatefulWidget {
  final String teacherId;

  const HomeworkUploadPage({super.key, required this.teacherId});

  @override
  State<HomeworkUploadPage> createState() => _HomeworkUploadPageState();
}

class _HomeworkUploadPageState extends State<HomeworkUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String selectedClass = 'Class 1A';
  String selectedSubject = 'Mathematics';
  DateTime dueDate = DateTime.now().add(const Duration(days: 7));
  File? attachedFile;

  final List<String> classes = ['Class 1A', 'Class 1B', 'Class 2A', 'Class 2B'];
  final List<String> subjects = ['Mathematics', 'English', 'Science', 'Social Studies'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        dueDate = picked;
      });
    }
  }

  Future<void> _attachFile() async {
    // TODO: Implement file picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File picker will be implemented here')),
    );
  }

  void _uploadHomework() {
    if (_formKey.currentState!.validate()) {
      // TODO: Upload to database
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Homework has been uploaded successfully!'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Homework'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Homework Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Class Selection
              DropdownButtonFormField<String>(
                value: selectedClass,
                decoration: InputDecoration(
                  labelText: 'Select Class',
                  prefixIcon: const Icon(Icons.class_),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: classes.map((className) {
                  return DropdownMenuItem(
                    value: className,
                    child: Text(className),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedClass = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Subject Selection
              DropdownButtonFormField<String>(
                value: selectedSubject,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: const Icon(Icons.book),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: subjects.map((subject) {
                  return DropdownMenuItem(
                    value: subject,
                    child: Text(subject),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSubject = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Homework Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Homework Title',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'e.g., Chapter 5 Exercises',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter homework title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description/Instructions',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'Provide detailed instructions...',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter homework description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Due Date
              InkWell(
                onTap: _selectDueDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.green),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Due Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMM dd, yyyy').format(dueDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Attach File
              InkWell(
                onTap: _attachFile,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: attachedFile == null
                          ? Colors.grey.shade400
                          : Colors.green,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: attachedFile == null
                        ? Colors.grey.shade50
                        : Colors.green.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        attachedFile == null
                            ? Icons.attach_file
                            : Icons.check_circle,
                        color: attachedFile == null
                            ? Colors.grey.shade600
                            : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachedFile == null
                                  ? 'Attach File (Optional)'
                                  : 'File Attached',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: attachedFile == null
                                    ? Colors.grey.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attachedFile == null
                                  ? 'PDF, DOC, or Image files'
                                  : 'homework_file.pdf',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Upload Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploadHomework,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text(
                    'Upload Homework',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Uploads
              const Text(
                'Recent Uploads',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentHomeworkCard(
                'Chapter 4 Review',
                'Class 1A - Mathematics',
                'Due: Oct 25, 2025',
              ),
              _buildRecentHomeworkCard(
                'Essay Writing',
                'Class 2B - English',
                'Due: Oct 22, 2025',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentHomeworkCard(String title, String subtitle, String dueDate) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.assignment, color: Colors.green.shade700),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              dueDate,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}