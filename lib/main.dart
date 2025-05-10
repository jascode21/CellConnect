import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'cc_signup.dart';
import 'cc_verifyemail.dart';
import 'cc_inmatesdeets.dart';
import 'cc_login.dart';
import 'cc_verification.dart';
import 'cc_bottomnavbar.dart';
import 'cc_homepage.dart';
import 'cc_inpersonvisit.dart';
import 'cc_virtualvisit.dart';
import 'cc_notifipage.dart';
import 'cc_calendarpage.dart';
import 'cc_userprofile.dart';
import 'cc_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
    apiKey: "AIzaSyB26Z9zg8faccznzA4msKIUwN4_ihQIymg",
    authDomain: "cellconnect-4530f.firebaseapp.com",
    projectId: "cellconnect-4530f",
    storageBucket: "cellconnect-4530f.firebasestorage.app",
    messagingSenderId: "1021098978863",
    appId: "1:1021098978863:web:f5792c6bceee3e6d7020da"
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
      ),
      initialRoute: '/logIn', // Changed initial route to signUp for testing
      routes: {
        '/signUp': (context) => const SignupPage(),
        '/verifyEmail': (context) => VerifyEmailPage(
              email: ModalRoute.of(context)?.settings.arguments as String? ?? '',
              verificationCode: '', // Code will be passed when navigating
              role: '', // Role will be passed when navigating
              firstName: '', // First name will be passed when navigating
              lastName: '', // Last name will be passed when navigating
            ),
        '/inmateDetails': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, String>? ?? {};
          return InmateDetailsPage(
            email: arguments['email'] ?? '',
            role: arguments['role'] ?? '', firstName: '', lastName: '',
          );
        },
        '/logIn': (context) => const LoginPage(),
        '/verification': (context) => const VerificationPage(email: '', verificationCode: '', role: '', firstName: '', lastName: '', inmateFirstName: '', inmateLastName: '', relationship: '',),
        '/home': (context) => const BottomNavBar(role: 'Visitor', userName: '',),
        '/visitorPage': (context) => HomePage(role: '', userName: '',),
        '/inPersonVisit': (context) => const InPersonVisitPage(),
        '/virtualVisit': (context) => const VirtualVisitPage(),
        '/calendarPage': (context) => const CalendarPage(events: [],),
        '/notifPage': (context) => const NotificationsPage(),
        '/userProfile': (context) => const UserProfilePage(),
        '/staffPage': (context) => const BottomNavBar(role: 'Staff', userName: '',),
        '/dashBoard': (context) => const DashboardPage(),
      },
    );
  }
}