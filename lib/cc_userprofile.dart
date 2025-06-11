// ignore_for_file: dead_code, duplicate_ignore

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});
  
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isChangingPassword = false; // New state for password change
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _inmateData;
  String? _profileImageUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  // Track if edit mode is active
  bool _isEditMode = false;
  final TextEditingController _nameController = TextEditingController();
  
  // For password change
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // For animated background
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
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
    
    // Set up page change listener for background animation
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _pageController.dispose();
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
          
          // Set name controller
          final String fullName = _userData?['fullName'] ?? 
                               '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}'.trim();
          _nameController.text = fullName;
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
      // Show bottom sheet with options
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choose Profile Picture',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      context,
                      'Camera',
                      Icons.camera_alt,
                      Colors.blue,
                      () => Navigator.pop(context, ImageSource.camera),
                    ),
                    _buildImageSourceOption(
                      context,
                      'Gallery',
                      Icons.photo_library,
                      Colors.green,
                      () => Navigator.pop(context, ImageSource.gallery),
                    ),
                    if (_profileImageUrl != null || _userData?['profileImageBase64'] != null)
                      _buildImageSourceOption(
                        context,
                        'Remove',
                        Icons.delete,
                        Colors.red,
                        () => Navigator.pop(context, null),
                      ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      );
      
      // Handle image removal
      if (source == null && (_profileImageUrl != null || _userData?['profileImageBase64'] != null)) {
        // Show confirmation dialog
        final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Remove Profile Picture?'),
            content: const Text('Are you sure you want to remove your profile picture?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ?? false;
        
        if (confirm) {
          setState(() => _isUploading = true);
          
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) throw Exception('User not authenticated');
          
          // Remove profile image from Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'profileImageUrl': FieldValue.delete(),
            'profileImageBase64': FieldValue.delete(),
          });
          
          // Update UI
          setState(() {
            _profileImageUrl = null;
            if (_userData != null) {
              _userData!.remove('profileImageUrl');
              _userData!.remove('profileImageBase64');
            }
            _isUploading = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture removed'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        return;
      }
      
      // If no source selected, return
      if (source == null) return;
      
      // Show loading indicator immediately to provide feedback
      setState(() => _isUploading = true);
      
      // Pick image with reduced size to improve performance
      final XFile? image = await picker.pickImage(
        source: source,
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
          'profileImageUrl': FieldValue.delete(), // Remove URL if exists
        });
        
        // Update UI
        setState(() {
          _userData = {...?_userData, 'profileImageBase64': base64Image};
          _profileImageUrl = null;
          _isUploading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated'),
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
        'profileImageBase64': FieldValue.delete(), // Remove base64 if exists
      });
      
      setState(() {
        _profileImageUrl = downloadUrl;
        if (_userData != null) {
          _userData!.remove('profileImageBase64');
        }
        _isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      }
    }
  }
  
  Widget _buildImageSourceOption(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _signOut() async {
    // Show confirmation dialog with animation
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );
        },
      ),
    ) ?? false;
    
    if (!confirm) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Log logout activity - ONLY for visitors
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Get user data for the activity log
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          
          String userName = 'Unknown User';
          String userRole = 'Visitor';
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final firstName = userData['firstName'] ?? '';
            final lastName = userData['lastName'] ?? '';
            userName = userData['fullName'] ?? '$firstName $lastName'.trim();
            userRole = userData['role'] ?? 'Visitor';
            if (userName.isEmpty) userName = 'User';
          }
          
          // ONLY log logout activity for visitors
          if (userRole.toLowerCase() == 'visitor') {
            await FirebaseFirestore.instance.collection('activities').add({
              'type': 'logout',
              'userId': user.uid,
              'userName': userName,
              'userRole': userRole,
              'timestamp': FieldValue.serverTimestamp(),
              'deviceInfo': {
                'platform': Theme.of(context).platform.toString(),
                'isWeb': false,
              }
            });
          }
        } catch (e) {
          print('Error logging logout activity: $e');
        }
      }
      
      await FirebaseAuth.instance.signOut();
      
      if (!mounted) return;
      
      // Dismiss loading dialog
      Navigator.pop(context);
      
      // Navigate to login with animation
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/logIn',
        (route) => false,
      );
    } catch (e) {
      // Dismiss loading dialog if showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Update user document with new name
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fullName': _nameController.text.trim(),
      });
      
      // Exit edit mode
      setState(() {
        _isEditMode = false;
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
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showChangePasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool isChangingPassword = false;
          bool obscureCurrentPassword = true;
          bool obscureNewPassword = true;
          bool obscureConfirmPassword = true;
          
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Change Password',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Current password
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: obscureCurrentPassword,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureCurrentPassword = !obscureCurrentPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // New password
                  TextField(
                    controller: _newPasswordController,
                    obscureText: obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureNewPassword = !obscureNewPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm password
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_clock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Password requirements
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Password Requirements:',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPasswordRequirement('At least 8 characters'),
                        _buildPasswordRequirement('At least one uppercase letter'),
                        _buildPasswordRequirement('At least one number'),
                        _buildPasswordRequirement('At least one special character'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isChangingPassword
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isChangingPassword
                              ? null
                              : () async {
                                  // Validate inputs
                                  if (_currentPasswordController.text.isEmpty ||
                                      _newPasswordController.text.isEmpty ||
                                      _confirmPasswordController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please fill all fields'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  if (_newPasswordController.text != _confirmPasswordController.text) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('New passwords do not match'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  // Password strength validation
                                  final password = _newPasswordController.text;
                                  if (password.length < 8 ||
                                      !password.contains(RegExp(r'[A-Z]')) ||
                                      !password.contains(RegExp(r'[0-9]')) ||
                                      !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password does not meet requirements'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  setState(() {
                                    isChangingPassword = true;
                                    this._isChangingPassword = true; // Update parent state
                                  });
                                  
                                  try {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user == null) throw Exception('User not authenticated');
                                    
                                    // Reauthenticate user
                                    final credential = EmailAuthProvider.credential(
                                      email: user.email!,
                                      password: _currentPasswordController.text,
                                    );
                                    
                                    await user.reauthenticateWithCredential(credential);
                                    
                                    // Change password
                                    await user.updatePassword(_newPasswordController.text);
                                    
                                    Navigator.pop(context);
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password changed successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    String errorMessage = 'Error changing password';
                                    if (e is FirebaseAuthException) {
                                      if (e.code == 'wrong-password') {
                                        errorMessage = 'Current password is incorrect';
                                      } else if (e.code == 'weak-password') {
                                        errorMessage = 'New password is too weak';
                                      }
                                    }
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(errorMessage),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } finally {
                                    setState(() {
                                      isChangingPassword = false;
                                      this._isChangingPassword = false; // Reset parent state
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF054D88),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isChangingPassword
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Change Password'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPasswordRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.blue,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo or icon
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF054D88),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF054D88).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Loading text with animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: const Text(
                        'Loading Profile...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF054D88),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Loading indicator with animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Color(0xFF054D88),
                          strokeWidth: 3,
                        ),
                      ),
                    );
                  },
                ),
              ],
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
    
    // Check if we have a base64 image
    final String? base64Image = _userData?['profileImageBase64'];
    
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Page 1 - Gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0xFFF5F7FA)],
                    ),
                  ),
                ),
                // Page 2 - Pattern background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    image: DecorationImage(
                      image: NetworkImage(
                        'https://www.transparenttextures.com/patterns/cubes.png',
                      ),
                      repeat: ImageRepeat.repeat,
                      opacity: 0.1,
                    ),
                  ),
                ),
              ],
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
                              // Back button with ripple effect
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
                              
                              // Title with animation
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.8, end: 1.0),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Text(
                                      'My Profile',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.06,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF054D88),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              // Logout button with ripple effect
                              Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(30),
                                  onTap: _signOut,
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
                                      Icons.logout,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Profile Picture with Upload Option
                        Hero(
                          tag: 'profileImage',
                          child: GestureDetector(
                            onTap: _pickAndUploadImage,
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
                              child: Stack(
                                children: [
                                  if (_profileImageUrl == null && base64Image == null)
                                    Center(
                                      child: Text(
                                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF054D88),
                                        ),
                                      ),
                                    ),
                                  if (_isUploading)
                                    Container(
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
                                  // Camera icon overlay
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
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
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // User's Name with edit functionality
                        if (_isEditMode)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: TextField(
                              controller: _nameController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF054D88),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter your name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEditMode = true;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  fullName.isNotEmpty ? fullName : 'User',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF054D88),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Color(0xFF054D88),
                                ),
                              ],
                            ),
                          ),
                        
                        // Edit mode buttons
                        if (_isEditMode)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditMode = false;
                                      _nameController.text = fullName;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade200,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: _updateProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF054D88),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 8),
                        
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
                              
                              // Email Field
                              ProfileField(
                                label: 'Email',
                                icon: Icons.email,
                                value: email,
                                onTap: () {
                                  // Copy email to clipboard
                                  Clipboard.setData(ClipboardData(text: email));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Email copied to clipboard'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                              ),
                              
                              // Password Field
                              ProfileField(
                                label: 'Password',
                                icon: Icons.lock,
                                value: '***************',
                                isPassword: true,
                                isLoading: _isChangingPassword, // Pass loading state
                                onTap: _showChangePasswordDialog,
                              ),
                            ],
                          ),
                        ),
                        
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
                        
                        // Help & Support
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSupportButton(
                              'Help Center',
                              Icons.help_outline,
                              Colors.blue,
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Help Center coming soon!'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            _buildSupportButton(
                              'Contact Us',
                              Icons.mail_outline,
                              Colors.green,
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Contact Us coming soon!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            _buildSupportButton(
                              'About',
                              Icons.info_outline,
                              Colors.orange,
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('About page coming soon!'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Version info
                        Center(
                          child: Text(
                            'CellConnect v1.0.0',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.grey.shade500,
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildSupportButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
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
  final bool isLoading; // New property for loading state
  final VoidCallback? onTap;

  const ProfileField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.isPassword = false,
    this.isLoading = false,
    this.onTap,
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onTap, // Disable tap when loading
            borderRadius: BorderRadius.circular(12),
            child: Ink(
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
                    isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Color(0xFF054D88),
                              strokeWidth: 2,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: onTap,
                            icon: const Icon(
                              Icons.edit,
                              size: 16,
                            ),
                            label: const Text('Change'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF054D88),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                  else if (onTap != null)
                    const Icon(
                      Icons.content_copy,
                      color: Colors.grey,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
