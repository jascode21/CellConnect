import 'package:cellconnect/cc_video_call.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Notification Service to manage notifications
class NotificationService {
static final NotificationService _instance = NotificationService._internal();
factory NotificationService() => _instance;
NotificationService._internal();

// Get notifications from Firestore
Future<List<Map<String, dynamic>>> getNotifications() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];
  
  try {
    final notificationsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();
    
    return notificationsSnapshot.docs.map((doc) {
      final data = doc.data();
      
      // Determine icon and color based on notification type
      IconData icon;
      Color color;
      String type = data['type'] ?? '';
      
      switch (type) {
        case 'visit_approved':
          icon = Icons.check_circle;
          color = Colors.green;
          break;
        case 'visit_rejected':
          icon = Icons.cancel;
          color = Colors.red;
          break;
        case 'visit_started':
          icon = Icons.play_circle_fill;
          color = Colors.blue;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.orange;
      }
      
      return {
        'id': doc.id,
        'title': data['title'] ?? 'Notification',
        'description': data['description'] ?? 'You have a new notification',
        'date': data['date'] ?? DateFormat('MMMM d, yyyy').format(DateTime.now()),
        'icon': icon,
        'iconColor': color,
        'read': data['read'] ?? false,
        'timestamp': data['timestamp'] ?? Timestamp.now(),
        'type': type, // Include the type
        'visitationCode': data['visitationCode'] ?? '', // <-- Add this line
      };
    }).toList();
  } catch (e) {
    return [];
  }
}

// Mark notification as read
Future<void> markAsRead(String notificationId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({
      'read': true,
    });
  } catch (e) {
    // Handle error silently
  }
}

// Mark all notifications as read
Future<void> markAllAsRead() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  try {
    final batch = FirebaseFirestore.instance.batch();
    final notificationsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    
    for (final doc in notificationsSnapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    
    await batch.commit();
  } catch (e) {
    // Handle error silently
  }
}
}

// Notifications Page
class NotificationsPage extends StatefulWidget {
const NotificationsPage({super.key});

@override
State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
final NotificationService _notificationService = NotificationService();
List<Map<String, dynamic>> _notifications = [];
bool _isLoading = true;

@override
void initState() {
  super.initState();
  _loadNotifications();
}

Future<void> _loadNotifications() async {
  setState(() => _isLoading = true);
  
  try {
    final notifications = await _notificationService.getNotifications();
    
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
      
      // Show tutorial for swipe-to-delete feature
      _showSwipeTutorial();
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

Future<void> _markAllAsRead() async {
  try {
    await _notificationService.markAllAsRead();
    await _loadNotifications();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    // Handle error silently
  }
}

Future<void> _deleteNotification(String notificationId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
    await _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting notification: $e')),
      );
    }
  }
}

  // Show tutorial for swipe-to-delete feature
  void _showSwipeTutorial() {
    // Use SharedPreferences in a real app to check if tutorial has been shown before
    // For now, we'll just show it every time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_notifications.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.swipe, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Swipe left on a notification to delete it',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });
  }

@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final unreadCount = _notifications.where((n) => !n['read']).length;

  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        'Notifications',
        style: TextStyle(
          fontSize: screenWidth * 0.08,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      actions: [
        TextButton(
          onPressed: unreadCount > 0 ? _markAllAsRead : null,
          child: Text(
            'Read all ($unreadCount)',
            style: TextStyle(
              color: const Color.fromARGB(255, 5, 77, 136),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadNotifications,
            child: _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
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
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Dismissible(
                        key: Key(notification['id']),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          // Show confirmation dialog
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Delete Notification?'),
                                content: const Text('Are you sure you want to delete this notification?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          _deleteNotification(notification['id']);
                        },
                        background: Container(
                          color: Colors.red,
                          margin: const EdgeInsets.only(bottom: 12),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 30,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: NotificationCard(
                          id: notification['id'],
                          title: notification['title'],
                          description: notification['description'],
                          date: notification['date'],
                          icon: notification['icon'],
                          iconColor: notification['iconColor'],
                          isRead: notification['read'],
                          type: notification['type'] ?? '',
                          visitationCode: notification['visitationCode'] ?? '',
                          onTap: () async {
                            if (!notification['read']) {
                              await _notificationService.markAsRead(notification['id']);
                              _loadNotifications();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
  );
}
}

// Notification Card Widget
class NotificationCard extends StatelessWidget {
final String id;
final String title;
final String description;
final String date;
final IconData icon;
final Color iconColor;
final bool isRead;
final VoidCallback onTap;
final String type;
final String visitationCode;

const NotificationCard({
  super.key,
  required this.id,
  required this.title,
  required this.description,
  required this.date,
  required this.icon,
  required this.iconColor,
  required this.isRead,
  required this.onTap,
  this.type = '',
  this.visitationCode = '',
});

@override
Widget build(BuildContext context) {
  bool isVirtualStarted = type == 'visit_started' && description.contains('Virtual');
  
  return Card(
    elevation: isRead ? 1 : 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.only(bottom: 12),
    color: isRead ? Colors.white : const Color(0xFFF5F7FA),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: iconColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (isVirtualStarted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (visitationCode.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EnhancedVideoCallPage(
                            appId: '81bb421e4db9457f9522222420e2841c',
                            channelName: visitationCode,
                            userName: 'User',
                            role: 'Visitor',
                            token: '',
                          ),
                        ),
                      );
                    } else {
                      Navigator.pushNamed(context, '/home');
                    }
                  },
                  icon: const Icon(Icons.video_call),
                  label: const Text('Join Virtual Visit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            // Remove the conditional delete button for cancelled notifications since we now have a delete option for all notifications
          ],
        ),
      ),
    ),
  );
}
}
