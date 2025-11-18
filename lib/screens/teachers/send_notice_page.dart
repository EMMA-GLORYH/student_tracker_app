import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SendNoticePage extends StatefulWidget {
  final String teacherId;

  const SendNoticePage({super.key, required this.teacherId});

  @override
  State<SendNoticePage> createState() => _SendNoticePageState();
}

class _SendNoticePageState extends State<SendNoticePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String selectedRecipient = 'All Parents';
  String selectedPriority = 'Normal';
  String selectedClass = 'All Classes';

  final List<String> recipients = [
    'All Parents',
    'Specific Class',
    'Individual Parent',
  ];

  final List<String> priorities = ['Normal', 'Important', 'Urgent'];

  final List<String> classes = [
    'All Classes',
    'Class 1A',
    'Class 1B',
    'Class 2A',
    'Class 2B'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendNotice() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Send'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To: $selectedRecipient'),
              if (selectedRecipient == 'Specific Class')
                Text('Class: $selectedClass'),
              Text('Priority: $selectedPriority'),
              const SizedBox(height: 8),
              const Text('Send this notice?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Send to database
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notice sent successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Send'),
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
        title: const Text('Send Notice'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice Type Section
              const Text(
                'Notice Configuration',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Recipients
              DropdownButtonFormField<String>(
                value: selectedRecipient,
                decoration: InputDecoration(
                  labelText: 'Send To',
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: recipients.map((recipient) {
                  return DropdownMenuItem(
                    value: recipient,
                    child: Text(recipient),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRecipient = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Class Selection (conditional)
              if (selectedRecipient == 'Specific Class')
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedClass,
                      decoration: InputDecoration(
                        labelText: 'Select Class',
                        prefixIcon: const Icon(Icons.class_),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: classes.map((classItem) {
                        return DropdownMenuItem(
                          value: classItem,
                          child: Text(classItem),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClass = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Priority
              DropdownButtonFormField<String>(
                value: selectedPriority,
                decoration: InputDecoration(
                  labelText: 'Priority Level',
                  prefixIcon: Icon(
                    _getPriorityIcon(selectedPriority),
                    color: _getPriorityColor(selectedPriority),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: priorities.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Row(
                      children: [
                        Icon(
                          _getPriorityIcon(priority),
                          size: 20,
                          color: _getPriorityColor(priority),
                        ),
                        const SizedBox(width: 8),
                        Text(priority),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPriority = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Notice Content
              const Text(
                'Notice Content',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Notice Title',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'e.g., Parent-Teacher Meeting',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter notice title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Message
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  prefixIcon: const Icon(Icons.message),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'Type your message here...',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your message';
                  }
                  if (value.length < 10) {
                    return 'Message should be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Quick Templates
              const Text(
                'Quick Templates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTemplateChip('Meeting Notice'),
                  _buildTemplateChip('Homework Reminder'),
                  _buildTemplateChip('Event Announcement'),
                  _buildTemplateChip('Absence Notification'),
                ],
              ),
              const SizedBox(height: 32),

              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendNotice,
                  icon: const Icon(Icons.send),
                  label: const Text(
                    'Send Notice',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Notices
              const Text(
                'Recent Notices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentNoticeCard(
                'Parent-Teacher Meeting',
                'Sent to: All Parents',
                'Oct 15, 2025',
                'Important',
              ),
              _buildRecentNoticeCard(
                'Homework Reminder',
                'Sent to: Class 1A',
                'Oct 14, 2025',
                'Normal',
              ),
              _buildRecentNoticeCard(
                'School Trip Announcement',
                'Sent to: All Parents',
                'Oct 12, 2025',
                'Urgent',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String label) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.insert_drive_file, size: 18),
      onPressed: () {
        _applyTemplate(label);
      },
      backgroundColor: Colors.grey.shade200,
    );
  }

  void _applyTemplate(String template) {
    switch (template) {
      case 'Meeting Notice':
        _titleController.text = 'Parent-Teacher Meeting';
        _messageController.text =
        'Dear Parents/Guardians,\n\nYou are cordially invited to attend the Parent-Teacher Meeting scheduled for [Date] at [Time].\n\nWe look forward to discussing your child\'s progress.\n\nBest regards,\n${widget.teacherId}';
        break;
      case 'Homework Reminder':
        _titleController.text = 'Homework Reminder';
        _messageController.text =
        'Dear Parents/Guardians,\n\nThis is a reminder that homework assignments are due by [Date].\n\nPlease ensure your child completes and submits their work on time.\n\nThank you.';
        break;
      case 'Event Announcement':
        _titleController.text = 'Upcoming School Event';
        _messageController.text =
        'Dear Parents/Guardians,\n\nWe are excited to announce [Event Name] on [Date].\n\nMore details will follow soon.\n\nThank you.';
        break;
      case 'Absence Notification':
        _titleController.text = 'Student Absence Notice';
        _messageController.text =
        'Dear Parents/Guardians,\n\nYour child was absent from class today. If this was unexpected, please contact us.\n\nThank you.';
        break;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$template applied')),
    );
  }

  Widget _buildRecentNoticeCard(
      String title,
      String subtitle,
      String date,
      String priority,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor(priority).withOpacity(0.1),
          child: Icon(
            _getPriorityIcon(priority),
            color: _getPriorityColor(priority),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 2),
            Text(
              date,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getPriorityColor(priority).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            priority,
            style: TextStyle(
              color: _getPriorityColor(priority),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'Urgent':
        return Icons.priority_high;
      case 'Important':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return Colors.red;
      case 'Important':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}