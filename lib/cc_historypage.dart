import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pastVisits = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'completed', 'missed', 'cancelled'
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchPastVisits();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPastVisits() async {
    setState(() => _isLoading = true);

    try {
      // Query Firestore for all visits
      final visitsSnapshot = await FirebaseFirestore.instance
          .collection('visits')
          .orderBy('date', descending: true)
          .get();

      // Process the visits
      final visits = <Map<String, dynamic>>[];

      for (final doc in visitsSnapshot.docs) {
        final data = doc.data();
        final visitDate = (data['date'] as Timestamp).toDate();
        final visitTime = data['time'] as String;
        
        // Only include past visits
        if (!_isVisitPassed(visitDate, visitTime)) {
          continue;
        }

        // Get visitor details
        String visitorName = data['visitorName'] ?? 'Unknown Visitor';
        String visitorId = data['visitorId'] ?? '';
        String visitorImageUrl = '';
        String visitorImageBase64 = '';

        // Try to get the visitor's profile image if available
        if (visitorId.isNotEmpty) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(visitorId)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data();
              if (userData != null) {
                visitorImageUrl = userData['profileImageUrl'] ?? '';
                if (visitorImageUrl.isEmpty) {
                  visitorImageBase64 = userData['profileImageBase64'] ?? '';
                }
              }
            }
          } catch (e) {
            debugPrint('Error fetching visitor profile: $e');
          }
        }

        visits.add({
          'id': doc.id,
          'visitorName': visitorName,
          'visitorImageUrl': visitorImageUrl,
          'visitorImageBase64': visitorImageBase64,
          'type': data['type'] == 'virtual' ? 'Virtual visit' : 'In-person visit',
          'time': data['time'] ?? 'No time specified',
          'status': data['status'] ?? 'pending',
          'date': visitDate,
          'visitorId': visitorId,
          'facility': data['facility'] ?? 'Not specified',
        });
      }

      if (mounted) {
        setState(() {
          _pastVisits = visits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading visit history: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredVisits {
    return _pastVisits.where((visit) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final visitorName = (visit['visitorName'] as String).toLowerCase();
        final visitType = (visit['type'] as String).toLowerCase();
        final visitTime = (visit['time'] as String).toLowerCase();
        final visitStatus = (visit['status'] as String).toLowerCase();
        final visitDate = DateFormat('MMMM d, yyyy').format(visit['date']).toLowerCase();
        final facility = (visit['facility'] as String).toLowerCase();

        if (!visitorName.contains(query) &&
            !visitType.contains(query) &&
            !visitTime.contains(query) &&
            !visitStatus.contains(query) &&
            !visitDate.contains(query) &&
            !facility.contains(query)) {
          return false;
        }
      }

      // Apply status filter
      if (_selectedFilter != 'all') {
        final status = visit['status'] as String;
        if (_selectedFilter == 'completed' && status != 'completed') return false;
        if (_selectedFilter == 'missed' && (status != 'pending' && status != 'approved')) return false;
        if (_selectedFilter == 'cancelled' && status != 'cancelled') return false;
      }

      // Apply date range filter
      if (_startDate != null && visit['date'].isBefore(_startDate!)) return false;
      if (_endDate != null && visit['date'].isAfter(_endDate!.add(const Duration(days: 1)))) return false;

      return true;
    }).toList();
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _showVisitDetailsModal(Map<String, dynamic> visit) {
    final visitDate = visit['date'] as DateTime;
    final formattedDate = DateFormat('MMMM d, yyyy').format(visitDate);
    final visitStatus = visit['status'] as String;
    final facility = visit['facility'] as String;
    final time = visit['time'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Colors.grey,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Past Visit Details',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(visitStatus).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStatusText(visitStatus),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(visitStatus),
                            ),
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
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visitor information
                    _buildDetailSection(
                      'Visitor Information',
                      Icons.person,
                      [
                        _buildDetailItem('Name', visit['visitorName']),
                        _buildDetailItem('ID', visit['visitorId'] ?? 'Not available'),
                      ],
                      Colors.grey,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Date and time section
                    _buildDetailSection(
                      'Date & Time',
                      Icons.calendar_today,
                      [
                        _buildDetailItem('Date', formattedDate),
                        _buildDetailItem('Time', time),
                      ],
                      Colors.grey,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Location section
                    _buildDetailSection(
                      'Location',
                      Icons.location_on,
                      [
                        _buildDetailItem('Facility', facility),
                      ],
                      Colors.grey,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Status section
                    _buildDetailSection(
                      'Status Information',
                      Icons.info_outline,
                      [
                        _buildDetailItem('Status', _getStatusText(visitStatus)),
                        if (visitStatus == 'pending') 
                          _buildDetailItem('Note', 'This visit was not completed as it was not approved before the scheduled time.'),
                        if (visitStatus == 'approved') 
                          _buildDetailItem('Note', 'This visit was approved but not completed.'),
                      ],
                      Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  bool _isVisitPassed(DateTime visitDate, String visitTime) {
    final now = DateTime.now();
    final visitDateTime = _parseVisitDateTime(visitDate, visitTime);
    return visitDateTime.isBefore(now);
  }

  DateTime _parseVisitDateTime(DateTime date, String time) {
    // Parse time string (e.g., "9:00 AM - 10:00 AM")
    final timeParts = time.split(' - ')[0].split(' ');
    final timeComponents = timeParts[0].split(':');
    int hour = int.parse(timeComponents[0]);
    int minute = int.parse(timeComponents[1]);
    
    // Convert to 24-hour format if PM
    if (timeParts[1] == 'PM' && hour != 12) {
      hour += 12;
    }
    // Convert 12 AM to 0
    if (timeParts[1] == 'AM' && hour == 12) {
      hour = 0;
    }
    
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Visit History',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showDateRangePicker,
            icon: const Icon(Icons.date_range, color: Colors.black, size: 28),
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF054D88)),
                    hintText: 'Search by visitor name, date, status...',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF054D88)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterChip('All', 'all'),
                      _buildFilterChip('Completed', 'completed'),
                      _buildFilterChip('Missed', 'missed'),
                      _buildFilterChip('Cancelled', 'cancelled'),
                    ],
                  ),
                ),
                if (_startDate != null && _endDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Date Range: ${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Visit List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVisits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No past visits found',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchPastVisits,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredVisits.length,
                          itemBuilder: (context, index) {
                            final visit = _filteredVisits[index];
                            return _buildVisitCard(visit);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: const Color(0xFF054D88),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final visitDate = visit['date'] as DateTime;
    final formattedDate = DateFormat('MMM d, yyyy').format(visitDate);
    final visitType = visit['type'] as String;
    final visitStatus = visit['status'] as String;
    final time = visit['time'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showVisitDetailsModal(visit),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildProfileImage(
                visit['visitorImageUrl'],
                visit['visitorImageBase64'],
                visit['visitorName'],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit['visitorName'],
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          visitType.contains('Virtual') ? Icons.videocam : Icons.person,
                          size: 16,
                          color: visitType.contains('Virtual') ? Colors.blue : const Color(0xFF054D88),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          visitType,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: visitType.contains('Virtual') ? Colors.blue : const Color(0xFF054D88),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$formattedDate at $time',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(visitStatus).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(minWidth: 70),
                child: Text(
                  _getStatusText(visitStatus),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(visitStatus),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? url, String? base64, String name) {
    // First try to use the URL if available
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: 50,
            height: 50,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading network image: $error');
              // If URL fails, try base64
              if (base64 != null && base64.isNotEmpty) {
                return _buildBase64Image(base64, name);
              }
              return _buildFallbackAvatar(name);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const CircularProgressIndicator();
            },
          ),
        ),
      );
    }
    
    // If no URL, try base64
    if (base64 != null && base64.isNotEmpty) {
      return _buildBase64Image(base64, name);
    }
    
    // If neither URL nor base64, show fallback
    return _buildFallbackAvatar(name);
  }

  Widget _buildBase64Image(String base64, String name) {
    try {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: Image.memory(
            base64Decode(base64),
            fit: BoxFit.cover,
            width: 50,
            height: 50,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading base64 image: $error');
              return _buildFallbackAvatar(name);
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return _buildFallbackAvatar(name);
    }
  }

  Widget _buildFallbackAvatar(String name) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey.shade200,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF054D88),
        ),
      ),
    );
  }
} 