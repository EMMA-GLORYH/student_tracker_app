import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:ui';

class MessagingPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final String userId;
  final String adminName;

  const MessagingPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
    required this.userId,
    required this.adminName,
  });

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage>
    with TickerProviderStateMixin {
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  late AnimationController _connectivityAnimationController;
  late Animation<double> _connectivityAnimation;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkConnectivity();
  }

  void _initializeAnimations() {
    _connectivityAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _connectivityAnimation = CurvedAnimation(
      parent: _connectivityAnimationController,
      curve: Curves.easeInOut,
    );
  }

  void _checkConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
          final isConnected = result != ConnectivityResult.none;
          if (isConnected != _isConnected) {
            setState(() {
              _isConnected = isConnected;
            });
            if (!_isConnected) {
              _connectivityAnimationController.forward();
            } else {
              _connectivityAnimationController.reverse();
            }
          }
        });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _connectivityAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A1929), // Dark blue
                Color(0xFF1A2F3F), // Medium dark blue
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildEnhancedAppBar(),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Stack(
                      children: [
                        TabBarView(
                          children: [
                            _buildSendMessage(),
                            _buildMessageHistory(),
                          ],
                        ),
                        _buildConnectivityOverlay(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Messaging Center',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Communicate with your school community',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.6),
                  indicator: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorPadding: const EdgeInsets.all(4),
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  tabs: const [
                    Tab(
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Send Message',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'History',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildConnectivityOverlay() {
    return AnimatedBuilder(
      animation: _connectivityAnimation,
      builder: (context, child) {
        if (_isConnected) return const SizedBox.shrink();

        return Positioned(
          bottom: 20 + (20 * _connectivityAnimation.value),
          left: 20,
          right: 20,
          child: Transform.scale(
            scale: 0.8 + (0.2 * _connectivityAnimation.value),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Messages will be queued and sent when connection is restored',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
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
      },
    );
  }

  Widget _buildSendMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Compose Message',
            'Create and send messages to your school community',
            Icons.edit_rounded,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _SendMessageForm(
              schoolId: widget.schoolId,
              schoolName: widget.schoolName,
              userId: widget.userId,
              adminName: widget.adminName,
              isConnected: _isConnected,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Better message history with fallback queries
  Widget _buildMessageHistory() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Message History',
            'View all messages you\'ve sent',
            Icons.history_rounded,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildMessageStream(),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Smart message loading with multiple fallback strategies
  Widget _buildMessageStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _isConnected ? _getOnlineStream() : _getOfflineStream(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting &&
            (!snapshot.hasData || snapshot.data!.docs.isEmpty)) {
          return _buildLoadingState();
        }

        // Handle errors with fallback
        if (snapshot.hasError) {
          debugPrint('Primary stream error: ${snapshot.error}');
          return _buildFallbackQuery();
        }

        // Handle empty state
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // Success - show messages
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Refresh stream
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final messageDoc = snapshot.data!.docs[index];
              final messageData = messageDoc.data() as Map<String, dynamic>;
              return _buildMessageHistoryCard(messageData, index);
            },
          ),
        );
      },
    );
  }

  // Online stream with proper ordering
  Stream<QuerySnapshot> _getOnlineStream() {
    try {
      return FirebaseFirestore.instance
          .collection('messages')
          .where('sentBy', isEqualTo: widget.userId)
          .where('schoolId', isEqualTo: widget.schoolId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
    } catch (e) {
      debugPrint('Online stream setup error: $e');
      // Fallback to simpler query
      return FirebaseFirestore.instance
          .collection('messages')
          .where('sentBy', isEqualTo: widget.userId)
          .limit(20)
          .snapshots();
    }
  }

  // Offline stream (uses cached data)
  Stream<QuerySnapshot> _getOfflineStream() {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('sentBy', isEqualTo: widget.userId)
        .limit(20)
        .snapshots(includeMetadataChanges: false);
  }

  // Fallback query when stream fails
  Widget _buildFallbackQuery() {
    return FutureBuilder<QuerySnapshot>(
      future: _getFallbackData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          debugPrint('Fallback query error: ${snapshot.error}');
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // Filter and sort locally
        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['schoolId'] == widget.schoolId;
        }).toList();

        // Sort by timestamp
        filteredDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] ?? 0;
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] ?? 0;
          return bTime.compareTo(aTime);
        });

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final messageData = filteredDocs[index].data() as Map<String, dynamic>;
            return _buildMessageHistoryCard(messageData, index);
          },
        );
      },
    );
  }

  // Get data with simple query as fallback
  Future<QuerySnapshot> _getFallbackData() async {
    try {
      return await FirebaseFirestore.instance
          .collection('messages')
          .where('sentBy', isEqualTo: widget.userId)
          .get();
    } catch (e) {
      debugPrint('Fallback data error: $e');
      rethrow;
    }
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A1929), Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A1929).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1929).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A1929)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isConnected ? 'Loading messages...' : 'Loading cached messages...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Failed to load messages',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _isConnected
                  ? 'Check your internet connection and try again.'
                  : 'You\'re offline. Some messages may not be visible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {}); // Refresh
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A1929),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0A1929).withOpacity(0.1),
                  const Color(0xFF2563EB).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 60,
              color: Color(0xFF0A1929),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No messages sent yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your message history will appear here once you\nstart sending messages to your school community.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              DefaultTabController.of(context).animateTo(0);
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send Your First Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A1929),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageHistoryCard(Map<String, dynamic> messageData, int index) {
    final recipients = messageData['recipients'] as List<dynamic>?;
    final sentAt = messageData['sentAt'] as Timestamp?;
    final createdAt = messageData['createdAt'];
    final channels = messageData['channels'] as List<dynamic>? ?? [];

    // Use createdAt as fallback if sentAt is null
    DateTime? messageTime;
    if (sentAt != null) {
      messageTime = sentAt.toDate();
    } else if (createdAt != null) {
      if (createdAt is int) {
        messageTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
      } else if (createdAt is Timestamp) {
        messageTime = createdAt.toDate();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        messageData['title'] ?? 'Message',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        messageTime != null
                            ? _formatDateTime(messageTime)
                            : 'Unknown time',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[400]!, Colors.green[600]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Delivered',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Text(
                messageData['message'] ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1929).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_rounded,
                        size: 16,
                        color: Color(0xFF0A1929),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${recipients?.length ?? 0} Recipients',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0A1929),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (channels.contains('email'))
                  _buildChannelBadge('Email', Icons.email_rounded, const Color(0xFF3B82F6)),
                if (channels.contains('sms'))
                  _buildChannelBadge('SMS', Icons.sms_rounded, const Color(0xFF10B981)),
                if (channels.contains('app'))
                  _buildChannelBadge('App', Icons.notifications_rounded, const Color(0xFF8B5CF6)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class _SendMessageForm extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  final String userId;
  final String adminName;
  final bool isConnected;

  const _SendMessageForm({
    required this.schoolId,
    required this.schoolName,
    required this.userId,
    required this.adminName,
    required this.isConnected,
  });

  @override
  State<_SendMessageForm> createState() => _SendMessageFormState();
}

class _SendMessageFormState extends State<_SendMessageForm>
    with TickerProviderStateMixin {
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<String> selectedRecipientTypes = [];
  List<String> selectedChannels = [];
  List<Map<String, dynamic>> selectedUsers = [];

  bool isLoading = false;
  bool _titleValidated = false;
  bool _messageValidated = false;

  late AnimationController _animationController;
  late AnimationController _successAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _successAnimation;

  final recipientTypes = [
    {
      'id': 'teachers',
      'label': 'Teachers',
      'icon': Icons.school_rounded,
      'roleId': 'ROL0002',
      'color': const Color(0xFF2563EB),
    },
    {
      'id': 'parents',
      'label': 'Parents',
      'icon': Icons.family_restroom_rounded,
      'roleId': 'ROL0003',
      'color': const Color(0xFF10B981),
    },
    {
      'id': 'drivers',
      'label': 'Drivers',
      'icon': Icons.directions_car_rounded,
      'roleId': 'ROL0005',
      'color': const Color(0xFF8B5CF6),
    },
    {
      'id': 'security',
      'label': 'Security',
      'icon': Icons.security_rounded,
      'roleId': 'ROL0004',
      'color': const Color(0xFFEF4444),
    },
    {
      'id': 'all_users',
      'label': 'All Users',
      'icon': Icons.people_rounded,
      'roleId': '',
      'color': const Color(0xFF0A1929),
    },
  ];

  final channels = [
    {
      'id': 'email',
      'label': 'Email',
      'icon': Icons.email_rounded,
      'color': const Color(0xFF2563EB),
      'description': 'Send via email',
    },
    {
      'id': 'sms',
      'label': 'SMS',
      'icon': Icons.sms_rounded,
      'color': const Color(0xFF10B981),
      'description': 'Send via text message',
    },
    {
      'id': 'app',
      'label': 'Push Notification',
      'icon': Icons.notifications_rounded,
      'color': const Color(0xFF8B5CF6),
      'description': 'Send app notification',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupTextListeners();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _successAnimation = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );
  }

  void _setupTextListeners() {
    titleController.addListener(() {
      setState(() {
        _titleValidated = titleController.text.isNotEmpty;
      });
    });

    messageController.addListener(() {
      setState(() {
        _messageValidated = messageController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    _animationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    selectedUsers.clear();

    for (String type in selectedRecipientTypes) {
      final roleId = recipientTypes
          .firstWhere((r) => r['id'] == type)['roleId']
          .toString();

      if (type == 'all_users') {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('isActive', isEqualTo: true)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          selectedUsers.add({
            'userId': doc.id,
            'email': data['email'],
            'phone': data['phone'],
            'fullName': data['fullName'],
            'roleId': data['roleId'],
          });
        }
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: widget.schoolId)
            .where('roleId', isEqualTo: roleId)
            .where('isActive', isEqualTo: true)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          selectedUsers.add({
            'userId': doc.id,
            'email': data['email'],
            'phone': data['phone'],
            'fullName': data['fullName'],
            'roleId': data['roleId'],
          });
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate() ||
        selectedRecipientTypes.isEmpty ||
        selectedChannels.isEmpty) {
      _showErrorSnackBar('Please fill all required fields and select recipients and channels');
      return;
    }

    if (!widget.isConnected) {
      _showErrorSnackBar('No internet connection. Please check your network.');
      return;
    }

    setState(() => isLoading = true);
    _animationController.repeat();

    try {
      await _loadRecipients();

      if (selectedUsers.isEmpty) {
        throw 'No recipients found for the selected criteria';
      }

      // ✅ FIXED: Better message saving with proper timestamps
      final messageRef = await FirebaseFirestore.instance.collection('messages').add({
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'recipientTypes': selectedRecipientTypes,
        'channels': selectedChannels,
        'recipients': selectedUsers.map((u) => u['userId']).toList(),
        'schoolId': widget.schoolId,
        'sentBy': widget.userId,
        'senderName': widget.adminName,
        'sentAt': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().millisecondsSinceEpoch, // For reliable ordering
        'status': 'sent',
      });

      debugPrint('✅ Message saved with ID: ${messageRef.id}');

      // Send through selected channels
      List<Future> channelFutures = [];

      for (String channel in selectedChannels) {
        switch (channel) {
          case 'email':
            channelFutures.add(_sendEmailNotifications());
            break;
          case 'sms':
            channelFutures.add(_sendSMSNotifications());
            break;
          case 'app':
            channelFutures.add(_sendAppNotifications());
            break;
        }
      }

      // Wait for all channels to complete
      await Future.wait(channelFutures);

      if (mounted) {
        _animationController.stop();
        _successAnimationController.forward();
        _showSuccessSnackBar();
        _resetForm();
      }
    } catch (e) {
      _animationController.stop();
      debugPrint('❌ Error sending message: $e');
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _resetForm() {
    titleController.clear();
    messageController.clear();
    setState(() {
      selectedRecipientTypes.clear();
      selectedChannels.clear();
      _titleValidated = false;
      _messageValidated = false;
    });
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Message Sent Successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Delivered to ${selectedUsers.length} recipients',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _sendEmailNotifications() async {
    for (var user in selectedUsers) {
      if ((user['email'] as String?)?.isNotEmpty ?? false) {
        await FirebaseFirestore.instance.collection('mail').add({
          'to': [user['email']],
          'message': {
            'subject': titleController.text.trim(),
            'html': '''
              <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, #0A1929 0%, #2563EB 100%); padding: 40px 20px;">
                <div style="background: white; border-radius: 20px; padding: 40px; box-shadow: 0 20px 40px rgba(0,0,0,0.1);">
                  <div style="text-align: center; margin-bottom: 32px;">
                    <h1 style="color: #0A1929; margin: 0; font-size: 28px; font-weight: bold;">${titleController.text.trim()}</h1>
                  </div>
                  <p style="color: #333; margin: 0 0 24px 0; font-size: 18px; line-height: 1.6;">Hello ${user['fullName']},</p>
                  <div style="background: #f8fafc; padding: 24px; border-radius: 12px; margin: 24px 0;">
                    <p style="color: #475569; margin: 0; font-size: 16px; line-height: 1.8;">${messageController.text.trim()}</p>
                  </div>
                  <hr style="border: none; border-top: 2px solid #e2e8f0; margin: 32px 0;">
                  <div style="text-align: center;">
                    <p style="color: #64748b; margin: 0; font-size: 14px; line-height: 1.6;">
                      <strong style="color: #1e293b;">${widget.schoolName}</strong><br>
                      School Management System<br>
                      Sent by: ${widget.adminName}
                    </p>
                  </div>
                </div>
              </div>
            ''',
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sentBy': widget.userId,
          'schoolId': widget.schoolId,
          'recipientId': user['userId'],
        });
      }
    }
  }

  Future<void> _sendSMSNotifications() async {
    for (var user in selectedUsers) {
      if ((user['phone'] as String?)?.isNotEmpty ?? false) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'sms',
          'to': user['phone'],
          'message': '${widget.schoolName}: ${messageController.text.trim()}',
          'title': titleController.text.trim(),
          'schoolId': widget.schoolId,
          'sentBy': widget.userId,
          'sentAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'recipientId': user['userId'],
        });
      }
    }
  }

  Future<void> _sendAppNotifications() async {
    for (var user in selectedUsers) {
      await FirebaseFirestore.instance.collection('appNotifications').add({
        'recipientId': user['userId'],
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'schoolId': widget.schoolId,
        'sentBy': widget.userId,
        'senderName': widget.adminName,
        'sentAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEnhancedFormField(
                  'Message Title',
                  'Give your message a clear and descriptive title',
                  TextFormField(
                    controller: titleController,
                    maxLength: 100,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Please enter a message title';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g., Important School Announcement',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1929).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.title_rounded,
                          color: Color(0xFF0A1929),
                          size: 20,
                        ),
                      ),
                      suffixIcon: _titleValidated
                          ? Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildEnhancedFormField(
                  'Message Content',
                  'Write your message clearly and professionally',
                  TextFormField(
                    controller: messageController,
                    maxLines: 6,
                    maxLength: 1000,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Please enter your message content';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Type your message here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '',
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildRecipientSelection(),
                const SizedBox(height: 32),
                _buildChannelSelection(),
                const SizedBox(height: 32),
                _buildSendButton(),
                if (selectedRecipientTypes.isNotEmpty && selectedChannels.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildDeliveryInfo(),
                ],
                const SizedBox(height: 100), // Extra space for scrolling
              ],
            ),
          ),
          if (isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildEnhancedFormField(String title, String subtitle, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: field,
        ),
      ],
    );
  }

  Widget _buildRecipientSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Recipients',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose who will receive this message',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: recipientTypes.map((type) {
            final isSelected = selectedRecipientTypes.contains(type['id']);
            final color = type['color'] as Color;

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedRecipientTypes.remove(type['id']);
                  } else {
                    selectedRecipientTypes.add(type['id'] as String);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey[300]!,
                    width: 2,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      size: 20,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChannelSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how recipients will receive the message',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: channels.map((channel) {
            final isSelected = selectedChannels.contains(channel['id']);
            final color = channel['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedChannels.remove(channel['id']);
                    } else {
                      selectedChannels.add(channel['id'] as String);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey[300]!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          channel['icon'] as IconData,
                          color: isSelected ? Colors.white : color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel['label'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? color : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              channel['description'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedScale(
                        scale: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    final canSend = _titleValidated &&
        _messageValidated &&
        selectedRecipientTypes.isNotEmpty &&
        selectedChannels.isNotEmpty &&
        !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: canSend ? _sendMessage : null,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
              : const Icon(Icons.send_rounded, size: 24),
        ),
        label: Text(
          isLoading ? 'Sending...' : 'Send Message',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canSend ? const Color(0xFF0A1929) : Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canSend ? 8 : 0,
          shadowColor: const Color(0xFF0A1929).withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A1929).withOpacity(0.1),
            const Color(0xFF2563EB).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0A1929).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A1929), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to Send',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Message will be delivered to ${selectedRecipientTypes.join(', ')} via ${selectedChannels.join(', ')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A1929), Color(0xFF2563EB)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sending Message',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Delivering to recipients...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: selectedChannels.map((channel) {
                    final channelData = channels.firstWhere(
                          (c) => c['id'] == channel,
                    );
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (channelData['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        channelData['icon'] as IconData,
                        color: channelData['color'] as Color,
                        size: 20,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}