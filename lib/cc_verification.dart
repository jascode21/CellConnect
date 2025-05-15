import 'package:cellconnect/cc_homepage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class _VerificationPageState extends State<VerificationPage> with SingleTickerProviderStateMixin {
  String? _selectedIdType;
  bool _isVerifying = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
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
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _completeRegistration(BuildContext context) async {
    if (_selectedIdType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an ID type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Save all data to Firestore using the UID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'email': widget.email,
        'role': widget.role,
        'verificationMethod': _selectedIdType,
        'verifiedAt': FieldValue.serverTimestamp(),
        'fullName': '${widget.firstName} ${widget.lastName}',
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inmates')
          .add({
        'firstName': widget.inmateFirstName,
        'lastName': widget.inmateLastName,
        'fullName': '${widget.inmateFirstName} ${widget.inmateLastName}',
        'relationship': widget.relationship,
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      // Show success animation before navigating
      _showSuccessAnimation();
      
      // Navigate to the home page after successful verification
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              role: widget.role,
              userName: '${widget.firstName} ${widget.lastName}',
            ),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isVerifying = false);
    }
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                
                SizedBox(height: screenHeight * 0.02),
                
                // Verification icon with animation
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
                            Icons.verified_user,
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
                          'Verification',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Final step to complete your registration',
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
                
                // ID selection card with animation
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choose your ID',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF054D88),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Select the type of ID you will use for verification',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                prefixIcon: const Icon(Icons.badge, color: Color(0xFF054D88)),
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
                              hint: const Text('Select ID type'),
                              isExpanded: true,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // ID upload section (simulated)
                          if (_selectedIdType != null) ...[
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1-value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF054D88).withAlpha(77), // 0.3 opacity
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.cloud_upload,
                                      size: 48,
                                      color: Color(0xFF054D88),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Upload your ID',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tap to browse files or drag and drop',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Browse Files'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                          ],
                          
                          // Complete verification button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _selectedIdType == null || _isVerifying
                                  ? null
                                  : () => _completeRegistration(context),
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
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Verifying...',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Complete Verification',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(51), // 0.2 opacity
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.arrow_forward, color: Colors.white),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Privacy note with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
                    child: Text(
                      'Your information is secure and will only be used for verification purposes.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
