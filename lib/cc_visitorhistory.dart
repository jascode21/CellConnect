import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisitorHistoryPage extends StatefulWidget {
  const VisitorHistoryPage({super.key});

  @override
  State<VisitorHistoryPage> createState() => _VisitorHistoryPageState();
}

class _VisitorHistoryPageState extends State<VisitorHistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pastVisits = [];

  @override
  void initState() {
    super.initState();
    _loadPastVisits();
  }

  Future<void> _loadPastVisits() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _pastVisits = [];
        });
        return;
      }

      final visitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visits')
          .get();

      final now = DateTime.now();
      final pastVisits = <Map<String, dynamic>>[];

      for (var doc in visitsSnapshot.docs) {
        final data = doc.data();
        final visitDate = (data['date'] as Timestamp).toDate();
        
        // Include visits that have passed or were rejected
        if (visitDate.isBefore(now) || data['status'] == 'rejected') {
          data['id'] = doc.id;
          pastVisits.add(data);
        }
      }

      // Sort by date, most recent first
      pastVisits.sort((a, b) => 
        (b['date'] as Timestamp).compareTo(a['date'] as Timestamp));

      setState(() {
        _pastVisits = pastVisits;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading past visits: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading past visits: $e')),
        );
      }
      setState(() {
        _isLoading = false;
        _pastVisits = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Visit History',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF054D88),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPastVisits,
              child: _pastVisits.isEmpty
                  ? const Center(
                      child: Text(
                        'No past visits found',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pastVisits.length,
                      itemBuilder: (context, index) {
                        final visit = _pastVisits[index];
                        final date = (visit['date'] as Timestamp).toDate();
                        final formattedDate = DateFormat('MMMM d, yyyy').format(date);
                        final visitType = visit['type'] == 'virtual' ? 'Virtual' : 'In-person';
                        final status = visit['status'] as String? ?? 'pending';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: visitType == 'Virtual' 
                                      ? Colors.blue.withAlpha((0.1 * 255).round())
                                      : const Color(0xFF054D88).withAlpha((0.1 * 255).round()),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      visitType == 'Virtual' ? Icons.videocam : Icons.person,
                                      color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      visitType,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: visitType == 'Virtual' ? Colors.blue : const Color(0xFF054D88),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: status == 'rejected' 
                                            ? Colors.red.withAlpha((0.1 * 255).round())
                                            : Colors.grey.withAlpha((0.1 * 255).round()),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status == 'rejected' ? 'REJECTED' : 'PASSED',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'rejected' ? Colors.red : Colors.grey,
                                        ),
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
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      visit['time'] ?? 'No time specified',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (visit['facility'] != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        visit['facility'],
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
} 