import 'package:flutter/material.dart';
import 'cc_homepage.dart';
import 'cc_calendarpage.dart';
import 'cc_notifipage.dart';
import 'cc_userprofile.dart';
import 'cc_dashboard.dart';
import 'cc_managepage.dart';
import 'cc_activitylog.dart';
import 'cc_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BottomNavBar extends StatefulWidget {
  final String role; // Role to determine navigation (Visitor or Staff)
  final String userName; // User's name to display

  const BottomNavBar({
    super.key, 
    required this.role, 
    required this.userName
  });

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  int _unreadCount = 0;

  late List<Widget> _visitorPages; // Pages for Visitor
  late List<Widget> _staffPages;   // Pages for Staff

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _setupNotificationListener();

    // Define pages for Visitor
    _visitorPages = [
      HomePage(role: widget.role, userName: widget.userName),
      const CalendarPage(events: []),
      const NotificationsPage(),
      const UserProfilePage(),
    ];

    // Define pages for Staff
    _staffPages = [
      const DashboardPage(),
      const ManagePage(),
      const ActivityLog(),
      const DatabasePage(),
    ];
  }

  void _setupNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .get();
        
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      } catch (e) {
        debugPrint('Error loading unread count: $e');
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine pages and navigation items based on role
    final isStaff = widget.role == 'Staff';
    final pages = isStaff ? _staffPages : _visitorPages;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color.fromARGB(255, 0, 0, 0),
        unselectedItemColor: const Color.fromARGB(255, 5, 77, 136),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: isStaff
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.manage_accounts),
                  label: 'Manage',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list),
                  label: 'Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.storage),
                  label: 'Database',
                ),
              ]
            : [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      const Icon(Icons.notifications),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Notifications',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }
}
