import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ActivityLog extends StatefulWidget {
  const ActivityLog({super.key});

  @override
  State<ActivityLog> createState() => _ActivityLogState();
}

class _ActivityLogState extends State<ActivityLog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _filteredActivities = [];
  String? _selectedDateRange;
  String? _selectedActivityType;
  Map<String, List<Map<String, dynamic>>> _groupedActivities = {};

  // Activity types - login/logout are only for visitors
  final List<String> _activityTypes = [
    'All activities',
    'Logins',
    'Logouts',
    'Visits',
    'Approvals',
    'Rejections',
    'Cancellations',
    'Virtual', // Add new activity type
  ];

  final List<String> _dateRanges = [
    'Today',
    'Yesterday',
    'Last 7 days',
    'Last 30 days',
    'All time',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDateRange = _dateRanges[0];
    _selectedActivityType = _activityTypes[0];
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() => _isLoading = true);
    
    try {
      // Calculate date range
      DateTime startDate;
      final now = DateTime.now();
      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      switch (_selectedDateRange) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Yesterday':
          startDate = DateTime(now.year, now.month, now.day - 1);
          break;
        case 'Last 7 days':
          startDate = DateTime(now.year, now.month, now.day - 6);
          break;
        case 'Last 30 days':
          startDate = DateTime(now.year, now.month, now.day - 29);
          break;
        case 'All time':
        default:
          startDate = DateTime(2000);
          break;
      }
      
      // Build query based on activity type
      Query query = FirebaseFirestore.instance.collection('activities');
      
      // Filter by date range
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                  .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      
      // Filter by activity type if needed
      if (_selectedActivityType != 'All activities') {
        String activityTypeFilter;
        
        switch (_selectedActivityType) {
          case 'Logins':
            activityTypeFilter = 'login';
            break;
          case 'Logouts':
            activityTypeFilter = 'logout';
            break;
          case 'Visits':
            activityTypeFilter = 'visit';
            break;
          case 'Approvals':
            activityTypeFilter = 'visit_approved';
            break;
          case 'Rejections':
            activityTypeFilter = 'visit_rejected';
            break;
          case 'Cancellations':
            activityTypeFilter = 'visit_cancelled';
            break;
          case 'Virtual':
            activityTypeFilter = 'visit_ended';
            break;
          default:
            activityTypeFilter = '';
            break;
        }
        
        if (activityTypeFilter.isNotEmpty) {
          query = query.where('type', isEqualTo: activityTypeFilter);
        }
      }
      
      // Order by timestamp (descending)
      query = query.orderBy('timestamp', descending: true);
      
      // Execute query
      final activitiesSnapshot = await query.get();
      
      // Process activities
      final activities = <Map<String, dynamic>>[];
      
      for (final doc in activitiesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        
        if (timestamp == null) continue;
        
        // Get user details if available
        String userName = data['userName'] ?? data['staffName'] ?? 'Unknown User';
        String? userImageUrl;
        String? userImageBase64;
        String userRole = data['userRole'] ?? 'Visitor';
        
        // Try to get the user's profile image if available
        final userId = data['userId'] ?? data['staffId'];
        if (userId != null) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            
            if (userDoc.exists) {
              final userData = userDoc.data();
              if (userData != null) {
                // Get profile image URL or base64
                if (userData['profileImageUrl'] != null) {
                  userImageUrl = userData['profileImageUrl'];
                } else if (userData['profileImageBase64'] != null) {
                  userImageBase64 = userData['profileImageBase64'];
                }
                
                // Get user name
                if (userData['fullName'] != null) {
                  userName = userData['fullName'];
                } else if (userData['firstName'] != null || userData['lastName'] != null) {
                  userName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
                }
                
                // Get user role
                userRole = userData['role'] ?? 'Visitor';
              }
            }
          } catch (e) {
            // Error fetching user details
          }
        }
        
        // Format activity data
        final activityData = {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'timestamp': timestamp,
          'userName': userName,
          'userImageUrl': userImageUrl,
          'userImageBase64': userImageBase64,
          'userRole': userRole,
          'details': getActivityDetails(data),
        };
        
        activities.add(activityData);
      }
      
      // Group activities by date
      final groupedActivities = <String, List<Map<String, dynamic>>>{};
      
      for (final activity in activities) {
        final timestamp = activity['timestamp'] as Timestamp;
        final date = timestamp.toDate();
        final dateKey = getDateKey(date);
        
        if (!groupedActivities.containsKey(dateKey)) {
          groupedActivities[dateKey] = [];
        }
        
        groupedActivities[dateKey]!.add(activity);
      }
      
      if (mounted) {
        setState(() {
          _filteredActivities = activities;
          _groupedActivities = groupedActivities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activities: $e')),
        );
      }
    }
  }

  String getDateKey(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Map<String, dynamic> getActivityDetails(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'unknown';
    
    switch (type) {
      case 'login':
        return {
          'icon': Icons.login,
          'title': 'Logged in',
          'subtitle': 'Successfully logged into the system.',
          'color': Colors.green,
        };
      case 'logout':
        return {
          'icon': Icons.logout,
          'title': 'Logged out',
          'subtitle': 'Successfully logged out of the system.',
          'color': Colors.orange,
        };
      case 'visit_scheduled':
        final visitType = data['visitType'] ?? 'visit';
        return {
          'icon': Icons.calendar_today_outlined,
          'title': 'Visit Scheduled',
          'subtitle': 'Submitted a${visitType == 'virtual' ? ' virtual' : 'n in-person'} visit schedule.',
          'color': Colors.blue,
        };
      case 'visit_approved':
        return {
          'icon': Icons.check_circle_outline,
          'title': 'Visit Approved',
          'subtitle': 'Approved a visitation request.',
          'color': Colors.green,
        };
      case 'visit_rejected':
        return {
          'icon': Icons.cancel_outlined,
          'title': 'Visit Rejected',
          'subtitle': 'Rejected a visitation request.',
          'color': Colors.red,
        };
      case 'visit_cancelled':
        return {
          'icon': Icons.event_busy,
          'title': 'Visit Cancelled',
          'subtitle': 'Cancelled a scheduled visit.',
          'color': Colors.red,
        };
      case 'visit_started':
        final visitType = data['visitType'] ?? 'in-person';
        return {
          'icon': visitType == 'virtual' ? Icons.videocam : Icons.meeting_room,
          'title': '${visitType == 'virtual' ? 'Virtual' : 'In-person'} Visit Started',
          'subtitle': 'Started a ${visitType == 'virtual' ? 'virtual' : 'in-person'} visitation session.',
          'color': Colors.blue,
        };
      case 'visit_ended':
        final visitType = data['visitType'] ?? 'in-person';
        final visitorName = data['userName'] ?? 'Unknown Visitor';
        final sessionDuration = data['sessionDuration'] ?? 0;
        
        return {
          'icon': visitType == 'virtual' ? Icons.videocam_off : Icons.meeting_room_outlined,
          'title': '${visitType == 'virtual' ? 'Virtual' : 'In-person'} Session Ended',
          'subtitle': visitType == 'virtual' 
              ? 'Virtual session ended with $visitorName (Duration: ${sessionDuration}min)'
              : 'In-person session concluded with $visitorName (Duration: ${sessionDuration}min)',
          'color': Colors.green,
        };

      default:
        return {
          'icon': Icons.info_outline,
          'title': 'System Activity',
          'subtitle': 'An activity occurred in the system.',
          'color': Colors.grey,
        };
    }
  }

  void onDateRangeChanged(String? value) {
    if (value != null && value != _selectedDateRange) {
      setState(() {
        _selectedDateRange = value;
      });
      _fetchActivities();
    }
  }

  void onActivityTypeChanged(String? value) {
    if (value != null && value != _selectedActivityType) {
      setState(() {
        _selectedActivityType = value;
      });
      _fetchActivities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Activity Log',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: screenWidth * 0.08,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF054D88),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchActivities,
              child: Container(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter Row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filters',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF054D88),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // Date Range Filter
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedDateRange,
                                    items: _dateRanges
                                        .map((filter) => DropdownMenuItem<String>(
                                              value: filter,
                                              child: Text(
                                                filter,
                                                style: const TextStyle(fontFamily: 'Inter'),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: onDateRangeChanged,
                                    decoration: InputDecoration(
                                      labelText: 'Date Range',
                                      labelStyle: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        color: Color(0xFF054D88),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF054D88)),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Activity Type Filter
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedActivityType,
                                    items: _activityTypes
                                        .map((filter) => DropdownMenuItem<String>(
                                              value: filter,
                                              child: Text(
                                                filter,
                                                style: const TextStyle(fontFamily: 'Inter'),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: onActivityTypeChanged,
                                    decoration: InputDecoration(
                                      labelText: 'Activity Type',
                                      labelStyle: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        color: Color(0xFF054D88),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF054D88)),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
          
                      // Activity List with StreamBuilder for real-time updates
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _buildActivityStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting && _filteredActivities.isEmpty) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading activities: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }
                            
                            // If we have new data, process it
                            if (snapshot.hasData && snapshot.data != null) {
                              _processStreamData(snapshot.data!);
                            }
                            
                            if (_filteredActivities.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.history,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No activities found',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filters',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            return ListView.builder(
                              itemCount: _groupedActivities.length,
                              itemBuilder: (context, index) {
                                final dateKey = _groupedActivities.keys.elementAt(index);
                                final activitiesForDate = _groupedActivities[dateKey]!;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Section Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 20,
                                            color: const Color(0xFF054D88).withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            dateKey,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF054D88),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Activities for this date
                                    ...activitiesForDate.map((activity) {
                                      final details = activity['details'] as Map<String, dynamic>;
                                      final timestamp = activity['timestamp'] as Timestamp;
                                      final time = DateFormat('h:mm a').format(timestamp.toDate());
                                      final activityId = activity['id'] as String;
                                      
                                      return ActivityEntry(
                                        icon: details['icon'],
                                        title: details['title'],
                                        subtitle: details['subtitle'],
                                        time: time,
                                        name: activity['userName'],
                                        userImageUrl: activity['userImageUrl'],
                                        userImageBase64: activity['userImageBase64'],
                                        userRole: activity['userRole'],
                                        activityColor: details['color'] ?? const Color(0xFF054D88),
                                        activityId: activityId,
                                        onDelete: (id) => _deleteActivity(id),
                                      );
                                    }),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Stream<QuerySnapshot> _buildActivityStream() {
    // Calculate date range
    DateTime startDate;
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    switch (_selectedDateRange) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Yesterday':
        startDate = DateTime(now.year, now.month, now.day - 1);
        break;
      case 'Last 7 days':
        startDate = DateTime(now.year, now.month, now.day - 6);
        break;
      case 'Last 30 days':
        startDate = DateTime(now.year, now.month, now.day - 29);
        break;
      case 'All time':
      default:
        startDate = DateTime(2000);
        break;
    }
    
    // Build query based on activity type
    Query query = FirebaseFirestore.instance.collection('activities');
    
    // Filter by date range
    query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    
    // Filter by activity type if needed
    if (_selectedActivityType != 'All activities') {
      String activityTypeFilter;
      
      switch (_selectedActivityType) {
        case 'Logins':
          activityTypeFilter = 'login';
          break;
        case 'Logouts':
          activityTypeFilter = 'logout';
          break;
        case 'Visits':
          activityTypeFilter = 'visit';
          break;
        case 'Approvals':
          activityTypeFilter = 'visit_approved';
          break;
        case 'Rejections':
          activityTypeFilter = 'visit_rejected';
          break;
        case 'Cancellations':
          activityTypeFilter = 'visit_cancelled';
          break;
        case 'Virtual Sessions':
          activityTypeFilter = 'visit_ended';
          break;
        default:
          activityTypeFilter = '';
          break;
      }
      
      if (activityTypeFilter.isNotEmpty) {
        query = query.where('type', isEqualTo: activityTypeFilter);
      }
    }
    
    // Order by timestamp (descending)
    return query.orderBy('timestamp', descending: true).snapshots();
  }

  void _processStreamData(QuerySnapshot snapshot) async {
    try {
      // Process activities
      final activities = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        
        if (timestamp == null) continue;
        
        // Get user details if available
        String userName = data['userName'] ?? data['staffName'] ?? 'Unknown User';
        String? userImageUrl;
        String? userImageBase64;
        String userRole = data['userRole'] ?? 'Visitor';
        
        // Try to get the user's profile image if available
        final userId = data['userId'] ?? data['staffId'];
        if (userId != null) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            
            if (userDoc.exists) {
              final userData = userDoc.data();
              if (userData != null) {
                // Get profile image URL or base64
                if (userData['profileImageUrl'] != null) {
                  userImageUrl = userData['profileImageUrl'];
                } else if (userData['profileImageBase64'] != null) {
                  userImageBase64 = userData['profileImageBase64'];
                }
                
                // Get user name
                if (userData['fullName'] != null) {
                  userName = userData['fullName'];
                } else if (userData['firstName'] != null || userData['lastName'] != null) {
                  userName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
                }
                
                // Get user role
                userRole = userData['role'] ?? 'Visitor';
              }
            }
          } catch (e) {
            // Error fetching user details
          }
        }
        
        // Format activity data
        final activityData = {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'timestamp': timestamp,
          'userName': userName,
          'userImageUrl': userImageUrl,
          'userImageBase64': userImageBase64,
          'userRole': userRole,
          'details': getActivityDetails(data),
        };
        
        activities.add(activityData);
      }
      
      // Group activities by date
      final groupedActivities = <String, List<Map<String, dynamic>>>{};
      
      for (final activity in activities) {
        final timestamp = activity['timestamp'] as Timestamp;
        final date = timestamp.toDate();
        final dateKey = getDateKey(date);
        
        if (!groupedActivities.containsKey(dateKey)) {
          groupedActivities[dateKey] = [];
        }
        
        groupedActivities[dateKey]!.add(activity);
      }
      
      if (mounted) {
        setState(() {
          _filteredActivities = activities;
          _groupedActivities = groupedActivities;
        });
      }
    } catch (e) {
      // Error processing stream data
    }
  }

  Future<void> _deleteActivity(String activityId) async {
    try {
      setState(() => _isLoading = true);
      
      // Delete the activity document from Firestore
      await FirebaseFirestore.instance
        .collection('activities')
        .doc(activityId)
        .delete();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Refresh the activity list
      await _fetchActivities();
    } catch (e) {
      debugPrint('Error deleting activity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting activity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class ActivityEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final String name;
  final String? userImageUrl;
  final String? userImageBase64;
  final String userRole;
  final Color activityColor;
  final String activityId;
  final Function(String) onDelete;

  const ActivityEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.name,
    this.userImageUrl,
    this.userImageBase64,
    required this.userRole,
    required this.activityColor,
    required this.activityId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(activityId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 28,
            ),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Activity'),
            content: const Text('Are you sure you want to delete this activity? This action cannot be undone.'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        onDelete(activityId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row for Icon, Title, and Time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: activityColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Row for Profile Picture and Name
            Row(
              children: [
                // User Profile Picture
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activityColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    image: _buildProfileImage(),
                  ),
                  child: _buildProfileImage() == null
                      ? Icon(
                          _getUserIcon(),
                          color: activityColor,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF054D88),
                        ),
                      ),
                      Text(
                        userRole,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Slide hint icon
                Icon(
                  Icons.keyboard_arrow_left,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                Text(
                  'Slide to delete',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DecorationImage? _buildProfileImage() {
    if (userImageUrl != null) {
      return DecorationImage(
        image: NetworkImage(userImageUrl!),
        fit: BoxFit.cover,
      );
    } else if (userImageBase64 != null) {
      try {
        return DecorationImage(
          image: MemoryImage(base64Decode(userImageBase64!)),
          fit: BoxFit.cover,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  IconData _getUserIcon() {
    switch (userRole.toLowerCase()) {
      case 'staff':
      case 'admin':
        return Icons.admin_panel_settings;
      case 'visitor':
      default:
        return Icons.person;
    }
  }
}
