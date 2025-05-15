import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cc_inmatesdeets.dart';
import 'cc_bottomnavbar.dart';

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

class _VerifyEmailPageState extends State<VerifyEmailPage> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _codeControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  String _currentVerificationCode = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _currentVerificationCode = widget.verificationCode;
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
      _animationController.forward();
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
    _animationController.dispose();
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
      
      if (enteredCode == _currentVerificationCode) {
        // Save basic user data to Firestore
        await _saveBasicUserData();
        
        // For Staff/Admin users, navigate directly to dashboard after email verification
        if (widget.role == 'Staff') {
          if (!mounted) return;
          
          // Show success animation
          _showSuccessAnimation();
          
          // Navigate to dashboard after a short delay
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BottomNavBar(
                  role: 'Staff',
                  userName: '${widget.firstName} ${widget.lastName}',
                ),
              ),
            );
          });
          return;
        }
        
        // For Visitors, continue with the normal flow
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InmateDetailsPage(
              email: widget.email,
              role: widget.role,
              firstName: widget.firstName,
              lastName: widget.lastName,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code is incorrect'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Shake animation for incorrect code
        _shakeInputFields();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }
  
  void _shakeInputFields() {
    // Create a shake animation for the input fields
    final shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    Tween<Offset>(
      begin: const Offset(-0.05, 0.0),
      end: const Offset(0.05, 0.0),
    ).animate(CurvedAnimation(
      parent: shakeController,
      curve: Curves.elasticIn,
    ));
    
    shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        shakeController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        shakeController.dispose();
      }
    });
    
    shakeController.forward();
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26), // 0.1 opacity
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 80,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveBasicUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'email': widget.email,
        'role': widget.role,
        'emailVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      throw e; // Re-throw to handle in calling function
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    
    try {
      final newVerificationCode = randomNumeric(4);
      await _sendVerificationEmail(widget.email, newVerificationCode);
      
      setState(() {
        _currentVerificationCode = newVerificationCode;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New verification code sent'),
          backgroundColor: Colors.green,
        ),
      );
      
      for (var controller in _codeControllers) {
        controller.clear();
      }
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend code: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _sendVerificationEmail(String email, String code) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF054D88).withAlpha(204), // 0.8 opacity
              const Color(0xFF054D88).withAlpha(153), // 0.6 opacity
              Colors.white,
            ],
            stops: const [0.0, 0.2, 0.5],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                
                SizedBox(height: screenHeight * 0.02),
                
                // Email icon with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF054D88).withAlpha(77), // 0.3 opacity
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.email_outlined,
                            size: 60,
                            color: Color(0xFF054D88),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Header text with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        const Text(
                          'Verify your email',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter the 4-digit code sent to ${widget.email}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withAlpha(230), // 0.9 opacity
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: screenHeight * 0.05),
                
                // Verification code inputs with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26), // 0.1 opacity
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              4,
                              (index) => SizedBox(
                                width: 60,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0.0, end: 1.0),
                                  duration: Duration(milliseconds: 400 + (index * 100)),
                                  curve: Curves.easeOutBack,
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: child,
                                    );
                                  },
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
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF5F7FA),
                                    ),
                                    onChanged: (value) => _onCodeChanged(value, index),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Verify button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isVerifying ? null : _verifyCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF054D88),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                elevation: 4,
                                shadowColor: const Color(0xFF054D88).withAlpha(102), // 0.4 opacity
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isVerifying
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Verify Email',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Resend code button
                          TextButton.icon(
                            onPressed: _isResending ? null : _resendCode,
                            icon: _isResending
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF054D88),
                                    ),
                                  )
                                : const Icon(Icons.refresh, size: 16),
                            label: Text(
                              _isResending ? 'Sending...' : 'Resend Code',
                              style: const TextStyle(
                                color: Color(0xFF054D88),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Login link with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/logIn'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF054D88),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Log In'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
