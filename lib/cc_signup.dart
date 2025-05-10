import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:random_string/random_string.dart';

import 'cc_verifyemail.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? selectedRole;

  Future<void> _signUp(BuildContext context) async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role.')),
      );
      return;
    }

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        final String verificationCode = randomNumeric(4);
        // Simulate sending email (replace with actual email sending)
        _sendVerificationEmail(_emailController.text.trim(), verificationCode);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailPage(
              email: _emailController.text.trim(),
              verificationCode: verificationCode,
              role: selectedRole!,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during sign up.';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is invalid.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    }
  }

  // Function to simulate sending verification email
  Future<void> _sendVerificationEmail(String email, String code) async {
    // In a real application, you would use a service like Firebase Cloud Functions
    // along with an email sending service (e.g., SendGrid, Mailgun) to send emails.
    // For this example, we'll just print the code.
    print('Sending verification code: $code to $email');

    // Replace the following with your actual email sending logic
    // For example, using the mailer package:
    // import 'package:mailer/mailer.dart';
    // import 'package:mailer/smtp_server/gmail.dart';
    //
    // final smtpServer = gmail('your_email@gmail.com', 'your_password');
    // final message = Message()
    //   ..from = const Address('your_email@gmail.com', 'Your App Name')
    //   ..recipients.add(email)
    //   ..subject = 'Verify Your Email'
    //   ..html = 'Your verification code is: <b>$code</b>';
    //
    // try {
    //   final sendReport = await send(message, smtpServer);
    //   print('Message sent: ${sendReport.toString()}');
    // } catch (e) {
    //   print('Error sending email: $e');
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Prevents overflow when keyboard appears
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                items: ['Visitor', 'Staff']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRole = value; // Update selected role
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Select Role',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () => _signUp(context),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      color: Colors.black54,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/logIn');
                    },
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: Color.fromARGB(255, 5, 77, 136),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}