import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'cc_userdetails.dart';
import 'cc_historypage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyB26Z9zg8faccznzA4msKIUwN4_ihQIymg",
        authDomain: "cellconnect-4530f.firebaseapp.com",
        projectId: "cellconnect-4530f",
        storageBucket: "cellconnect-4530f.firebasestorage.app",
        messagingSenderId: "1021098978863",
        appId: "1:1021098978863:web:f5792c6bceee3e6d7020da",
      ),
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization failed: $e");
  }
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
      home: AuthCheck(),
      routes: {
        '/signUp': (context) => const SignupPage(),
        '/verifyEmail': (context) => VerifyEmailPage(
              email: ModalRoute.of(context)?.settings.arguments as String? ?? '',
              verificationCode: '',
              role: '',
              firstName: '',
              lastName: '',
            ),
        '/inmateDetails': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, String>? ?? {};
          return InmateDetailsPage(
            email: arguments['email'] ?? '',
            role: arguments['role'] ?? '',
            firstName: '',
            lastName: '',
          );
        },
        '/logIn': (context) => const LoginPage(),
        '/verification': (context) => const VerificationPage(
              email: '',
              verificationCode: '',
              role: '',
              firstName: '',
              lastName: '',
              inmateFirstName: '',
              inmateLastName: '',
              relationship: '',
            ),
        '/home': (context) => const BottomNavBar(role: 'Visitor', userName: ''),
        '/visitorPage': (context) => HomePage(role: '', userName: ''),
        '/inPersonVisit': (context) => const InPersonVisitPage(),
        '/virtualVisit': (context) => const VirtualVisitPage(),
        '/calendarPage': (context) => const CalendarPage(events: []),
        '/notifPage': (context) => const NotificationsPage(),
        '/userProfile': (context) => const UserProfilePage(),
        '/staffPage': (context) => const BottomNavBar(role: 'Staff', userName: ''),
        '/dashBoard': (context) => const DashboardPage(),
        '/userDetails': (context) {
          final userId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return UserDetailsPage(userId: userId);
        },
        '/history': (context) => const HistoryPage(),
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoading = true;
  String? _initialRoute;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    print("Checking authentication state...");
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      print("Auth state changed: user = ${user?.uid}");
      if (user == null) {
        setState(() {
          _initialRoute = '/logIn';
          _isLoading = false;
        });
      } else {
        print("Fetching user data for UID: ${user.uid}");
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .then((doc) {
          print("Firestore response: exists = ${doc.exists}");
          if (doc.exists) {
            final userData = doc.data() as Map<String, dynamic>;
            print("User data: $userData");
            String role = userData['role'] ?? 'Visitor';
            String firstName = userData['firstName'] ?? '';
            String lastName = userData['lastName'] ?? '';
            String fullName = userData['fullName'] ?? '$firstName $lastName'.trim();

            if (fullName.isEmpty) fullName = 'User';

            setState(() {
              _initialRoute = '/home';
              _isLoading = false;
            });

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BottomNavBar(
                  role: role,
                  userName: fullName,
                ),
              ),
            );
          } else {
            print("User document does not exist");
            setState(() {
              _initialRoute = '/logIn';
              _isLoading = false;
            });
          }
        }).catchError((error) {
          print("Error fetching user data: $error");
          setState(() {
            _initialRoute = '/logIn';
            _isLoading = false;
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_initialRoute == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error: Unable to initialize app'),
        ),
      );
    } else {
      return Navigator(
        initialRoute: _initialRoute,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/logIn':
              return MaterialPageRoute(builder: (context) => const LoginPage());
            case '/home':
              return MaterialPageRoute(builder: (context) => const BottomNavBar(role: 'Visitor', userName: ''));
            default:
              return null;
          }
        },
      );
    }
  }
}
