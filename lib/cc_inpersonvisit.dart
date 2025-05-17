import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class InPersonVisitPage extends StatefulWidget {
  const InPersonVisitPage({super.key});

  @override
  _InPersonVisitPageState createState() => _InPersonVisitPageState();
}

class _InPersonVisitPageState extends State<InPersonVisitPage> with SingleTickerProviderStateMixin {
  String? selectedFacility = 'Sta. Cruz Police Station 3';
  DateTime? selectedDate;
  String? selectedTime;
  DateTime _currentMonth = DateTime.now();
  bool _isLoading = false;
  bool _isCheckingExistingVisit = true;
  bool _hasActiveVisit = false;
  Map<String, dynamic>? _activeVisit;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _facilities = [
    'Sta. Cruz Police Station 3', 
    'Gandara Police Community Precinct', 
    'Raxabago-Tondo Police Station'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _checkForExistingVisit();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkForExistingVisit() async {
    setState(() => _isCheckingExistingVisit = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isCheckingExistingVisit = false;
          _hasActiveVisit = false;
        });
        return;
      }
      
      // Query for active visits (pending or approved)
      final visitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visits')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .where('status', whereIn: ['pending', 'approved'])
          .orderBy('date')
          .limit(1)
          .get();
      
      if (visitsSnapshot.docs.isNotEmpty) {
        final visitData = visitsSnapshot.docs.first.data();
        visitData['id'] = visitsSnapshot.docs.first.id;
        
        setState(() {
          _hasActiveVisit = true;
          _activeVisit = visitData;
          _isCheckingExistingVisit = false;
        });
      } else {
        setState(() {
          _hasActiveVisit = false;
          _isCheckingExistingVisit = false;
        });
      }
      
      _animationController.forward();
    } catch (e) {
      print('Error checking for existing visit: $e');
      setState(() {
        _isCheckingExistingVisit = false;
        _hasActiveVisit = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking for existing visits: $e')),
      );
      
      _animationController.forward();
    }
  }

  List<String> _generateTimeSlots(DateTime date) {
    if (date.weekday >= 6) {
      return [
        '9:00 AM - 10:00 AM',
        '11:00 AM - 12:00 PM',
        '2:00 PM - 3:00 PM',
        '4:00 PM - 5:00 PM'
      ];
    } else {
      return [
        '8:00 AM - 9:00 AM',
        '10:00 AM - 11:00 AM',
        '1:00 PM - 2:00 PM',
        '3:00 PM - 4:00 PM',
        '5:00 PM - 6:00 PM'
      ];
    }
  }

  void _previousMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
  void _nextMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayOffset = firstDay.weekday % 7;

    return [
      ...List.generate(firstDayOffset, (i) => DateTime(firstDay.year, firstDay.month, 0 - i)),
      ...List.generate(lastDay.day, (i) => DateTime(_currentMonth.year, _currentMonth.month, i + 1))
    ];
  }

  void _selectDate(DateTime date) {
    if (date.month != _currentMonth.month || date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) return;
    setState(() {
      selectedDate = date;
      selectedTime = null;
    });
    
    // Provide haptic feedback when a date is selected
    HapticFeedback.selectionClick();
  }

  Future<void> _confirmSchedule() async {
    if (selectedFacility == null || selectedDate == null || selectedTime == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF054D88).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available, color: Color(0xFF054D88)),
            ),
            const SizedBox(width: 12),
            const Text("Confirm Visit Details", style: TextStyle(fontFamily: 'Inter')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow("Facility:", selectedFacility!),
            _buildDetailRow("Date:", DateFormat('MMMM d, y').format(selectedDate!)),
            _buildDetailRow("Time:", selectedTime!),
            const SizedBox(height: 16),
            const Text(
              "Please make sure all details are correct. Once submitted, your visit request will be reviewed by staff.",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF054D88))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveVisitToFirestore();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF054D88),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Confirm", style: TextStyle(fontFamily: 'Inter', color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _saveVisitToFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Get user data for reference
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User data not found');
      }
      
      final userData = userDoc.data()!;
      
      // Create visit document
      final visitData = {
        'type': 'in-person',
        'facility': selectedFacility,
        'date': Timestamp.fromDate(selectedDate!),
        'time': selectedTime,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'visitorName': userData['fullName'] ?? '${userData['firstName']} ${userData['lastName']}',
        'visitorId': user.uid,
      };
      
      // Save to user's visits collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visits')
          .add(visitData);
      
      // Also save to global visits collection for staff access
      await FirebaseFirestore.instance
          .collection('visits')
          .add(visitData);
      
      if (!mounted) return;
      
      // Show success screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VisitScheduledScreen(
            facility: selectedFacility!,
            date: selectedDate!,
            time: selectedTime!,
            onBackToHome: () {
              Navigator.popUntil(context, ModalRoute.withName('/home'));
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling visit: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(
          label, 
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          )
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildActiveVisitCard() {
    if (_activeVisit == null) return const SizedBox.shrink();
    
    final visitDate = (_activeVisit!['date'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMMM d, yyyy').format(visitDate);
    final visitType = _activeVisit!['type'] == 'virtual' ? 'Virtual' : 'In-person';
    final visitStatus = _activeVisit!['status'] ?? 'pending';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
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
          color: visitStatus == 'approved' 
              ? Colors.green.withOpacity(0.5) 
              : const Color(0xFF054D88).withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: visitType == 'Virtual' 
                      ? Colors.blue.withOpacity(0.1) 
                      : const Color(0xFF054D88).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  visitType == 'Virtual' ? Icons.videocam : Icons.person,
                  color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active $visitType Visit',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: visitStatus == 'approved'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        visitStatus == 'approved' ? 'Approved' : 'Pending',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: visitStatus == 'approved' ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.calendar_today, 'Date', formattedDate),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.access_time, 'Time', _activeVisit!['time'] ?? 'Not specified'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on, 'Facility', _activeVisit!['facility'] ?? 'Not specified'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You already have an active visit scheduled. Please cancel it if you want to book a new one.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  // Navigate to home
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF054D88),
                  side: const BorderSide(color: Color(0xFF054D88)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // Show cancel confirmation dialog
                  _showCancelConfirmationDialog();
                },
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('Cancel Visit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF054D88)),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Cancel Visit?'),
          ],
        ),
        content: const Text('Are you sure you want to cancel this visit? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _cancelVisit();
            },
            icon: const Icon(Icons.cancel, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: const Text('Yes, Cancel Visit'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelVisit() async {
    if (_activeVisit == null || _activeVisit!['id'] == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Update the visit status to 'cancelled' in user's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visits')
          .doc(_activeVisit!['id'])
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      // Also update in the global visits collection
      // We need to find the matching visit in the global collection
      final globalVisitsSnapshot = await FirebaseFirestore.instance
          .collection('visits')
          .where('visitorId', isEqualTo: user.uid)
          .where('date', isEqualTo: _activeVisit!['date'])
          .where('time', isEqualTo: _activeVisit!['time'])
          .get();
      
      if (globalVisitsSnapshot.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('visits')
            .doc(globalVisitsSnapshot.docs.first.id)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Refresh the page
      setState(() {
        _hasActiveVisit = false;
        _activeVisit = null;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling visit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime> daysInMonth = _getDaysInMonth();

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 24),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'In-person Visit',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF054D88),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Schedule a face-to-face visit with an inmate at your selected facility',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      if (_isCheckingExistingVisit)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: Color(0xFF054D88)),
                                SizedBox(height: 16),
                                Text(
                                  'Checking for existing visits...',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_hasActiveVisit)
                        _buildActiveVisitCard()
                      else ...[
                        // Facility Selection
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
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
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF054D88).withOpacity(0.05),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.location_on, color: Color(0xFF054D88)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Select Facility',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: _facilities.map((facility) => 
                                    Column(
                                      children: [
                                        RadioListTile<String>(
                                          title: Text(
                                            facility,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 16,
                                            ),
                                          ),
                                          value: facility,
                                          groupValue: selectedFacility,
                                          activeColor: const Color(0xFF054D88),
                                          onChanged: (value) {
                                            setState(() => selectedFacility = value);
                                            HapticFeedback.selectionClick();
                                          },
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 30, bottom: 8),
                                          child: Text(
                                            facility == 'Sta. Cruz Police Station 3' 
                                                ? 'Available daily, 8AM-6PM'
                                                : facility == 'Gandara Police Community Precinct'
                                                    ? 'Available weekdays, 9AM-5PM'
                                                    : 'Available all days, 8AM-7PM',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                
                        // Calendar Section
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
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
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF054D88).withOpacity(0.05),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.calendar_today, color: Color(0xFF054D88)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Select Date',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF054D88),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      DateFormat('MMMM y').format(_currentMonth), 
                                      style: const TextStyle(
                                        fontFamily: 'Inter', 
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Month navigation
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left, color: Color(0xFF054D88)),
                                      onPressed: _previousMonth,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right, color: Color(0xFF054D88)),
                                      onPressed: _nextMonth,
                                    ),
                                  ],
                                ),
                              ),
                
                              // Weekday headers
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) =>
                                      SizedBox(
                                        width: 32, 
                                        child: Center(
                                          child: Text(
                                            d, 
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF054D88),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ).toList(),
                                ),
                              ),
                
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Select a date for your visit. Weekends may have different available hours.',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Calendar grid
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 7,
                                padding: const EdgeInsets.all(8),
                                children: daysInMonth.map((date) {
                                  final isCurrentMonth = date.month == _currentMonth.month;
                                  final isSelected = DateUtils.isSameDay(selectedDate, date);
                                  final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
                                  final isToday = DateUtils.isSameDay(date, DateTime.now());
                
                                  return GestureDetector(
                                    onTap: isCurrentMonth && !isPast ? () => _selectDate(date) : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? const Color(0xFF054D88) 
                                            : isToday 
                                                ? const Color(0xFFECF2F9)
                                                : null,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isToday && !isSelected 
                                            ? Border.all(color: const Color(0xFF054D88))
                                            : null,
                                        boxShadow: isSelected ? [
                                          BoxShadow(
                                            color: const Color(0xFF054D88).withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ] : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          date.day > 0 ? date.day.toString() : '',
                                          style: TextStyle(
                                            color: isCurrentMonth
                                                ? (isPast 
                                                    ? Colors.grey 
                                                    : (isSelected 
                                                        ? Colors.white 
                                                        : Colors.black))
                                                : Colors.transparent,
                                            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                
                        // Time Slots Section
                        if (selectedDate != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
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
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF054D88).withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.access_time, color: Color(0xFF054D88)),
                                      SizedBox(width: 8),
                                      Text(
                                        'Select Time',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF054D88),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Each visit lasts for 1 hour. Please arrive 15 minutes before your scheduled time.',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Available time slots for ${DateFormat('MMMM d, yyyy').format(selectedDate!)}:',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: _generateTimeSlots(selectedDate!).map((time) => GestureDetector(
                                          onTap: () {
                                            setState(() => selectedTime = time);
                                            HapticFeedback.selectionClick();
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: selectedTime == time 
                                                  ? const Color(0xFF054D88) 
                                                  : Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: selectedTime == time 
                                                    ? const Color(0xFF054D88) 
                                                    : Colors.grey.shade300,
                                                width: 1.5,
                                              ),
                                              boxShadow: selectedTime == time 
                                                  ? [
                                                      BoxShadow(
                                                        color: const Color(0xFF054D88).withOpacity(0.3),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      )
                                                    ] 
                                                  : null,
                                            ),
                                            child: Text(
                                              time, 
                                              style: TextStyle(
                                                color: selectedTime == time ? Colors.white : Colors.black,
                                                fontFamily: 'Inter',
                                                fontWeight: selectedTime == time ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                
                        // Schedule Button
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading || (selectedDate == null || selectedTime == null) 
                                    ? null 
                                    : _confirmSchedule,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF054D88),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 3,
                                  shadowColor: const Color(0xFF054D88).withOpacity(0.5),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Schedule Visit', 
                                            style: TextStyle(
                                              fontFamily: 'Inter', 
                                              fontSize: 18, 
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward,
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class VisitScheduledScreen extends StatelessWidget {
  final String facility;
  final DateTime date;
  final String time;
  final VoidCallback onBackToHome;

  const VisitScheduledScreen({
    super.key,
    required this.facility,
    required this.date,
    required this.time,
    required this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFECF2F9)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF054D88).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 100,
                      color: Color(0xFF054D88),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Visit Scheduled!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF054D88),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
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
                    children: [
                      const Text(
                        'Your visit request has been submitted successfully. You will receive a notification when it\'s approved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Staff will review your request and you will be notified when it\'s approved or if there are any issues.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildDetailRow('Facility:', facility),
                      _buildDetailRow('Date:', DateFormat('MMMM d, y').format(date)),
                      _buildDetailRow('Time:', time),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please arrive 15 minutes before your scheduled time with a valid ID.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.badge, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Remember to bring a valid government-issued ID for verification.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.home, color: Colors.white),
                  label: const Text(
                    'Back to Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: onBackToHome,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label, 
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          )
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
          ),
        ),
      ],
    ),
  );
}
