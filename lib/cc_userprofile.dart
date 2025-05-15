import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});
  
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _inmateData;
  String? _profileImageUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _userData = null;
        });
        return;
      }
      
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
          _profileImageUrl = _userData?['profileImageUrl'];
        });
        
        // Get inmate data
        final inmatesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('inmates')
            .limit(1)
            .get();
        
        if (inmatesSnapshot.docs.isNotEmpty) {
          setState(() {
            _inmateData = inmatesSnapshot.docs.first.data();
          });
        }
      }
      
      _animationController.forward();
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      // Show loading indicator immediately to provide feedback
      setState(() => _isUploading = true);
      
      // Pick image with reduced size to improve performance
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );
      
      if (image == null) {
        setState(() => _isUploading = false);
        return;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Read image as bytes
      final bytes = await image.readAsBytes();
      
      // Convert to base64 for smaller images (for testing)
      if (bytes.length < 500000) { // Less than 500KB, store directly in Firestore
        final base64Image = base64Encode(bytes);
        
        // Update user document with base64 image
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'profileImageBase64': base64Image,
        });
        
        // Update UI
        setState(() {
          _userData = {...?_userData, 'profileImageBase64': base64Image};
          _isUploading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
      
      // For larger images, use Firebase Storage
      // Create a unique filename
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(user.uid)
          .child(fileName);
      
      // Use a smaller chunk size for better performance
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'picked-file-path': image.path},
      );
      
      final uploadTask = storageRef.putData(bytes, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });
      
      // Wait for upload to complete
      await uploadTask.whenComplete(() => print('Upload complete'));
      
      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Update user document with profile image URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'profileImageUrl': downloadUrl,
      });
      
      setState(() {
        _profileImageUrl = downloadUrl;
        _isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile image: $e')),
        );
      }
    }
  }
  
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/logIn', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
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
            child: CircularProgressIndicator(color: Color(0xFF054D88)),
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
    
    // Check if we have a base64 image
    final String? base64Image = _userData?['profileImageBase64'];
    
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
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
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF054D88),
                          ),
                        ),
                        IconButton(
                          onPressed: _signOut,
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Profile Picture with Upload Option
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: Hero(
                          tag: 'profileImage',
                          child: Container(
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
                            child: (_profileImageUrl == null && base64Image == null)
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
                      ),
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.5),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF054D88),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 4),
                  
                  // Verified Visitor with Icon
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
                          'Verified $role',
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
                  
                  // Profile Information Card
                  Container(
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Information',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF054D88),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Email Field
                        ProfileField(
                          label: 'Email',
                          icon: Icons.email,
                          value: email,
                        ),
                        
                        // Password Field
                        const ProfileField(
                          label: 'Password',
                          icon: Icons.lock,
                          value: '***************',
                          isPassword: true,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Inmate Information Card
                  Container(
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inmate Information',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF054D88),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Inmate Field
                        ProfileField(
                          label: 'Inmate',
                          icon: Icons.person,
                          value: inmateName.isNotEmpty ? inmateName : 'No inmate added',
                        ),
                        
                        // Relationship Field
                        ProfileField(
                          label: 'Relationship',
                          icon: Icons.group,
                          value: relationship,
                        ),
                      ],
                    ),
                  ),
                  
                  // Edit Profile Button
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Show edit profile dialog
                      _showEditProfileDialog(context, fullName, email);
                    },
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text(
                      'Edit Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF054D88),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF054D88).withOpacity(0.4),
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
  
  void _showEditProfileDialog(BuildContext context, String currentName, String currentEmail) {
    final nameController = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Email cannot be changed',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    currentEmail,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              if (nameController.text.trim().isEmpty) return;
              
              setState(() => _isLoading = true);
              
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('User not authenticated');
                
                // Update user document with new name
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({
                  'fullName': nameController.text.trim(),
                });
                
                // Reload user data
                await _loadUserData();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF054D88),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class ProfileField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool isPassword;

  const ProfileField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF054D88),
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: const Icon(
                    Icons.visibility_off,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password change feature coming soon')),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
