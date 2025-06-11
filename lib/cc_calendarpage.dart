import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cc_video_call.dart';
import 'cc_visitorhistory.dart';

class CalendarEvent {
final DateTime date;
final String time;
final String title;
final String? subtitle;
final String? status;
final String? visitId;
final String? visitationType;
final String? visitationCode;

CalendarEvent({
  required this.date,
  required this.time,
  required this.title,
  this.subtitle,
  this.status,
  this.visitId,
  this.visitationType,
  this.visitationCode,
});

// Factory constructor to create an event from Firestore data
factory CalendarEvent.fromFirestore(Map<String, dynamic> data) {
  return CalendarEvent(
    date: (data['date'] as Timestamp).toDate(),
    time: data['time'] ?? 'No time specified',
    title: data['type'] == 'virtual' ? 'Virtual Visit' : 'In-person Visit',
    subtitle: data['facility'] ?? 'No facility specified',
    status: data['status'] ?? 'pending',
    visitId: data['id'] ?? '',
    visitationType: data['type'] ?? 'in-person',
    visitationCode: data['visitationCode'],
  );
}
}

class CalendarPage extends StatefulWidget {
final List<CalendarEvent> events;

const CalendarPage({super.key, required this.events});

@override
State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with SingleTickerProviderStateMixin {
DateTime _selectedDate = DateTime.now();
late DateTime _currentMonth;
bool _isLoading = true;
List<CalendarEvent> _events = [];
late AnimationController _animationController;
late Animation<double> _fadeAnimation;

@override
void initState() {
  super.initState();
  _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
  );
  _loadEvents();

  // Add a focus listener to refresh data when the page is focused
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Listen for when the page gets focus
    final focusNode = FocusNode();
    FocusScope.of(context).requestFocus(focusNode);
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        _loadEvents();
      }
    });
  });
}

@override
void dispose() {
  _animationController.dispose();
  super.dispose();
}

Future<void> _loadEvents() async {
  setState(() => _isLoading = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _events = [];
      });
      return;
    }

    // Only fetch visits from the user's subcollection
    final visitsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('visits')
        .get();

    final events = <CalendarEvent>[];
    final now = DateTime.now();

    for (var doc in visitsSnapshot.docs) {
      final data = doc.data();
      final visitDate = (data['date'] as Timestamp).toDate();
      
      // Only include upcoming visits
      if (visitDate.isAfter(now)) {
        data['id'] = doc.id; // Add document ID to the data
        events.add(CalendarEvent.fromFirestore(data));
      }
    }

    // Sort events by date
    events.sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      _events = events;
      _isLoading = false;
    });

    _animationController.forward();

    if (events.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${events.length} upcoming visits loaded'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    debugPrint('Error loading events: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading events: $e')),
      );
    }
    setState(() {
      _isLoading = false;
      _events = [];
    });
  }
}

List<DateTime> _getDaysInMonth(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);

  final days = <DateTime>[];
  for (var i = 0; i < firstDay.weekday; i++) {
    days.add(firstDay.subtract(Duration(days: firstDay.weekday - i)));
  }
  for (var i = 0; i < lastDay.day; i++) {
    days.add(DateTime(month.year, month.month, i + 1));
  }
  return days;
}

List<CalendarEvent> _getEventsForDay(DateTime day) {
  return _events
      .where((event) =>
          event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day)
      .toList();
}

List<CalendarEvent> _getEventsForWeek(DateTime day) {
  final startOfWeek = day.subtract(Duration(days: day.weekday));
  final endOfWeek = startOfWeek.add(const Duration(days: 6));

  return _events
      .where((event) =>
          event.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          event.date.isBefore(endOfWeek.add(const Duration(days: 1))))
      .toList();
}

void _changeMonth(int delta) {
  setState(() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
  });
}

Future<void> _showMonthYearPicker() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _currentMonth,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    initialDatePickerMode: DatePickerMode.year,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF054D88),
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked != null) {
    setState(() {
      _currentMonth = DateTime(picked.year, picked.month, 1);
      _selectedDate = DateTime(
          picked.year,
          picked.month,
          _selectedDate.day.clamp(
              1, DateTime(picked.year, picked.month + 1, 0).day));
    });
  }
}

void _showEventDetailsModal(CalendarEvent event) {
  final formattedDate = DateFormat('MMMM d, yyyy').format(event.date);
  final visitType = event.visitationType == 'virtual' ? 'Virtual' : 'In-person';
  final visitStatus = event.status ?? 'pending';
  
  // Generate a unique hero tag for this event
  final heroTag = 'calendar-event-${event.visitId}';

  DateTime _parseVisitDateTime(DateTime date, String timeStr) {
    try {
      // Handle different time formats
      if (timeStr.contains('AM') || timeStr.contains('PM')) {
        // Format: "2:30 PM" or "2:30 AM"
        final timeParts = timeStr.split(':');
        int hour = int.parse(timeParts[0].trim());
        final minutePart = timeParts[1].split(' ')[0].trim();
        int minute = int.parse(minutePart);
        
        // Handle AM/PM
        if (timeStr.toUpperCase().contains('PM') && hour != 12) {
          hour += 12;
        } else if (timeStr.toUpperCase().contains('AM') && hour == 12) {
          hour = 0;
        }
        
        return DateTime(date.year, date.month, date.day, hour, minute);
      } else {
        // Format: "14:30"
        final timeParts = timeStr.split(':');
        int hour = int.parse(timeParts[0].trim());
        int minute = int.parse(timeParts[1].trim());
        
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    } catch (e) {
      debugPrint('Error parsing time: $e');
      // Return a default time if parsing fails
      return DateTime(date.year, date.month, date.day, 0, 0);
    }
  }
  
  // Calculate if visit has passed
  bool isVisitPassed() {
    final now = DateTime.now();
    final visitDateTime = _parseVisitDateTime(event.date, event.time);
    
    // Add 1 hour buffer for virtual visits to allow for late joins
    if (event.visitationType == 'virtual') {
      return visitDateTime.add(const Duration(hours: 1)).isBefore(now);
    }
    
    // For in-person visits, consider it passed after 30 minutes
    return visitDateTime.add(const Duration(minutes: 30)).isBefore(now);
  }

  String getTimeRemaining() {
    final now = DateTime.now();
    final visitDateTime = _parseVisitDateTime(event.date, event.time);
    final difference = visitDateTime.difference(now);
    
    if (difference.isNegative) {
      return 'Passed';
    }
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours.remainder(24)}h remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m remaining';
    } else {
      return '${difference.inMinutes}m remaining';
    }
  }

  final bool isPassed = isVisitPassed();
  final String timeRemaining = getTimeRemaining();

  // Always show "Passed" status if the visit has passed
  final String effectiveStatus = isPassed ? 'passed' : visitStatus;
  final Color statusColor = isPassed 
      ? Colors.grey 
      : effectiveStatus == 'approved' 
          ? Colors.green 
          : effectiveStatus == 'rejected' 
              ? Colors.red 
              : effectiveStatus == 'cancelled'
                  ? Colors.grey
                  : effectiveStatus == 'in_progress'
                      ? Colors.blue
                      : Colors.orange;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context).overlay! as TickerProvider,
      duration: const Duration(milliseconds: 400),
    ),
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40 * value,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
          
          // Header with hero animation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: heroTag,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: visitType == 'Virtual' 
                          ? Colors.blue.withAlpha((0.1 * 255).round())
                          : const Color(0xFF054D88).withAlpha((0.1 * 255).round()),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88)).withAlpha((0.2 * 255).round()),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      visitType == 'Virtual' ? Icons.videocam : Icons.person,
                      color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPassed
                              ? Colors.grey.withAlpha((0.1 * 255).round())
                              : statusColor.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: (isPassed
                                  ? Colors.grey
                                  : statusColor).withAlpha((0.2 * 255).round()),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPassed
                                  ? Icons.history
                                  : effectiveStatus == 'approved'
                                      ? Icons.check_circle
                                      : effectiveStatus == 'rejected'
                                          ? Icons.cancel
                                          : effectiveStatus == 'cancelled'
                                              ? Icons.block
                                              : effectiveStatus == 'in_progress'
                                                  ? Icons.play_circle_fill
                                                  : Icons.hourglass_empty,
                              size: 14,
                              color: isPassed ? Colors.grey : statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPassed
                                  ? 'Passed'
                                  : effectiveStatus == 'approved'
                                      ? 'Approved'
                                      : effectiveStatus == 'rejected'
                                          ? 'Rejected'
                                          : effectiveStatus == 'cancelled'
                                              ? 'Cancelled'
                                              : effectiveStatus == 'in_progress'
                                                  ? 'In Progress'
                                                  : 'Pending Approval',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPassed ? Colors.grey : statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          
          // Content with animation
          Expanded(
            child: TweenAnimationBuilder<double>(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and time section with time remaining
                    _buildDetailSection(
                      'Date & Time',
                      Icons.calendar_today,
                      [
                        _buildDetailItem('Date', formattedDate),
                        _buildDetailItem('Time', event.time),
                        if (!isPassed)
                          _buildDetailItem('Time Remaining', timeRemaining),
                      ],
                      visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Location section
                    _buildDetailSection(
                      'Location',
                      Icons.location_on,
                      [
                        _buildDetailItem('Facility', event.subtitle ?? 'Not specified'),
                      ],
                      visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Status section
                    _buildDetailSection(
                      'Status Information',
                      Icons.info_outline,
                      [
                        _buildDetailItem('Status', isPassed ? 'PASSED' : effectiveStatus.toUpperCase()),
                        if (!isPassed && effectiveStatus == 'pending')
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(Icons.pending_actions, size: 16, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your visit request is being reviewed by staff. You will be notified when it\'s approved.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isPassed && effectiveStatus == 'approved')
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your visit has been approved. Please arrive on time or join the virtual room at the scheduled time.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (effectiveStatus == 'cancelled')
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(Icons.block, size: 16, color: Colors.grey),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This visit has been cancelled and cannot be reinstated.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isPassed && effectiveStatus == 'in_progress')
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(Icons.play_circle_fill, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your visit is currently in progress. If this is a virtual visit, you can join using the visitation code.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isPassed)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Icon(Icons.history, size: 16, color: Colors.grey),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This visit has already passed and cannot be joined.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      statusColor,
                    ),
                    
                    // Only show action buttons for active visits that haven't passed
                    if (!isPassed && effectiveStatus != 'cancelled' && effectiveStatus != 'rejected') ...[
                      const SizedBox(height: 32),
                      
                      // Action buttons with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha((0.05 * 255).round()),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              if (visitType == 'Virtual' && effectiveStatus == 'approved') ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.video_call),
                                    label: const Text('Join Virtual Visit'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showVirtualRoomDialog();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 4,
                                      shadowColor: Colors.blue.withAlpha((0.4 * 255).round()),
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.cancel),
                                  label: const Text('Cancel Visit'),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showCancelConfirmationDialog(event);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 4,
                                    shadowColor: Colors.red.withAlpha((0.4 * 255).round()),
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Add this for cancelled bookings
                    if (effectiveStatus == 'cancelled') ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Booking'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _deleteBooking(event);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    ),
  );
}

Widget _buildDetailSection(String title, IconData icon, List<Widget> children, Color color) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 500),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: color.withAlpha((0.1 * 255).round()),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withAlpha((0.05 * 255).round()),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    ),
  );
}

Widget _buildDetailItem(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
      ],
    ),
  );
}

void _showVirtualRoomDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha((0.1 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          const Text('Virtual Visitation Room'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You are about to enter the virtual visitation room. Please ensure your camera and microphone are working properly.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Text(
            'Note: This is a simulated experience. In a real application, you would be connected to a video call interface.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.video_call, size: 16),
          label: const Text('Enter Room'),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entering virtual visitation room...'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

void _showCancelConfirmationDialog(CalendarEvent event) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Cancel Visit?'),
      content: const Text('Are you sure you want to cancel this visit? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('No, Keep It'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _cancelVisit(event);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Yes, Cancel Visit'),
        ),
      ],
    ),
  );
}

Future<void> _cancelVisit(CalendarEvent event) async {
  if (event.visitId == null || event.visitId!.isEmpty) return;
  
  setState(() => _isLoading = true);
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    // Update the visit status to 'cancelled' in user's collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('visits')
        .doc(event.visitId)
        .update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    
    // Also update in the global visits collection
    // We need to find the matching visit in the global collection
    final globalVisitsSnapshot = await FirebaseFirestore.instance
        .collection('visits')
        .where('visitorId', isEqualTo: user.uid)
        .where('date', isEqualTo: Timestamp.fromDate(event.date))
        .get();
    
    if (globalVisitsSnapshot.docs.isNotEmpty) {
      for (var doc in globalVisitsSnapshot.docs) {
        if (doc.data()['time'] == event.time) {
          await FirebaseFirestore.instance
              .collection('visits')
              .doc(doc.id)
              .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          break;
        }
      }
    }
    
    // Refresh the events
    await _loadEvents();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling visit: $e')),
      );
    }
  }
}

Future<void> _deleteBooking(CalendarEvent event) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || event.visitId == null || event.visitId!.isEmpty) return;

  setState(() => _isLoading = true);

  try {
    // Delete from user's subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('visits')
        .doc(event.visitId)
        .delete();

    // Optionally, also delete from global collection if you want:
    // await FirebaseFirestore.instance.collection('visits').doc(event.visitId).delete();

    await _loadEvents();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting booking: $e')),
      );
    }
  }
}

@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final daysInMonth = _getDaysInMonth(_currentMonth);
  final todayEvents = _getEventsForDay(_selectedDate);
  final weekEvents = _getEventsForWeek(_selectedDate);

  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F7FA)],
        ),
      ),
      child: Column(
        children: [
          // Calendar header
          Container(
            padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.05 * 255).round()),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28, color: Color(0xFF054D88)),
                  onPressed: () => _changeMonth(-1),
                ),
                GestureDetector(
                  onTap: _showMonthYearPicker,
                  child: Row(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(_currentMonth),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF054D88),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF054D88)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history, size: 24, color: Color(0xFF054D88)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VisitorHistoryPage(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 28, color: Color(0xFF054D88)),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Calendar body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: RefreshIndicator(
                      onRefresh: _loadEvents,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Weekday headers
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: List.generate(7, (index) {
                                    final
                                        weekday =
                                        DateFormat.E().format(DateTime(2021, 1, 4 + index));
                                    return SizedBox(
                                      width: 32,
                                      child: Text(
                                        weekday[0],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF054D88),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              
                              // Calendar grid
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha((0.05 * 255).round()),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                      childAspectRatio: 1.0,
                                    ),
                                    itemCount: daysInMonth.length,
                                    itemBuilder: (context, index) {
                                      final day = daysInMonth[index];
                                      final isCurrentMonth = day.month == _currentMonth.month;
                                      final isSelected = day.day == _selectedDate.day &&
                                          day.month == _selectedDate.month &&
                                          day.year == _selectedDate.year;
                                      final isToday = day.day == DateTime.now().day &&
                                          day.month == DateTime.now().month &&
                                          day.year == DateTime.now().year;
                                      
                                      // Check if there are events for this day
                                      final hasEvents = _events.any((event) => 
                                        event.date.day == day.day && 
                                        event.date.month == day.month && 
                                        event.date.year == day.year);
                        
                                      return GestureDetector(
                                        onTap: () {
                                          if (isCurrentMonth) {
                                            setState(() {
                                              _selectedDate = day;
                                            });
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? const Color(0xFF054D88)
                                                : isToday
                                                    ? const Color(0xFFECF2F9)
                                                    : null,
                                            border: isToday && !isSelected
                                                ? Border.all(color: const Color(0xFF054D88))
                                                : null,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(
                                                day.day.toString(),
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 15,
                                                  fontWeight: isSelected || isToday
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : isCurrentMonth
                                                          ? Colors.black
                                                          : Colors.grey.withAlpha((0.3 * 255).round()),
                                                ),
                                              ),
                                              if (hasEvents && isCurrentMonth)
                                                Positioned(
                                                  bottom: 2,
                                                  child: Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : const Color(0xFF054D88),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Today's events section
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha((0.05 * 255).round()),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Today - ${DateFormat('EEEE, MMMM d').format(_selectedDate)}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (todayEvents.isNotEmpty)
                                      ...todayEvents.map((event) => InkWell(
                                        onTap: () => _showEventDetailsModal(event),
                                        child: _EventItem(
                                          time: event.time,
                                          title: event.title,
                                          subtitle: event.subtitle,
                                          status: event.status,
                                          visitId: event.visitId,
                                          visitationType: event.visitationType,
                                          visitationCode: event.visitationCode,
                                          date: event.date,
                                        ),
                                      ))
                                    else
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16.0),
                                        child: Text(
                                          'No events for today',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // This Week section
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha((0.05 * 255).round()),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'This Week',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (weekEvents.isNotEmpty)
                                      ...weekEvents.map((event) => InkWell(
                                        onTap: () => _showEventDetailsModal(event),
                                        child: _EventItem(
                                          time: '${DateFormat('EEEE, MMMM d').format(event.date)}\n${event.time}',
                                          title: event.title,
                                          subtitle: event.subtitle,
                                          status: event.status,
                                          visitId: event.visitId,
                                          visitationType: event.visitationType,
                                          visitationCode: event.visitationCode,
                                          date: event.date,
                                        ),
                                      ))
                                    else
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16.0),
                                        child: Text(
                                          'No events this week',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
    floatingActionButton: Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: FloatingActionButton(
        onPressed: () {
          // Show a dialog to choose visit type
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF054D88).withAlpha((0.1 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_available, color: Color(0xFF054D88), size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Schedule a Visit',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'What type of visit would you like to schedule?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/inPersonVisit');
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF054D88).withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF054D88).withAlpha((0.3 * 255).round()),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha((0.05 * 255).round()),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha((0.1 * 255).round()),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.person, color: Color(0xFF054D88), size: 32),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'In-Person',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF054D88),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/virtualVisit');
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.blue.withAlpha((0.3 * 255).round()),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha((0.05 * 255).round()),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha((0.1 * 255).round()),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.videocam, color: Colors.blue, size: 32),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Virtual',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        backgroundColor: const Color(0xFF054D88),
        elevation: 6,
        child: const Icon(Icons.add, size: 32),
      ),
    ),
  );
}
}

class _EventItem extends StatelessWidget {
final String time;
final String title;
final String? subtitle;
final String? status;
final String? visitId;
final String? visitationType;
final String? visitationCode;
final DateTime date;

const _EventItem({
  required this.time,
  required this.title,
  required this.date,
  this.subtitle,
  this.status,
  this.visitId,
  this.visitationType,
  this.visitationCode,
});

bool _isVisitPassed() {
  final now = DateTime.now();
  final visitDateTime = _parseVisitDateTime(date, time);
  
  // Add 1 hour buffer for virtual visits to allow for late joins
  if (visitationType == 'virtual') {
    return visitDateTime.add(const Duration(hours: 1)).isBefore(now);
  }
  
  // For in-person visits, consider it passed after 30 minutes
  return visitDateTime.add(const Duration(minutes: 30)).isBefore(now);
}

DateTime _parseVisitDateTime(DateTime date, String timeStr) {
  try {
    // Handle different time formats
    if (timeStr.contains('AM') || timeStr.contains('PM')) {
      // Format: "2:30 PM" or "2:30 AM"
      final timeParts = timeStr.split(':');
      int hour = int.parse(timeParts[0].trim());
      final minutePart = timeParts[1].split(' ')[0].trim();
      int minute = int.parse(minutePart);
      
      // Handle AM/PM
      if (timeStr.toUpperCase().contains('PM') && hour != 12) {
        hour += 12;
      } else if (timeStr.toUpperCase().contains('AM') && hour == 12) {
        hour = 0;
      }
      
      return DateTime(date.year, date.month, date.day, hour, minute);
    } else {
      // Format: "14:30"
      final timeParts = timeStr.split(':');
      int hour = int.parse(timeParts[0].trim());
      int minute = int.parse(timeParts[1].trim());
      
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
  } catch (e) {
    debugPrint('Error parsing time: $e');
    // Return a default time if parsing fails
    return DateTime(date.year, date.month, date.day, 0, 0);
  }
}

String _getTimeRemaining() {
  final now = DateTime.now();
  final visitDateTime = _parseVisitDateTime(date, time);
  final difference = visitDateTime.difference(now);
  
  if (difference.isNegative) {
    return 'Passed';
  }
  
  if (difference.inDays > 0) {
    return '${difference.inDays}d ${difference.inHours.remainder(24)}h remaining';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m remaining';
  } else {
    return '${difference.inMinutes}m remaining';
  }
}

@override
Widget build(BuildContext context) {
  final Color statusColor = status == 'approved' 
      ? Colors.green 
      : status == 'rejected' 
          ? Colors.red 
          : status == 'cancelled'
              ? Colors.grey
              : status == 'in_progress'
                  ? Colors.blue
                  : Colors.orange;

  final String statusText = status == 'approved' 
      ? 'Approved' 
      : status == 'rejected' 
          ? 'Rejected' 
          : status == 'cancelled'
              ? 'Cancelled'
              : status == 'in_progress'
                  ? 'In Progress'
                  : 'Pending';
  
  final bool isVirtualInProgress = visitationType == 'virtual' && status == 'in_progress';
  final bool isPassed = _isVisitPassed();
  final String timeRemaining = _getTimeRemaining();

  // Always show "Passed" status if the visit has passed
  final String effectiveStatusText = isPassed ? 'Passed' : statusText;
  final Color effectiveStatusColor = isPassed ? Colors.grey : statusColor;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: title.contains('Virtual') ? Colors.blue : const Color(0xFF054D88),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  if (!isPassed)
                    Text(
                      timeRemaining,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: effectiveStatusColor.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 70),
              child: Text(
                effectiveStatusText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: effectiveStatusColor,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        // Add Join button for virtual visits that are in progress and not passed
        if (isVirtualInProgress && !isPassed) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (visitationCode != null && visitationCode!.isNotEmpty) {
                  debugPrint("Joining virtual visit from calendar with code: $visitationCode");
                  
                  const String agoraAppId = '81bb421e4db9457f9522222420e2841c';
                  
                  if (agoraAppId.isEmpty || agoraAppId.contains('Replace with your')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid Agora App ID. Please configure a valid App ID.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EnhancedVideoCallPage(
                        appId: agoraAppId,
                        channelName: visitationCode!,
                        userName: 'User',
                        role: 'Visitor',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No visitation code available. Please contact staff.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.video_call, size: 16),
              label: const Text('Join Meeting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
}
