import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';
import 'cc_inmatesdeets.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;
  final String verificationCode;
  final String role;
  final String firstName;
  final String lastName;

  const VerifyEmailPage({
    super.key,
    required this.email,
    required this.verificationCode,
    required this.role,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final List<TextEditingController> _codeControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    });
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(String value, int index) {
    if (value.isNotEmpty && index < 3) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (index == 3 && value.isNotEmpty) {
      _verifyCode();
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _isVerifying = true);
    
    try {
      final enteredCode = _codeControllers.map((c) => c.text).join();
      
      if (enteredCode == widget.verificationCode) {
        // Navigate immediately without waiting for Firestore
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InmateDetailsPage(
              email: widget.email,
              role: widget.role, firstName: '', lastName: '',
            ),
          ),
        );

        // Save data in background after navigation
        _saveUserDataInBackground();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code is incorrect')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _saveUserDataInBackground() async {
    try {
      final docId = widget.email.replaceAll('.', '_').replaceAll('@', '_');
      await FirebaseFirestore.instance.collection('users').doc(docId).set({
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'email': widget.email,
        'role': widget.role,
        'emailVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('User data saved successfully');
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    
    try {
      final newVerificationCode = randomNumeric(4);
      await _sendVerificationEmail(widget.email, newVerificationCode);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New verification code sent')),
      );
      
      for (var controller in _codeControllers) {
        controller.clear();
      }
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend code: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _sendVerificationEmail(String email, String code) async {
    print('Sending verification code: $code to $email');
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Verify your email',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter the 4-digit code sent to ${widget.email}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (index) => SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _codeControllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) => _onCodeChanged(value, index),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: _isResending
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _resendCode,
                      child: const Text(
                        'Resend Code',
                        style: TextStyle(
                          color: Color(0xFF054D88),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF054D88),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text(
                      'Verify Email',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? '),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/logIn'),
                  child: const Text(
                    'Log In',
                    style: TextStyle(
                      color: Color(0xFF054D88),
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