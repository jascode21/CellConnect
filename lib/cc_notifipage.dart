import 'package:flutter/material.dart';

// Notification Service to manage notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  List<Map<String, dynamic>> notifications = [];

  void addNotification(String title, String description, String date, IconData icon, Color iconColor) {
    notifications.add({
      'title': title,
      'description': description,
      'date': date,
      'icon': icon,
      'iconColor': iconColor,
    });
  }

  List<Map<String, dynamic>> getNotifications() {
    return notifications;
  }
}

// Notifications Page
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final notifications = NotificationService().getNotifications();

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
            onPressed: () {
              // Implement the "Read All" functionality
            },
            child: Text(
              'Read all (${notifications.length})',
              style: TextStyle(
                color: const Color.fromARGB(255, 5, 77, 136),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: notifications.map((notification) {
            return NotificationCard(
              title: notification['title'],
              description: notification['description'],
              date: notification['date'],
              icon: notification['icon'],
              iconColor: notification['iconColor'],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Notification Card Widget
class NotificationCard extends StatelessWidget {
  final String title;
  final String description;
  final String date;
  final IconData icon;
  final Color iconColor;

  const NotificationCard({
    super.key,
    required this.title,
    required this.description,
    required this.date,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 50,
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
                      color: Colors.black,
                    ),
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
      ),
    );
  }
}