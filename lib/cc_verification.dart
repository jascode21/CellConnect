import 'package:cellconnect/cc_homepage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class VerificationPage extends StatefulWidget {
  final String email;
  final String verificationCode;
  final String role;
  final String firstName;
  final String lastName;
  final String inmateFirstName;
  final String inmateLastName;
  final String relationship;

  const VerificationPage({
    super.key,
    required this.email,
    required this.verificationCode,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.inmateFirstName,
    required this.inmateLastName,
    required this.relationship,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String? _selectedIdType;
  bool _isVerifying =
      false; // Added for the loading state in the button, and to prevent multiple submissions

  Future<void> _completeRegistration(BuildContext context) async {
    if (_selectedIdType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an ID type')),
      );
      return;
    }

    if (_isVerifying) return; // Prevent multiple submissions
    setState(() => _isVerifying = true);

    try {
      final sanitizedEmail = widget.email.replaceAll('.', '_');

      // Save all data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(sanitizedEmail)
          .set({
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'email': widget.email,
        'role': widget.role,
        'verificationMethod': _selectedIdType,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(sanitizedEmail)
          .collection('inmates')
          .add({
        'firstName': widget.inmateFirstName,
        'lastName': widget.inmateLastName,
        'relationship': widget.relationship,
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      // Navigate to the home page after successful verification
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            role: widget.role,
            userName: widget.firstName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return; //check if the widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
      setState(() => _isVerifying =
          false); // set it back to false, so user can try again
    } finally {
      if (mounted)
        setState(() =>
            _isVerifying =
                false); // Ensure _isVerifying is set to false after completion
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verification',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Choose your ID',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                color: Color.fromARGB(255, 5, 77, 136),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: _selectedIdType,
              items: const [
                DropdownMenuItem(value: 'umid', child: Text('UMID')),
                DropdownMenuItem(value: 'drivers_license', child: Text('Driver\'s License')),
                DropdownMenuItem(value: 'passport', child: Text('Passport')),
                DropdownMenuItem(value: 'ephilid', child: Text('ePhilID')),
                DropdownMenuItem(value: 'philhealth_id', child: Text('PhilHealth ID')),
                DropdownMenuItem(value: 'postal_id', child: Text('Postal ID')),
                DropdownMenuItem(value: 'voters_id', child: Text('Voter\'s ID')),
              ],
              onChanged: (value) {
                setState(() => _selectedIdType = value);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  _selectedIdType == null ? null : () => _completeRegistration(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                minimumSize: const Size(double.infinity, 0),
              ),
              child: _isVerifying
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Verifying...',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                        SizedBox(width: 10),
                        CircularProgressIndicator(color: Colors.white),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Complete Verification',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

