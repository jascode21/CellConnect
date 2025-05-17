import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'cc_video_call.dart';
import 'dart:convert';

class ManagePage extends StatefulWidget {
const ManagePage({super.key});

@override
State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
bool _isLoading = true;
DateTime _selectedDate = DateTime.now();
List<Map<String, dynamic>> _scheduledVisits = [];
List<Map<String, dynamic>> _allVisits = []; // Store all visits
List<String> _weekDays = [];
List<int> _weekDates = [];
int _activeDay = -1; // Set to -1 to indicate "All" is selected
final TextEditingController _searchController = TextEditingController();
String _searchQuery = '';

@override
void initState() {
  super.initState();
  _initializeWeekDays();
  _fetchAllVisits(); // Fetch all visits by default

  _searchController.addListener(() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  });
}

@override
void dispose() {
  _searchController.dispose();
  super.dispose();
}

void _initializeWeekDays() {
  // Get the current week starting from today
  final now = DateTime.now();
  final weekDays = <String>[];
  final weekDates = <int>[];

  for (int i = 0; i < 7; i++) {
    final day = now.add(Duration(days: i));
    weekDays.add(DateFormat('E').format(day)[0]); // First letter of day name
    weekDates.add(day.day);

    if (i == 0) {
      _selectedDate = day;
    }
  }

  setState(() {
    _weekDays = weekDays;
    _weekDates = weekDates;
  });
}

Future<void> _fetchAllVisits() async {
  setState(() => _isLoading = true);

  try {
    // Query Firestore for all visits
    final visitsSnapshot = await FirebaseFirestore.instance
        .collection('visits')
        .orderBy('date', descending: false)
        .get();

    // Process the visits
    final visits = <Map<String, dynamic>>[];

    for (final doc in visitsSnapshot.docs) {
      final data = doc.data();

      // Get visitor details
      String visitorName = data['visitorName'] ?? 'Unknown Visitor';
      String visitorId = data['visitorId'] ?? '';
      String visitorImageUrl = ''; // Remove default image
      String visitorImageBase64 = '';

      // Try to get the visitor's profile image if available
      if (visitorId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(visitorId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            if (userData != null) {
              // Get profile image URL
              visitorImageUrl = userData['profileImageUrl'] ?? '';
              
              // Get base64 image if URL is not available
              if (visitorImageUrl.isEmpty) {
                visitorImageBase64 = userData['profileImageBase64'] ?? '';
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching visitor profile: $e');
        }
      }

      visits.add({
        'id': doc.id,
        'visitorName': visitorName,
        'visitorImageUrl': visitorImageUrl,
        'visitorImageBase64': visitorImageBase64,
        'type': data['type'] == 'virtual' ? 'Virtual visit' : 'In-person visit',
        'time': data['time'] ?? 'No time specified',
        'status': data['status'] ?? 'pending',
        'date': (data['date'] as Timestamp).toDate(),
        'visitorId': visitorId,
        'facility': data['facility'] ?? 'Not specified',
      });

      // Add this after fetching user data
      debugPrint('Visitor ID: $visitorId');
      debugPrint('Image URL: $visitorImageUrl');
      debugPrint('Has Base64: ${visitorImageBase64.isNotEmpty}');
    }

    // Sort visits by date and time
    visits.sort((a, b) {
      final dateCompare = a['date'].compareTo(b['date']);
      if (dateCompare != 0) return dateCompare;
      
      final timeA = a['time'] as String;
      final timeB = b['time'] as String;
      
      final startTimeA = timeA.split(' - ').first;
      final startTimeB = timeB.split(' - ').first;
      
      return startTimeA.compareTo(startTimeB);
    });

    if (mounted) {
      setState(() {
        _allVisits = visits;
        _scheduledVisits = visits;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading scheduled visits: $e')),
      );
    }
  }
}

Future<void> _fetchScheduledVisits() async {
  setState(() => _isLoading = true);

  try {
    // Get the start and end of the selected date
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Filter visits for the selected date
    final filteredVisits = _allVisits.where((visit) {
      final visitDate = visit['date'] as DateTime;
      return visitDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) && 
             visitDate.isBefore(endOfDay);
    }).toList();

    if (mounted) {
      setState(() {
        _scheduledVisits = filteredVisits;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading scheduled visits: $e')),
      );
    }
  }
}

void _selectDay(int index) {
  if (index != _activeDay) {
    setState(() {
      _activeDay = index;
      if (index == -1) {
        // "All" is selected
        _scheduledVisits = _allVisits;
      } else {
        final now = DateTime.now();
        _selectedDate = DateTime(now.year, now.month, now.day).add(Duration(days: index));
        _fetchScheduledVisits();
      }
    });
  }
}

Future<void> _approveVisit(String visitId) async {
try {
  // First, get the visit data to find the visitor ID
  final visitDoc = await FirebaseFirestore.instance
      .collection('visits')
      .doc(visitId)
      .get();
      
  if (!visitDoc.exists) {
    throw Exception('Visit not found');
  }
  
  final visitData = visitDoc.data()!;
  final visitorId = visitData['visitorId'];
  
  if (visitorId == null || visitorId.isEmpty) {
    throw Exception('Visitor ID not found');
  }
  
  // Update status in the global visits collection
  await FirebaseFirestore.instance
      .collection('visits')
      .doc(visitId)
      .update({
    'status': 'approved',
    'approvedAt': FieldValue.serverTimestamp(),
  });

  // Generate a random visitation code for virtual visits
  final visitIndex = _scheduledVisits.indexWhere((visit) => visit['id'] == visitId);
  if (visitIndex != -1 && _scheduledVisits[visitIndex]['type'] == 'Virtual visit') {
    final visitationCode = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();

    await FirebaseFirestore.instance
        .collection('visits')
        .doc(visitId)
        .update({
      'visitationCode': visitationCode,
    });
  }
  
  // Now find and update the corresponding visit in the user's subcollection
  try {
    // Query to find the matching visit in the user's subcollection
    final userVisitsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(visitorId)
        .collection('visits')
        .where('date', isEqualTo: visitData['date'])
        .where('time', isEqualTo: visitData['time'])
        .get();
        
    if (userVisitsSnapshot.docs.isNotEmpty) {
      // Update the status in the user's visit
      await FirebaseFirestore.instance
          .collection('users')
          .doc(visitorId)
          .collection('visits')
          .doc(userVisitsSnapshot.docs.first.id)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'visitationCode': visitData['visitationCode'], // Copy the visitation code if it exists
      });
    }
  } catch (e) {
    debugPrint('Error updating user visit: $e');
    // Continue even if there's an error updating the user's visit
  }

  // Log the activity
  DocumentSnapshot user = await FirebaseFirestore.instance.collection('users').doc('currentStaffId').get();
  String staffName = 'Staff';
  if (user.exists && user.data() != null) {
    final userData = user.data()! as Map<String, dynamic>;
    if (userData.containsKey('fullName')) {
      staffName = userData['fullName'] as String? ?? 'Staff';
    }
  }

  await FirebaseFirestore.instance
      .collection('activities')
      .add({
    'type': 'visit_approved',
    'visitId': visitId,
    'staffId': 'currentStaffId', // In a real app, this would be the actual staff ID
    'staffName': staffName,
    'timestamp': FieldValue.serverTimestamp(),
  });

  // Send notification to the visitor
  final visitIndex2 = _scheduledVisits.indexWhere((visit) => visit['id'] == visitId);
  if (visitIndex2 != -1) {
    final visitorId = _scheduledVisits[visitIndex2]['visitorId'];
    if (visitorId != null && visitorId.isNotEmpty) {
      await _sendNotification(
        visitorId,
        'Visit Approved',
        'Your ${_scheduledVisits[visitIndex2]['type']} on ${DateFormat('MMMM d, yyyy').format(_scheduledVisits[visitIndex2]['date'])} at ${_scheduledVisits[visitIndex2]['time']} has been approved.',
        'visit_approved',
        visitationCode: _scheduledVisits[visitIndex2]['visitationCode'] ?? ''
      );
    }
  }

  // Refresh the list
  if (_activeDay == -1) {
    _fetchAllVisits();
  } else {
    _fetchScheduledVisits();
  }

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visit approved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error approving visit: $e')),
  );
}
}

Future<void> _declineVisit(String visitId) async {
try {
  // First, get the visit data to find the visitor ID
  final visitDoc = await FirebaseFirestore.instance
      .collection('visits')
      .doc(visitId)
      .get();
      
  if (!visitDoc.exists) {
    throw Exception('Visit not found');
  }
  
  final visitData = visitDoc.data()!;
  final visitorId = visitData['visitorId'];
  
  if (visitorId == null || visitorId.isEmpty) {
    throw Exception('Visitor ID not found');
  }
  
  // Update status in the global visits collection
  await FirebaseFirestore.instance
      .collection('visits')
      .doc(visitId)
      .update({
    'status': 'rejected',
    'rejectedAt': FieldValue.serverTimestamp(),
  });
  
  // Now find and update the corresponding visit in the user's subcollection
  try {
    // Query to find the matching visit in the user's subcollection
    final userVisitsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(visitorId)
        .collection('visits')
        .where('date', isEqualTo: visitData['date'])
        .where('time', isEqualTo: visitData['time'])
        .get();
        
    if (userVisitsSnapshot.docs.isNotEmpty) {
      // Update the status in the user's visit
      await FirebaseFirestore.instance
          .collection('users')
          .doc(visitorId)
          .collection('visits')
          .doc(userVisitsSnapshot.docs.first.id)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    }
  } catch (e) {
    debugPrint('Error updating user visit: $e');
    // Continue even if there's an error updating the user's visit
  }

  // Log the activity
  DocumentSnapshot user = await FirebaseFirestore.instance.collection('users').doc('currentStaffId').get();
  String staffName = 'Staff';
  if (user.exists && user.data() != null) {
    final userData = user.data()! as Map<String, dynamic>;
    if (userData.containsKey('fullName')) {
      staffName = userData['fullName'] as String? ?? 'Staff';
    }
  }

  await FirebaseFirestore.instance
      .collection('activities')
      .add({
    'type': 'visit_rejected',
    'visitId': visitId,
    'staffId': 'currentStaffId', // In a real app, this would be the actual staff ID
    'staffName': staffName,
    'timestamp': FieldValue.serverTimestamp(),
  });

  // Send notification to the visitor
  final visitIndex = _scheduledVisits.indexWhere((visit) => visit['id'] == visitId);
  if (visitIndex != -1) {
    final visitorId = _scheduledVisits[visitIndex]['visitorId'];
    if (visitorId != null && visitorId.isNotEmpty) {
      await _sendNotification(
        visitorId,
        'Visit Rejected',
        'Your ${_scheduledVisits[visitIndex]['type']} on ${DateFormat('MMMM d, yyyy').format(_scheduledVisits[visitIndex]['date'])} at ${_scheduledVisits[visitIndex]['time']} has been rejected.',
        'visit_rejected',
        visitationCode: _scheduledVisits[visitIndex]['visitationCode'] ?? ''
      );
    }
  }

  // Refresh the list
  if (_activeDay == -1) {
    _fetchAllVisits();
  } else {
    _fetchScheduledVisits();
  }

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visit declined'),
        backgroundColor: Colors.orange,
      ),
    );
  }
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error declining visit: $e')),
  );
}
}

Future<void> _startVisit(String visitId) async {
try {
  // First, get the visit data to find the visitor ID
  final visitDoc = await FirebaseFirestore.instance
      .collection('visits')
      .doc(visitId)
      .get();
      
  if (!visitDoc.exists) {
    throw Exception('Visit not found');
  }
  
  final visitData = visitDoc.data()!;
  final visitorId = visitData['visitorId'];
  final visitType = visitData['type'] ?? 'in-person';
  
  if (visitorId == null || visitorId.isEmpty) {
    throw Exception('Visitor ID not found');
  }
  
  // Generate a visitation code if it doesn't exist
  String visitationCode = visitData['visitationCode'] ?? '';
  if (visitType == 'virtual' && (visitationCode.isEmpty)) {
    visitationCode = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    
    // Update the visit with the new code
    await FirebaseFirestore.instance
        .collection('visits')
        .doc(visitId)
        .update({
      'visitationCode': visitationCode,
    });
  }
  
  // Update status in the global visits collection
  await FirebaseFirestore.instance
      .collection('visits')
      .doc(visitId)
      .update({
    'status': 'in_progress',
    'startedAt': FieldValue.serverTimestamp(),
  });
  
  // Now find and update the corresponding visit in the user's subcollection
  try {
    // Query to find the matching visit in the user's subcollection
    final userVisitsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(visitorId)
        .collection('visits')
        .where('date', isEqualTo: visitData['date'])
        .where('time', isEqualTo: visitData['time'])
        .get();
        
    if (userVisitsSnapshot.docs.isNotEmpty) {
      // Update the status in the user's visit
      await FirebaseFirestore.instance
          .collection('users')
          .doc(visitorId)
          .collection('visits')
          .doc(userVisitsSnapshot.docs.first.id)
          .update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'visitationCode': visitationCode, // Make sure to update the code here too
      });
    }
  } catch (e) {
    debugPrint('Error updating user visit: $e');
    // Continue even if there's an error updating the user's visit
  }

  // Log the activity
  DocumentSnapshot user = await FirebaseFirestore.instance.collection('users').doc('currentStaffId').get();
  String staffName = 'Staff';
  if (user.exists && user.data() != null) {
    final userData = user.data()! as Map<String, dynamic>;
    if (userData.containsKey('fullName')) {
      staffName = userData['fullName'] as String? ?? 'Staff';
    }
  }

  await FirebaseFirestore.instance
      .collection('activities')
      .add({
    'type': 'visit_started',
    'visitId': visitId,
    'staffId': 'currentStaffId', // In a real app, this would be the actual staff ID
    'staffName': staffName,
    'timestamp': FieldValue.serverTimestamp(),
  });

  // Send notification to the visitor
  final visitIndex = _scheduledVisits.indexWhere((visit) => visit['id'] == visitId);
  if (visitIndex != -1) {
    final visitorId = _scheduledVisits[visitIndex]['visitorId'];
    if (visitorId != null && visitorId.isNotEmpty) {
      await _sendNotification(
        visitorId,
        'Visit Started',
        'Your ${_scheduledVisits[visitIndex]['type']} on ${DateFormat('MMMM d, yyyy').format(_scheduledVisits[visitIndex]['date'])} at ${_scheduledVisits[visitIndex]['time']} has started.',
        'visit_started',
        visitationCode: visitationCode
      );
    }
  }

  // Refresh the list
  if (_activeDay == -1) {
    _fetchAllVisits();
  } else {
    _fetchScheduledVisits();
  }

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visit started'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // For virtual visits, navigate to the video call interface
  if (visitType == 'virtual') {
    if (mounted) {
      debugPrint("Starting virtual visit with code: $visitationCode");
      
      // Use a valid Agora App ID
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
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedVideoCallPage(
            appId: agoraAppId,
            channelName: visitationCode,
            userName: 'Staff',
            role: 'Staff',
            token: '', // Add empty string token
          ),
        ),
      );
    }
  }
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error starting visit: $e')),
  );
}
}

Future<void> _joinVirtualVisit(String visitId) async {
try {
  // Get the visit data to find the visitation code
  final visitDoc = await FirebaseFirestore.instance
      .collection('visits')
      .doc(visitId)
      .get();
      
  if (!visitDoc.exists) {
    throw Exception('Visit not found');
  }
  
  final visitData = visitDoc.data()!;
  final visitationType = visitData['type'];
  final visitationCode = visitData['visitationCode'] ?? '';
  
  if (visitationType != 'virtual') {
    throw Exception('This is not a virtual visit');
  }
  
  if (visitationCode.isEmpty) {
    throw Exception('No visitation code found for this visit');
  }
  
  // Navigate to the video call interface
  if (mounted) {
    debugPrint("Joining virtual visit with code: $visitationCode");
    
    // Use a valid Agora App ID
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
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedVideoCallPage(
          appId: agoraAppId,
          channelName: visitationCode,
          userName: 'Staff',
          role: 'Staff',
          token: '', // Add empty string token
        ),
      ),
    );
  }
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error joining visit: $e')),
  );
}
}

// This is a placeholder method - you need to implement actual token generation

// Send notification to user
Future<void> _sendNotification(String userId, String title, String description, String type, {String visitationCode = ''}) async {
  try {
    // Get current date
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM d, yyyy').format(now);
    
    // Determine icon and color based on notification type
    
    switch (type) {
      case 'visit_approved':
        break;
      case 'visit_rejected':
        break;
      case 'visit_started':
        break;
      default:
    }
    
    // Add notification to user's collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'description': description,
      'date': formattedDate,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'type': type,
      'visitationCode': visitationCode,
    });
    
  } catch (e) {
    // Handle error silently
  }
}

List<Map<String, dynamic>> get _filteredVisits {
  if (_searchQuery.isEmpty) {
    return _scheduledVisits;
  }

  final query = _searchQuery.toLowerCase();
  return _scheduledVisits.where((visit) {
    final visitorName = (visit['visitorName'] as String).toLowerCase();
    final visitType = (visit['type'] as String).toLowerCase();
    final visitTime = (visit['time'] as String).toLowerCase();
    final visitStatus = (visit['status'] as String).toLowerCase();
    final visitDate = DateFormat('MMMM d, yyyy').format(visit['date']).toLowerCase();

    return visitorName.contains(query) ||
        visitType.contains(query) ||
        visitTime.contains(query) ||
        visitStatus.contains(query) ||
        visitDate.contains(query);
  }).toList();
}

get visit => null;

void _showVisitDetailsModal(Map<String, dynamic> visit) {
  final visitDate = visit['date'] as DateTime;
  final formattedDate = DateFormat('MMMM d, yyyy').format(visitDate);
  final visitType = visit['type'] as String;
  final visitStatus = visit['status'] as String;
  final facility = visit['facility'] as String;
  final time = visit['time'] as String;
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: visitType.contains('Virtual') 
                        ? Colors.blue.withOpacity(0.1) 
                        : const Color(0xFF054D88).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    visitType.contains('Virtual') ? Icons.videocam : Icons.person,
                    color: visitType.contains('Virtual') ? Colors.blue : const Color(0xFF054D88),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$visitType Details',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: visitType.contains('Virtual') ? Colors.blue : const Color(0xFF054D88),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(visitStatus).withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(visitStatus),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(visitStatus),
                          ),
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
                  // Visitor information
                  _buildDetailSection(
                    'Visitor Information',
                    Icons.person,
                    [
                      _buildDetailItem('Name', visit['visitorName']),
                      _buildDetailItem('ID', visit['visitorId'] ?? 'Not available'),
                    ],
                    visitType.contains('Virtual') ? Colors.blue : const Color(0xFF054D88),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Date and time section
                  _buildDetailSection(
                    'Date & Time',
                    Icons.calendar_today,
                    [
                      _buildDetailItem('Date', formattedDate),
                      _buildDetailItem('Time', time),
                    ],
                    visitType.contains('Virtual') ? Colors.blue : const Color(0xFF054D88),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Location section
                  _buildDetailSection(
                    'Location',
                    Icons.location_on,
                    [
                      _buildDetailItem('Facility', facility),
                    ],
                    visitType.contains('Virtual') ? Colors.blue : const Color(0xFF054D88),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Status section
                  _buildDetailSection(
                    'Status Information',
                    Icons.info_outline,
                    [
                      _buildDetailItem('Current Status', _getStatusText(visitStatus)),
                    ],
                    _getStatusColor(visitStatus),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Action buttons
                  if (visitStatus == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Approve Visit'),
                            onPressed: () {
                              Navigator.pop(context);
                              _approveVisit(visit['id']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.cancel),
                            label: const Text('Decline Visit'),
                            onPressed: () {
                              Navigator.pop(context);
                              _declineVisit(visit['id']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (visitStatus == 'approved') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text('Start Visit'),
                        onPressed: () {
                          Navigator.pop(context);
                          _startVisit(visit['id']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF054D88),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ] else if (visitStatus == 'in_progress' && visitType.contains('Virtual')) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.videocam),
                        label: const Text('Join Virtual Visit'),
                        onPressed: () {
                          Navigator.pop(context);
                          _joinVirtualVisit(visit['id']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
      color: Colors.white,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
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

@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final formattedDate = _activeDay == -1 
      ? "All Bookings" 
      : DateFormat('MMMM yyyy').format(_selectedDate);

  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        formattedDate,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: screenWidth * 0.08,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // Show date picker
            showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            ).then((date) {
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                  // Reset active day since we're selecting a specific date
                  _activeDay = -1;
                });
                _fetchScheduledVisits();
              }
            });
          },
          icon: const Icon(Icons.calendar_month, color: Colors.black, size: 28),
        ),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calendar Row with "All" option
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All" option
                GestureDetector(
                  onTap: () => _selectDay(-1),
                  child: Column(
                    children: [
                      const Text(
                        "All",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _activeDay == -1
                            ? const Color.fromARGB(255, 5, 77, 136)
                            : Colors.transparent,
                        child: Text(
                          "•••",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _activeDay == -1 ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Day options
                ...List.generate(7, (index) {
                  return GestureDetector(
                    onTap: () => _selectDay(index),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Column(
                        children: [
                          Text(
                            _weekDays[index],
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: index == _activeDay
                                ? const Color.fromARGB(255, 5, 77, 136)
                                : Colors.transparent,
                            child: Text(
                              _weekDates[index].toString(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: index == _activeDay ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Scheduled Today Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            _activeDay == -1 
                ? 'All Scheduled Visits' 
                : _activeDay == 0 
                    ? 'Scheduled Today' 
                    : 'Scheduled on ${DateFormat('MMMM d').format(_selectedDate)}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by visitor name, date, status...',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Scheduled Visitors List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredVisits.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _activeDay == -1 
                                ? 'No visits scheduled' 
                                : 'No visits scheduled for this day',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _activeDay == -1 ? _fetchAllVisits : _fetchScheduledVisits,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _filteredVisits.length,
                        itemBuilder: (context, index) {
                          final visit = _filteredVisits[index];
                          return InkWell(
                            onTap: () => _showVisitDetailsModal(visit),
                            child: _buildVisitorCard(
                              name: visit['visitorName'],
                              type: visit['type'],
                              time: visit['time'],
                              imageUrl: visit['visitorImageUrl'],
                              imageBase64: visit['visitorImageBase64'],
                              status: visit['status'],
                              date: visit['date'],
                              onApprove: visit['status'] == 'pending'
                                  ? () => _approveVisit(visit['id'])
                                  : null,
                              onDecline: visit['status'] == 'pending'
                                  ? () => _declineVisit(visit['id'])
                                  : null,
                              onStart: visit['status'] == 'approved'
                                  ? () => _startVisit(visit['id'])
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    ),
  );
}

// Build Visitor Card Widget
Widget _buildVisitorCard({
  required String name,
  required String type,
  required String time,
  required String imageUrl,
  String? imageBase64,
  required String status,
  required DateTime date,
  VoidCallback? onApprove,
  VoidCallback? onDecline,
  VoidCallback? onStart,
}) {
  final formattedDate = _activeDay == -1 
      ? DateFormat('MMM d, yyyy').format(date) 
      : '';

  return Card(
    margin: const EdgeInsets.only(bottom: 16.0),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildProfileImage(imageUrl, imageBase64, name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$type - $time',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_activeDay == -1) ...[
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onApprove != null && onDecline != null) ...[
            IconButton(
              onPressed: onApprove,
              icon: const Icon(Icons.check_circle, color: Color.fromARGB(255, 5, 77, 136), size: 40),
            ),
            IconButton(
              onPressed: onDecline,
              icon: const Icon(Icons.cancel, color: Color.fromARGB(255, 150, 62, 62), size: 40),
            ),
          ],
          if ((onStart != null || status == 'in_progress') && type.contains('Virtual'))
            ElevatedButton(
              onPressed: onStart ?? (status == 'in_progress' ? () => _joinVirtualVisit(visit['id']) : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'in_progress' ? Colors.blue : const Color.fromARGB(255, 5, 77, 136),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                status == 'in_progress' ? 'Join' : 'Start',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          if (onApprove == null && onDecline == null && onStart == null)
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    ),
  );
}

Widget _buildProfileImage(String? url, String? base64, String name) {
  // First try to use the URL if available
  if (url != null && url.isNotEmpty) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: 50,
          height: 50,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading network image: $error');
            // If URL fails, try base64
            if (base64 != null && base64.isNotEmpty) {
              return _buildBase64Image(base64, name);
            }
            return _buildFallbackAvatar(name);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
  
  // If no URL, try base64
  if (base64 != null && base64.isNotEmpty) {
    return _buildBase64Image(base64, name);
  }
  
  // If neither URL nor base64, show fallback
  return _buildFallbackAvatar(name);
}

Widget _buildBase64Image(String base64, String name) {
  try {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.memory(
          base64Decode(base64),
          fit: BoxFit.cover,
          width: 50,
          height: 50,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading base64 image: $error');
            return _buildFallbackAvatar(name);
          },
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error decoding base64 image: $e');
    return _buildFallbackAvatar(name);
  }
}

Widget _buildFallbackAvatar(String name) {
  return CircleAvatar(
    radius: 25,
    backgroundColor: Colors.grey.shade200,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFF054D88),
      ),
    ),
  );
}

Color _getStatusColor(String status) {
  switch (status) {
    case 'approved':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    case 'in_progress':
      return Colors.blue;
    case 'completed':
      return Colors.purple;
    case 'cancelled':
      return Colors.grey;
    default:
      return Colors.orange;
  }
}

String _getStatusText(String status) {
  switch (status) {
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'in_progress':
      return 'In Progress';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Pending';
  }
}
}
