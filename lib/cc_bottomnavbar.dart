import 'package:flutter/material.dart';
import 'cc_homepage.dart';
import 'cc_calendarpage.dart';
import 'cc_notifipage.dart';
import 'cc_userprofile.dart';
import 'cc_dashboard.dart';
import 'cc_managepage.dart';
import 'cc_activitylog.dart';
import 'cc_database.dart';

class BottomNavBar extends StatefulWidget {
  final String role; // Role to determine navigation (Visitor or Staff)

  const BottomNavBar({super.key, required this.role, required String userName});

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;

  late List<Widget> _visitorPages; // Pages for Visitor
  late List<Widget> _staffPages;   // Pages for Staff

  @override
  void initState() {
    super.initState();

    // Define pages for Visitor
    _visitorPages = [
      HomePage(role: '', userName: '',),                   // Visitor Home Page
      const CalendarPage(events: [],),              // Visitor Calendar Page
      const NotificationsPage(),        // Visitor Notifications Page
      const UserProfilePage(),         // Visitor Profile Page
    ];

    // Define pages for Staff
    _staffPages = [
      const DashboardPage(),           // Staff Dashboard Page
      const ManagePage(),              // Staff Manage Page
      const ActivityLog(),            // Staff Activity Page
      const DatabasePage(),            // Staff Database Page
    ];
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
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Notifications',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }
}
