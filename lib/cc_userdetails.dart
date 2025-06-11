import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cc_userprofile.dart';
import 'package:intl/intl.dart';

class UserDetailsPage extends StatefulWidget {
  final String userId;

  const UserDetailsPage({super.key, required this.userId});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _inmateData;
  String? _profileImageUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
          _profileImageUrl = _userData?['profileImageUrl'];
        });

        // Only fetch inmate data if the user is not Staff
        if (_userData?['role'] != 'Staff') {
          // Get inmate data
          final inmatesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('inmates')
              .limit(1)
              .get();

          if (inmatesSnapshot.docs.isNotEmpty) {
            setState(() {
              _inmateData = inmatesSnapshot.docs.first.data();
            });
          }
        }
      }

      _animationController.forward();
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user details: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF5F7FA)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF054D88),
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    final String fullName = _userData?['fullName'] ?? 
                           '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}'.trim();
    final String email = _userData?['email'] ?? 'No email available';
    final String role = _userData?['role'] ?? 'Visitor';
    final String inmateName = _inmateData?['fullName'] ?? 
                             '${_inmateData?['firstName'] ?? ''} ${_inmateData?['lastName'] ?? ''}'.trim();
    final String relationship = _inmateData?['relationship'] ?? 'Not specified';
    final String? base64Image = _userData?['profileImageBase64'];
    final bool isStaff = role == 'Staff';

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF5F7FA)],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App Bar
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back button
                              Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(30),
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back,
                                      color: Color(0xFF054D88),
                                    ),
                                  ),
                                ),
                              ),
                              // Title
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.8, end: 1.0),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Text(
                                      'User Details',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.06,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF054D88),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 40), // Spacer for symmetry
                            ],
                          ),
                        ),
                        // Profile Picture
                        Hero(
                          tag: 'profileImage_${widget.userId}',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF054D88).withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              image: _profileImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_profileImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : base64Image != null
                                      ? DecorationImage(
                                          image: MemoryImage(base64Decode(base64Image)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child: _profileImageUrl == null && base64Image == null
                                ? Center(
                                    child: Text(
                                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // User's Name
                        Text(
                          fullName.isNotEmpty ? fullName : 'User',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF054D88),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Role
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF054D88).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF054D88),
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                role,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF054D88),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Account Information Card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(20),
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
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF054D88).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.account_circle,
                                      color: Color(0xFF054D88),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Account Information',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF054D88),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ProfileField(
                                label: 'Email',
                                icon: Icons.email,
                                value: email,
                              ),
                              ProfileField(
                                label: 'Role',
                                icon: Icons.verified_user,
                                value: role,
                              ),
                              ProfileField(
                                label: 'Created At',
                                icon: Icons.calendar_today,
                                value: _userData?['createdAt'] != null
                                    ? DateFormat('MMMM d, yyyy').format((_userData!['createdAt'] as Timestamp).toDate())
                                    : 'Not available',
                              ),
                            ],
                          ),
                        ),
                        if (!isStaff) ...[
                          const SizedBox(height: 16),
                          // Inmate Information Card
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(20),
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
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF054D88).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.people,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Inmate Information',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ProfileField(
                                  label: 'Inmate',
                                  icon: Icons.person,
                                  value: inmateName.isNotEmpty ? inmateName : 'No inmate added',
                                ),
                                ProfileField(
                                  label: 'Relationship',
                                  icon: Icons.group,
                                  value: relationship,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Visit History Card
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(20),
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
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF054D88).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.history,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Visit History',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                FutureBuilder<QuerySnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.userId)
                                      .collection('visits')
                                      .orderBy('date', descending: true)
                                      .limit(5)
                                      .get(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF054D88),
                                        ),
                                      );
                                    }

                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No visit history available',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    }

                                    return Column(
                                      children: snapshot.data!.docs.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final date = (data['date'] as Timestamp).toDate();
                                        final status = data['status'] as String? ?? 'pending';
                                        final type = data['type'] as String? ?? 'in-person';

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: type == 'virtual'
                                                      ? Colors.blue.withOpacity(0.1)
                                                      : const Color(0xFF054D88).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  type == 'virtual' ? Icons.videocam : Icons.person,
                                                  color: type == 'virtual'
                                                      ? Colors.blue
                                                      : const Color(0xFF054D88),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      DateFormat('MMMM d, yyyy').format(date),
                                                      style: const TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      data['time'] ?? 'Time not specified',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        color: Colors.grey.shade600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: status == 'approved'
                                                      ? Colors.green.withOpacity(0.1)
                                                      : status == 'pending'
                                                          ? Colors.orange.withOpacity(0.1)
                                                          : Colors.red.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: status == 'approved'
                                                        ? Colors.green
                                                        : status == 'pending'
                                                            ? Colors.orange
                                                            : Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}