import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cc_bottomnavbar.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // Function to handle user login with Firebase
  Future<void> _loginUser(BuildContext context, String email, String password) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Authenticate with Firebase
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Get user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // Close loading dialog
      Navigator.of(context).pop();

      if (userDoc.exists) {
        // Get user role and name
        String role = userDoc['role'] ?? 'Visitor';
        String name = userDoc['name'] ?? 'User';

        // Navigate to home with user data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BottomNavBar(role: role, userName: name),
          ),
        );
      } else {
        // Handle case where user data doesn't exist
        _showErrorDialog(context, 'User data not found. Please contact support.');
      }
    } on FirebaseAuthException catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is invalid.';
      } else {
        errorMessage = 'Login failed. Please try again.';
      }
      _showErrorDialog(context, errorMessage);
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      _showErrorDialog(context, 'An unexpected error occurred. Please try again.');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Controllers for capturing input
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Log In', style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold)),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(fontFamily: 'Inter', fontSize: 20, color: Color.fromARGB(255, 5, 77, 136)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(fontFamily: 'Inter', fontSize: 20, color: Color.fromARGB(255, 5, 77, 136)),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  final email = emailController.text.trim();
                  final password = passwordController.text.trim();

                  if (email.isEmpty || password.isEmpty) {
                    _showErrorDialog(context, 'Please enter both email and password.');
                  } else {
                    _loginUser(context, email, password);
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                child: const Text(
                  'Log In',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 18, color: Color.fromARGB(255, 255, 255, 255)),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () {
                  // Add forgot password functionality
                  // You can implement password reset here
                  // FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(fontFamily: 'Inter', color: Color.fromARGB(255, 72, 72, 72)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Colors.black54, fontFamily: 'Inter', fontWeight: FontWeight.w400),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/signUp');
                  },
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: Color.fromARGB(255, 5, 77, 136),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}