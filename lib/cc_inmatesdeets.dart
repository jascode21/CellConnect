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
  String _selectedRelationship = '';
  bool _showOtherRelationship = false;

  final List<String> _relationshipOptions = [
    'Spouse',
    'Parent',
    'Child',
    'Sibling',
    'Grandparent',
    'Grandchild',
    'Aunt/Uncle',
    'Niece/Nephew',
    'Cousin',
    'Legal Counsel',
    'Friend',
    'Other'
  ];

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
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F7FA)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Inmate Details',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          color: Color(0xFF054D88),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Animated container for form
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
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
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Please provide information about the inmate you wish to visit',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Inmate First Name
                        const Text(
                          'Inmate First Name',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF054D88),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _inmateFirstNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter inmate\'s first name',
                            fillColor: const Color(0xFFF5F7FA),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.person, color: Color(0xFF054D88)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter inmate first name';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Inmate Last Name
                        const Text(
                          'Inmate Last Name',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF054D88),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _inmateLastNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter inmate\'s last name',
                            fillColor: const Color(0xFFF5F7FA),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.person, color: Color(0xFF054D88)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter inmate last name';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Relationship
                        const Text(
                          'Your Relationship to Inmate',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF054D88),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedRelationship.isEmpty ? null : _selectedRelationship,
                            decoration: InputDecoration(
                              fillColor: const Color(0xFFF5F7FA),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.people, color: Color(0xFF054D88)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            hint: const Text(
                              'Select relationship',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.grey,
                              ),
                            ),
                            items: _relationshipOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF054D88),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedRelationship = newValue ?? '';
                                _showOtherRelationship = newValue == 'Other';
                                if (!_showOtherRelationship) {
                                  _relationshipController.text = newValue ?? '';
                                }
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a relationship';
                              }
                              return null;
                            },
                          ),
                        ),
                        
                        if (_showOtherRelationship) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Specify Relationship',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF054D88),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _relationshipController,
                            decoration: InputDecoration(
                              hintText: 'Enter your relationship to the inmate',
                              fillColor: const Color(0xFFF5F7FA),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.edit, color: Color(0xFF054D88)),
                            ),
                            validator: (value) {
                              if (_showOtherRelationship && (value == null || value.isEmpty)) {
                                return 'Please specify your relationship';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Submit button
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Color(0xFF054D88))
                      : TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: child,
                            );
                          },
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () => _proceedToVerification(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF054D88),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFF054D88).withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Verify Identity',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
