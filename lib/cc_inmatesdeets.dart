import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';
import 'cc_verification.dart';

class InmateDetailsPage extends StatefulWidget {
  final String email;
  final String role;
  final String firstName;
  final String lastName;

  const InmateDetailsPage({
    super.key,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<InmateDetailsPage> createState() => _InmateDetailsPageState();
}

class _InmateDetailsPageState extends State<InmateDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _inmateFirstNameController = TextEditingController();
  final _inmateLastNameController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _isLoading = false;

  Future<void> _proceedToVerification(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Generate verification code
      final verificationCode = randomNumeric(4);
      print('Verification code: $verificationCode'); // For testing only

      // Navigate to verification page with all required data
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationPage(
            email: widget.email,
            verificationCode: verificationCode,
            role: widget.role,
            firstName: widget.firstName,
            lastName: widget.lastName,
            inmateFirstName: _inmateFirstNameController.text.trim(),
            inmateLastName: _inmateLastNameController.text.trim(),
            relationship: _relationshipController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _inmateFirstNameController.dispose();
    _inmateLastNameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 70),
              const Text(
                'Inmate Details',
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _inmateFirstNameController,
                decoration: const InputDecoration(
                  labelText: 'Inmate First Name',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter inmate first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _inmateLastNameController,
                decoration: const InputDecoration(
                  labelText: 'Inmate Last Name',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter inmate last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Your Relationship to Inmate',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color.fromARGB(255, 5, 77, 136),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your relationship';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () => _proceedToVerification(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                        ),
                        child: const Text(
                          'Verify Identity',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}