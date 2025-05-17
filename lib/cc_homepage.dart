import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'cc_video_call.dart';

class HomePage extends StatefulWidget {
final String role;
final String userName;

const HomePage({super.key, required this.role, required this.userName});

@override
State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
final TextEditingController visitationCodeController = TextEditingController();
String _formattedDate = '';
Map<String, dynamic>? _nextVisit;
List<Map<String, dynamic>> _upcomingVisits = [];
bool _isLoading = true;
bool _isEnteringRoom = false;
late AnimationController _animationController;
late Animation<double> _fadeAnimation;
late Animation<Offset> _slideAnimation;

@override
void initState() {
  super.initState();
  _formattedDate = DateFormat('MMMM d, yyyy').format(DateTime.now());

  // Setup animations
  _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
  );

  _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
    CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
  );

  _fetchVisits();

  // Add a focus listener to refresh data when the page is focused
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Listen for when the page gets focus
    final focusNode = FocusNode();
    FocusScope.of(context).requestFocus(focusNode);
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        _fetchVisits();
      }
    });
  });
}

@override
void dispose() {
  visitationCodeController.dispose();
  _animationController.dispose();
  super.dispose();
}

Future<void> _fetchVisits() async {
  setState(() => _isLoading = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _nextVisit = null;
        _upcomingVisits = [];
      });
      return;
    }

    // Query for upcoming visits - using a simpler query to avoid index issues
    final visitsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('visits')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .orderBy('date')
        .get();

    final List<Map<String, dynamic>> visits = [];

    // Process user's visits
    for (var doc in visitsSnapshot.docs) {
      final visitData = doc.data();
      visitData['id'] = doc.id;

      // Only include pending or approved visits
      if (visitData['status'] == 'pending' || visitData['status'] == 'approved' || visitData['status'] == 'in_progress') {
        visits.add(Map<String, dynamic>.from(visitData));
      }
    }

    visits.sort((a, b) {
      final aDate = (a['date'] as Timestamp).toDate();
      final bDate = (b['date'] as Timestamp).toDate();
      return aDate.compareTo(bDate);
    });

    setState(() {
      _upcomingVisits = visits;
      _nextVisit = visits.isNotEmpty ? visits.first : null;
      _isLoading = false;
    });

    _animationController.forward();
  } catch (e) {
    debugPrint('Error fetching visits: $e');
    // Show error in UI
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching visits: $e')),
      );
    }
    setState(() {
      _nextVisit = null;
      _upcomingVisits = [];
      _isLoading = false;
    });

    _animationController.forward();
  }
}

Future<void> _enterVisitationRoom() async {
  if (visitationCodeController.text.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a visitation code')),
      );
    }
    return;
  }

  setState(() => _isEnteringRoom = true);

  try {
    final code = visitationCodeController.text.trim();
    debugPrint("Attempting to enter room with code: $code");
    
    // Query for visits with this code
    final visitsSnapshot = await FirebaseFirestore.instance
        .collection('visits')
        .where('visitationCode', isEqualTo: code)
        .get();

    debugPrint("Found ${visitsSnapshot.docs.length} visits with this code");
    
    setState(() => _isEnteringRoom = false);

    // Check if there are any visits with this code that are in progress or approved
    final inProgressVisits = visitsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'in_progress')
        .toList();
    
    final approvedVisits = visitsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'approved')
        .toList();

    if (inProgressVisits.isEmpty && approvedVisits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or unapproved visitation code'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Prioritize in-progress visits
    final visitData = inProgressVisits.isNotEmpty 
        ? inProgressVisits.first.data() 
        : approvedVisits.first.data();
    final visitId = inProgressVisits.isNotEmpty 
        ? inProgressVisits.first.id 
        : approvedVisits.first.id;
    
    // Allow joining even if the visit is just approved (not yet in progress)
    if (visitData['status'] != 'in_progress' && visitData['status'] != 'approved') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This meeting has not been approved yet. Please wait for staff approval.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // If visit is approved but not in progress, update it to in_progress
    if (visitData['status'] == 'approved') {
      // Update the visit status to in_progress
      await FirebaseFirestore.instance
          .collection('visits')
          .doc(visitId)
          .update({'status': 'in_progress'});
          
      debugPrint("Updated visit status to in_progress");
    }

    // Navigate to the video call screen
    if (mounted) {
      debugPrint("Entering virtual visit with code: $code");
      
      // Use the Agora App ID from your project
      const String agoraAppId = '81bb421e4db9457f9522222420e2841c';
      
      if (agoraAppId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Agora App ID. Please configure a valid App ID.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedVideoCallPage(
              appId: agoraAppId,
              channelName: code,
              userName: widget.userName,
              role: widget.role,
              token: '', // We'll generate the token in the video call page
              certificate: '522f820b685a44ba9cd040cab895e8c9', // Primary certificate
            ),
          ),
        );
      } catch (e) {
        debugPrint("Error navigating to video call: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting video call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Clear the code field
    visitationCodeController.clear();
  } catch (e) {
    debugPrint("Error entering visitation room: $e");
    setState(() => _isEnteringRoom = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}

// This is a placeholder method - you need to implement actual token generation

// Enhance the visit details modal with better UI and animations
void _showVisitDetailsModal(Map<String, dynamic> visit) {
  final visitDate = (visit['date'] as Timestamp).toDate();
  final formattedDate = DateFormat('MMMM d, yyyy').format(visitDate);
  final visitType = visit['type'] == 'virtual' ? 'Virtual' : 'In-person';
  final visitStatus = visit['status'] ?? 'pending';
  final facility = visit['facility'] ?? 'Not specified';
  final time = visit['time'] ?? 'Not specified';

  // For hero animation tag
  final heroTag = 'visit-${visit['id']}';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context).overlay! as TickerProvider,
      duration: const Duration(milliseconds: 400),
    ),
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: heroTag,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: visitType == 'Virtual'
                          ? Colors.blue.withAlpha((0.1 * 255).round())
                          : const Color(0xFF054D88).withAlpha((0.1 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      visitType == 'Virtual' ? Icons.videocam : Icons.person,
                      color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$visitType Visit Details',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: visitStatus == 'approved'
                              ? Colors.green.withAlpha((0.1 * 255).round())
                              : visitStatus == 'rejected'
                                  ? Colors.red.withAlpha((0.1 * 255).round())
                                  : visitStatus == 'in_progress'
                                      ? Colors.blue.withAlpha((0.1 * 255).round())
                                      : Colors.orange.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: (visitStatus == 'approved'
                                  ? Colors.green
                                  : visitStatus == 'rejected'
                                      ? Colors.red
                                      : visitStatus == 'in_progress'
                                          ? Colors.blue
                                          : Colors.orange).withAlpha((0.2 * 255).round()),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              visitStatus == 'approved'
                                  ? Icons.check_circle
                                  : visitStatus == 'rejected'
                                      ? Icons.cancel
                                      : visitStatus == 'in_progress'
                                          ? Icons.play_circle_fill
                                          : Icons.hourglass_empty,
                              size: 14,
                              color: visitStatus == 'approved'
                                  ? Colors.green
                                  : visitStatus == 'rejected'
                                      ? Colors.red
                                      : visitStatus == 'in_progress'
                                          ? Colors.blue
                                          : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              visitStatus == 'approved'
                                  ? 'Approved'
                                  : visitStatus == 'rejected'
                                      ? 'Rejected'
                                      : visitStatus == 'in_progress'
                                          ? 'In Progress'
                                          : 'Pending Approval',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: visitStatus == 'approved'
                                    ? Colors.green
                                    : visitStatus == 'rejected'
                                        ? Colors.red
                                        : visitStatus == 'in_progress'
                                            ? Colors.blue
                                            : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.grey,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and time section
                  _buildDetailSection(
                    'Date & Time',
                    Icons.calendar_today,
                    [
                      _buildDetailItem('Date', formattedDate),
                      _buildDetailItem('Time', time),
                    ],
                    visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                  ),

                  const SizedBox(height: 24),

                  // Location section
                  _buildDetailSection(
                    'Location',
                    Icons.location_on,
                    [
                      _buildDetailItem('Facility', facility),
                    ],
                    visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                  ),

                  const SizedBox(height: 24),

                  // Status section
                  _buildDetailSection(
                    'Status Information',
                    Icons.info_outline,
                    [
                      _buildDetailItem('Current Status', visitStatus.toUpperCase()),
                      if (visitStatus == 'pending')
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Icon(Icons.pending_actions, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your visit request is being reviewed by staff. You will be notified when it\'s approved.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (visitStatus == 'approved')
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your visit has been approved. Please arrive on time or join the virtual room at the scheduled time.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (visitStatus == 'in_progress')
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_fill, size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your visit is currently in progress. If this is a virtual visit, you can join using the visitation code.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    visitStatus == 'approved'
                        ? Colors.green
                        : visitStatus == 'rejected'
                            ? Colors.red
                            : Colors.orange,
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  if (visitStatus != 'cancelled' && visitStatus != 'rejected') ...[
                    const SizedBox(height: 32),
                    
                    // Action buttons with animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.05 * 255).round()),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (visitType == 'Virtual' && (visitStatus == 'in_progress' || visitStatus == 'approved')) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.video_call),
                                label: const Text('Join Virtual Visit'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  // Navigate to video call screen with enhanced version
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EnhancedVideoCallPage(
                                        appId: '81bb421e4db9457f9522222420e2841c',
                                        channelName: visit['visitationCode'],
                                        userName: widget.userName,
                                        role: widget.role,
                                        token: '', // Add empty string token
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 4,
                                  shadowColor: Colors.blue.withAlpha((0.4 * 255).round()),
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel Visit'),
                              onPressed: () {
                                Navigator.pop(context);
                                _showCancelConfirmationDialog(visit);
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 4,
                                shadowColor: Colors.red.withAlpha((0.4 * 255).round()),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDetailSection(String title, IconData icon, List<Widget> children, Color color) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 500),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: color.withAlpha((0.1 * 255).round()),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withAlpha((0.05 * 255).round()),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    ),
  );
}

Widget _buildDetailItem(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
      ],
    ),
  );
}

void _showCancelConfirmationDialog(Map<String, dynamic> visit) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Cancel Visit?'),
      content: const Text('Are you sure you want to cancel this visit? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('No, Keep It'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _cancelVisit(visit);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Yes, Cancel Visit'),
        ),
      ],
    ),
  );
}

Future<void> _cancelVisit(Map<String, dynamic> visit) async {
  if (visit['id'] == null) return;

  setState(() => _isLoading = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Update the visit status to 'cancelled' in user's collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('visits')
        .doc(visit['id'])
        .update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    // Also update in the global visits collection
    await FirebaseFirestore.instance
        .collection('visits')
        .doc(visit['id'])
        .update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    // Refresh the visits
    _fetchVisits();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling visit: $e')),
      );
    }
  }
}

@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;

  // Format next visit date if available
  String nextVisitDate = '';
  String visitType = '';
  String visitStatus = '';

  if (_nextVisit != null) {
    final visitDate = (_nextVisit!['date'] as Timestamp).toDate();
    nextVisitDate = DateFormat('MMMM d, yyyy').format(visitDate);
    visitType = _nextVisit!['type'] == 'virtual' ? 'virtual' : 'in-person';
    visitStatus = _nextVisit!['status'] ?? 'pending';
  }

  // Rest of the build method omitted for brevity...
  
  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F7FA)],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchVisits,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section with animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${widget.userName}!',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: screenWidth * 0.08,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF054D88),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formattedDate,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Next visit card
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((0.05 * 255).round()),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: _nextVisit != null
                              ? Border.all(
                                  color: visitStatus == 'approved'
                                      ? Colors.green.withAlpha((0.5 * 255).round())
                                      : visitType == 'virtual'
                                          ? Colors.blue.withAlpha((0.5 * 255).round())
                                          : const Color(0xFF054D88).withAlpha((0.5 * 255).round()),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF054D88).withAlpha((0.1 * 255).round()),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFF054D88),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Upcoming Visit',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF054D88),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (_nextVisit != null) ...[
                                    InkWell(
                                      onTap: () => _showVisitDetailsModal(_nextVisit!),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Ink(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          border: Border.all(color: Colors.grey[200]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    nextVisitDate,
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _nextVisit!['time'] ?? 'No time specified',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 14,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        visitType == 'virtual'
                                                            ? Icons.videocam
                                                            : Icons.person,
                                                        size: 16,
                                                        color: visitType == 'virtual'
                                                            ? Colors.blue
                                                            : const Color(0xFF054D88),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        visitType == 'virtual'
                                                            ? 'Virtual Visit'
                                                            : 'In-person Visit',
                                                        style: TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 14,
                                                          color: visitType == 'virtual'
                                                              ? Colors.blue
                                                              : const Color(0xFF054D88),
                                                        ),
                                                      ),
                                                    ],
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
                                                color: visitStatus == 'approved'
                                                    ? Colors.green.withAlpha((0.1 * 255).round())
                                                    : visitStatus == 'rejected'
                                                        ? Colors.red.withAlpha((0.1 * 255).round())
                                                        : visitStatus == 'in_progress'
                                                            ? Colors.blue.withAlpha((0.1 * 255).round())
                                                            : Colors.orange.withAlpha((0.1 * 255).round()),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                visitStatus == 'approved'
                                                    ? 'Approved'
                                                    : visitStatus == 'rejected'
                                                        ? 'Rejected'
                                                        : visitStatus == 'in_progress'
                                                            ? 'In Progress'
                                                            : 'Pending',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: visitStatus == 'approved'
                                                      ? Colors.green
                                                      : visitStatus == 'rejected'
                                                          ? Colors.red
                                                          : visitStatus == 'in_progress'
                                                              ? Colors.blue
                                                              : Colors.orange,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_ios,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Show other upcoming visits if available
                                    if (_upcomingVisits.length > 1) ...[
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Other Upcoming Visits',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF054D88),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...List.generate(
                                        _upcomingVisits.length > 3 ? 3 : _upcomingVisits.length - 1,
                                        (index) {
                                          final visit = _upcomingVisits[index + 1];
                                          final visitDate = (visit['date'] as Timestamp).toDate();
                                          final formattedDate = DateFormat('MMM d').format(visitDate);
                                          final visitType = visit['type'] == 'virtual' ? 'Virtual' : 'In-person';
                                          final visitStatus = visit['status'] ?? 'pending';

                                          return InkWell(
                                            onTap: () => _showVisitDetailsModal(visit),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Ink(
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    visitType == 'Virtual' ? Icons.videocam : Icons.person,
                                                    size: 16,
                                                    color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '$visitType Visit - $formattedDate',
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: visitStatus == 'approved'
                                                          ? Colors.green.withAlpha((0.1 * 255).round())
                                                          : visitStatus == 'in_progress'
                                                              ? Colors.blue.withAlpha((0.1 * 255).round())
                                                              : Colors.orange.withAlpha((0.1 * 255).round()),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      visitStatus == 'approved'
                                                          ? 'Approved'
                                                          : visitStatus == 'in_progress'
                                                              ? 'In Progress'
                                                              : 'Pending',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 12,
                                                        color: visitStatus == 'approved'
                                                            ? Colors.green
                                                            : visitStatus == 'in_progress'
                                                                ? Colors.blue
                                                                : Colors.orange,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.arrow_forward_ios,
                                                    size: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      if (_upcomingVisits.length > 3) ...[
                                        const SizedBox(height: 8),
                                        Center(
                                          child: TextButton(
                                            onPressed: () {
                                              // Navigate to all visits page
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('View all visits feature coming soon')),
                                                );
                                              }
                                            },
                                            child: const Text('View All Visits'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ] else ...[
                                    const Text(
                                      'You do not have any scheduled visits',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Schedule a visit using the buttons below',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Schedule buttons - only show if no active visit
                  if (_upcomingVisits.isEmpty) ...[
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Schedule a Visit',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF054D88),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildAnimatedButton(
                              icon: Icons.person,
                              title: 'Schedule in-person visit',
                              color: const Color(0xFF054D88),
                              onTap: () => Navigator.pushNamed(context, '/inPersonVisit'),
                            ),
                            const SizedBox(height: 12),
                            _buildAnimatedButton(
                              icon: Icons.videocam,
                              title: 'Book a virtual visit',
                              color: Colors.blue,
                              onTap: () => Navigator.pushNamed(context, '/virtualVisit'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Virtual visitation room section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((0.05 * 255).round()),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha((0.1 * 255).round()),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Virtual visitation room',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: visitationCodeController,
                              decoration: InputDecoration(
                                labelText: 'Visitation code',
                                hintText: 'Enter your 6-digit code',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.vpn_key),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isEnteringRoom ? null : _enterVisitationRoom,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isEnteringRoom
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Enter room',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Reporting a problem...')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.help_outline, size: 16),
                                label: const Text(
                                  'Did not receive visitation code? Report a Problem',
                                  style: TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

Widget _buildAnimatedButton({
  required IconData icon,
  required String title,
  required Color color,
  required VoidCallback onTap,
}) {
  return TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 1.0, end: 1.0),
    duration: const Duration(milliseconds: 200),
    builder: (context, scale, child) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          onEnter: (_) => setState(() {}),
          onExit: (_) => setState(() {}),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha((0.3 * 255).round()),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}
