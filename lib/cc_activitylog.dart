import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  final List<String> _dateRanges = [
    'Today',
    'Yesterday',
    'Last 7 days',
    'Last 30 days',
    'All time',
  ];

  final List<String> _activityTypes = [
    'All activities',
    'Logins',
    'Visits',
    'Approvals',
    'Rejections',
    'Cancellations',
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
        String userImageUrl = 'https://pbs.twimg.com/media/FxJUoDVWIAAX2dq.jpg'; // Default image
        
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
                if (userData['profileImageUrl'] != null) {
                  userImageUrl = userData['profileImageUrl'];
                }
                if (userData['fullName'] != null) {
                  userName = userData['fullName'];
                } else if (userData['firstName'] != null || userData['lastName'] != null) {
                  userName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
                }
              }
            }
          } catch (e) {
            // Error fetching user details: $e
          }
        }
        
        // Format activity data
        final activityData = {
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'timestamp': timestamp,
          'userName': userName,
          'userImageUrl': userImageUrl,
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
      // Error fetching activities: $e
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
        };
      case 'logout':
        return {
          'icon': Icons.logout,
          'title': 'Logged out',
          'subtitle': 'Successfully logged out of the system.',
        };
      case 'visit_scheduled':
        final visitType = data['visitType'] ?? 'visit';
        return {
          'icon': Icons.calendar_today_outlined,
          'title': 'Visit Scheduled',
          'subtitle': 'Submitted a${visitType == 'virtual' ? ' virtual' : 'n in-person'} visit schedule.',
        };
      case 'visit_approved':
        return {
          'icon': Icons.check_circle_outline,
          'title': 'Visit Approved',
          'subtitle': 'Approved a visitation request.',
        };
      case 'visit_rejected':
        return {
          'icon': Icons.cancel_outlined,
          'title': 'Visit Rejected',
          'subtitle': 'Rejected a visitation request.',
        };
      case 'visit_cancelled':
        return {
          'icon': Icons.event_busy,
          'title': 'Visit Cancelled',
          'subtitle': 'Cancelled a scheduled visit.',
        };
      case 'visit_started':
        final visitType = data['visitType'] ?? 'in-person';
        return {
          'icon': visitType == 'virtual' ? Icons.videocam : Icons.meeting_room,
          'title': '${visitType == 'virtual' ? 'Virtual' : 'In-person'} Visit Started',
          'subtitle': 'Started a ${visitType == 'virtual' ? 'virtual' : 'in-person'} visitation session.',
        };
      case 'visit_ended':
        final visitType = data['visitType'] ?? 'in-person';
        return {
          'icon': Icons.check_circle_outline,
          'title': '${visitType == 'virtual' ? 'Virtual' : 'In-person'} Visit Ended',
          'subtitle': 'Concluded the ${visitType == 'virtual' ? 'virtual' : 'in-person'} session.',
        };
      default:
        return {
          'icon': Icons.info_outline,
          'title': 'System Activity',
          'subtitle': 'An activity occurred in the system.',
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
          style: TextStyle(fontFamily: 'Inter', fontSize: screenWidth * 0.08, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchActivities,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Row
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
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
            
                    // Activity List
                    Expanded(
                      child: _filteredActivities.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No activities found',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _groupedActivities.length,
                              itemBuilder: (context, index) {
                                final dateKey = _groupedActivities.keys.elementAt(index);
                                final activitiesForDate = _groupedActivities[dateKey]!;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Section Header
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(
                                        dateKey,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    
                                    // Activities for this date
                                    ...activitiesForDate.map((activity) {
                                      final details = activity['details'] as Map<String, dynamic>;
                                      final timestamp = activity['timestamp'] as Timestamp;
                                      final time = DateFormat('h:mm a').format(timestamp.toDate());
                                      
                                      return ActivityEntry(
                                        icon: details['icon'],
                                        title: details['title'],
                                        subtitle: details['subtitle'],
                                        time: time,
                                        name: activity['userName'],
                                        imageUrl: activity['userImageUrl'],
                                      );
                                    }),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class ActivityEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final String name;
  final String imageUrl;

  const ActivityEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.name,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row for Icon, Title, and Time
          Row(
            children: [
              Icon(
                icon,
                color: const Color.fromARGB(255, 5, 77, 136),
                size: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Subtitle
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          // Row for Profile Picture and Name
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage(imageUrl),
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Divider(thickness: 1, color: Colors.grey),
        ],
      ),
    );
  }
}
