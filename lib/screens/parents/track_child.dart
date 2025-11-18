import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// ✅ PROFESSIONAL CHILD TRACKING PAGE
/// - Navy blue color scheme (#0A1929)
/// - Real-time location tracking
/// - Location history with map markers
/// - Professional loading animations

class TrackChildPage extends StatefulWidget {
  final String childId;
  final String childName;
  final String parentId;

  const TrackChildPage({
    super.key,
    required this.childId,
    required this.childName,
    required this.parentId,
  });

  @override
  State<TrackChildPage> createState() => _TrackChildPageState();
}

class _TrackChildPageState extends State<TrackChildPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;

  late AnimationController _dotsController;

  LatLng _currentLocation = const LatLng(5.6037, -0.1870); // Default: Accra, Ghana
  String _currentStatus = 'Loading...';
  String _lastUpdated = 'N/A';
  Map<String, dynamic>? _childData;
  List<Map<String, dynamic>> _locationHistory = [];

  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _loadChildData();
    _startRealTimeTracking();
    _loadLocationHistory();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadChildData() async {
    try {
      // Load from students collection
      final studentDoc = await _firestore.collection('students').doc(widget.childId).get();

      if (studentDoc.exists) {
        setState(() {
          _childData = studentDoc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading child data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startRealTimeTracking() {
    _locationSubscription = _firestore
        .collection('students')
        .doc(widget.childId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final latitude = data['latitude'] ?? 5.6037;
        final longitude = data['longitude'] ?? -0.1870;
        final status = data['status'] ?? 'Unknown';

        setState(() {
          _currentLocation = LatLng(latitude, longitude);
          _currentStatus = status;
          _lastUpdated = _formatTimestamp(data['lastUpdated']);
        });

        // Animate camera to new location
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation),
        );
      }
    });
  }

  Future<void> _loadLocationHistory() async {
    try {
      final historySnapshot = await _firestore
          .collection('students')
          .doc(widget.childId)
          .collection('locationHistory')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      setState(() {
        _locationHistory = historySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'status': data['status'],
            'timestamp': data['timestamp'],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading location history: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dateTime = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _sendMessageToContact(String contactType) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => MessageDialog(contactType: contactType),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _firestore.collection('messages').add({
          'from': widget.parentId,
          'to': contactType,
          'childId': widget.childId,
          'childName': widget.childName,
          'message': result,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Message sent to $contactType!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending message: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _dotsController,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final delay = index * 0.2;
                      final value = (_dotsController.value + delay) % 1.0;
                      final offset = (value < 0.5 ? value * 2 : (1 - value) * 2) * 18;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Transform.translate(
                          offset: Offset(0, -offset),
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == 1 ? const Color(0xFF0A1929) : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: (index == 1 ? const Color(0xFF0A1929) : Colors.white).withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
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
              Text(
                'Loading tracking data...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Track ${widget.childName}', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadChildData();
              _loadLocationHistory();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusHeader(isDark),
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomSheet(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactOptions(isDark),
        backgroundColor: const Color(0xFF0A1929),
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1929), Color(0xFF1A2F3F)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1929).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(_currentStatus),
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(_currentStatus).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      _currentStatus,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _getStatusEmoji(_currentStatus),
                style: const TextStyle(fontSize: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip('Last Update', _lastUpdated),
              if (_childData != null)
                _buildInfoChip('Grade', _childData!['grade'] ?? 'N/A'),
              if (_childData != null)
                _buildInfoChip('Class', _childData!['classRoom'] ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentLocation,
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      markers: {
        Marker(
          markerId: MarkerId(widget.childId),
          position: _currentLocation,
          infoWindow: InfoWindow(
            title: widget.childName,
            snippet: _currentStatus,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _currentStatus.toLowerCase().contains('transit') || _currentStatus.toLowerCase().contains('bus')
                ? BitmapDescriptor.hueBlue
                : _currentStatus.toLowerCase().contains('school') || _currentStatus.toLowerCase().contains('class')
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueOrange,
          ),
        ),
      },
      polylines: _locationHistory.length > 1
          ? {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _locationHistory.map((loc) => LatLng(loc['latitude'], loc['longitude'])).toList(),
          color: const Color(0xFF0A1929),
          width: 3,
        ),
      }
          : {},
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildBottomSheet(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Location History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _loadLocationHistory,
                      child: const Text('Refresh', style: TextStyle(color: Color(0xFF0A1929))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: _locationHistory.isEmpty
                      ? Center(
                    child: Text(
                      'No history available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                      : ListView.builder(
                    itemCount: _locationHistory.length,
                    itemBuilder: (context, index) {
                      final location = _locationHistory[index];
                      return _buildHistoryItem(location, isDark);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> location, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(location['status']),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location['status'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatTimestamp(location['timestamp']),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.location_on, size: 18, color: Color(0xFF0A1929)),
            onPressed: () {
              final loc = LatLng(location['latitude'], location['longitude']);
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(loc, 16),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showContactOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send Message To',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildContactOption(
              icon: Icons.directions_bus,
              title: 'Driver',
              subtitle: _childData?['driver'] ?? 'Not assigned',
              onTap: () {
                Navigator.pop(context);
                _sendMessageToContact('Driver');
              },
            ),
            _buildContactOption(
              icon: Icons.school,
              title: 'Teacher',
              subtitle: 'Classroom teacher',
              onTap: () {
                Navigator.pop(context);
                _sendMessageToContact('Teacher');
              },
            ),
            _buildContactOption(
              icon: Icons.admin_panel_settings,
              title: 'School Admin',
              subtitle: 'School administration',
              onTap: () {
                Navigator.pop(context);
                _sendMessageToContact('School Admin');
              },
            ),
            _buildContactOption(
              icon: Icons.security,
              title: 'Security',
              subtitle: 'School security',
              onTap: () {
                Navigator.pop(context);
                _sendMessageToContact('Security');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1929).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF0A1929)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in transit':
      case 'on bus':
        return Colors.blue;
      case 'at school':
      case 'in class':
        return Colors.green;
      case 'at home':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusEmoji(String status) {
    switch (status.toLowerCase()) {
      case 'in transit':
      case 'on bus':
        return '🚐';
      case 'at school':
      case 'in class':
        return '📚';
      case 'at home':
        return '🏠';
      default:
        return '📍';
    }
  }
}

// ============================================================================
// MESSAGE DIALOG
// ============================================================================

class MessageDialog extends StatefulWidget {
  final String contactType;

  const MessageDialog({super.key, required this.contactType});

  @override
  State<MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<MessageDialog> {
  final _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Message to ${widget.contactType}'),
      content: TextField(
        controller: _messageController,
        decoration: const InputDecoration(
          hintText: 'Type your message...',
          border: OutlineInputBorder(),
        ),
        maxLines: 5,
        maxLength: 500,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_messageController.text.trim().isNotEmpty) {
              Navigator.pop(context, _messageController.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A1929),
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}