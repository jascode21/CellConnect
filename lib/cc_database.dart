import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';

class DatabasePage extends StatefulWidget {
  const DatabasePage({super.key});

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _userData = [];
  List<Map<String, dynamic>> _filteredData = [];
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  int _totalPages = 1;
  final int _itemsPerPage = 10;
  String _sortField = 'createdAt';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();

    _searchController.addListener(() {
      _filterData(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final users = <Map<String, dynamic>>[];

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();

        // Get visit count for each user
        final visitsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .collection('visits')
            .get();

        final visitCount = visitsSnapshot.docs.length;

        // Format the data
        users.add({
          'id': doc.id,
          'name': data['fullName'] ??
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'email': data['email'] ?? 'No email',
          'role': data['role'] ?? 'Visitor',
          'createdAt': data['createdAt'] as Timestamp? ?? Timestamp.now(),
          'visitCount': visitCount,
          'lastVisit': _getLastVisitDate(visitsSnapshot.docs),
          'profileImageUrl': data['profileImageUrl'],
          'profileImageBase64': data['profileImageBase64'],
        });
      }

      // Sort the data
      _sortData(users, _sortField, _sortAscending);

      if (mounted) {
        setState(() {
          _userData = users;
          _filteredData = users;
          _calculatePagination();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Error fetching user data: $e
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }

  Timestamp? _getLastVisitDate(List<QueryDocumentSnapshot> visits) {
    if (visits.isEmpty) return null;

    Timestamp? lastVisit;

    for (final visit in visits) {
      final visitData = visit.data();
      final visitDate = visitData != null ? (visitData as Map<String, dynamic>)['date'] as Timestamp? : null;
      if (visitDate != null) {
        if (lastVisit == null || visitDate.compareTo(lastVisit) > 0) {
          lastVisit = visitDate;
        }
      }
    }

    return lastVisit;
  }

  void _filterData(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredData = _userData;
        _calculatePagination();
        _currentPage = 1;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    final filtered = _userData.where((user) {
      final name = user['name'].toString().toLowerCase();
      final email = user['email'].toString().toLowerCase();
      final role = user['role'].toString().toLowerCase();

      return name.contains(lowercaseQuery) ||
          email.contains(lowercaseQuery) ||
          role.contains(lowercaseQuery);
    }).toList();

    setState(() {
      _filteredData = filtered;
      _calculatePagination();
      _currentPage = 1;
    });
  }

  void _sortData(List<Map<String, dynamic>> data, String field, bool ascending) {
    data.sort((a, b) {
      dynamic valueA = a[field];
      dynamic valueB = b[field];

      // Handle null values
      if (valueA == null && valueB == null) return 0;
      if (valueA == null) return ascending ? -1 : 1;
      if (valueB == null) return ascending ? 1 : -1;

      // Handle different types
      if (valueA is Timestamp && valueB is Timestamp) {
        return ascending
            ? valueA.compareTo(valueB)
            : valueB.compareTo(valueA);
      }

      if (valueA is int && valueB is int) {
        return ascending
            ? valueA.compareTo(valueB)
            : valueB.compareTo(valueA);
      }

      // Default string comparison
      return ascending
          ? valueA.toString().compareTo(valueB.toString())
          : valueB.toString().compareTo(valueA.toString());
    });
  }

  void _calculatePagination() {
    _totalPages = (_filteredData.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;
  }

  List<Map<String, dynamic>> get _paginatedData {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= _filteredData.length) return [];

    return _filteredData.sublist(
      startIndex,
      endIndex > _filteredData.length ? _filteredData.length : endIndex,
    );
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages) return;

    setState(() {
      _currentPage = page;
    });
  }

  void _changeSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }

      _sortData(_filteredData, _sortField, _sortAscending);
    });
  }

  Future<void> _exportToCSV() async {
    try {
      // Prepare CSV data
      final header = ['Name', 'Email', 'Role', 'Created At', 'Visit Count', 'Last Visit'];
      final rows = _filteredData.map((user) {
        final createdAt = user['createdAt'] as Timestamp?;
        final lastVisit = user['lastVisit'] as Timestamp?;

        return [
          user['name'],
          user['email'],
          user['role'],
          createdAt != null
              ? DateFormat('yyyy-MM-dd').format(createdAt.toDate())
              : 'N/A',
          user['visitCount'],
          lastVisit != null
              ? DateFormat('yyyy-MM-dd').format(lastVisit.toDate())
              : 'N/A',
        ];
      }).toList();

      // Add header
      rows.insert(0, header);

      // Convert to CSV - would be used for download in a real app
      const ListToCsvConverter().convert(rows);

      // In a real app, this would download the CSV file
      // For this example, we'll just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV file generated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Print the first few lines for debugging
      //print('CSV Preview:');
      //print(csv.split('\n').take(5).join('\n'));
    } catch (e) {
      // Error exporting to CSV: $e
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting to CSV: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Database',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: screenWidth * 0.08,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _exportToCSV,
              icon: const Icon(Icons.download, size: 25, color: Colors.white),
              label: const Text(
                'CSV',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                hintText: 'Search by name, email, or role',
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Color.fromARGB(255, 98, 98, 98),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Database table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color.fromARGB(255, 5, 77, 136).withAlpha(25),
                            ),
                            dataRowMinHeight: 60,
                            dataRowMaxHeight: 60,
                            columns: [
                              DataColumn(
                                label: const Text('Name'),
                                onSort: (_, __) => _changeSort('name'),
                              ),
                              DataColumn(
                                label: const Text('Email'),
                                onSort: (_, __) => _changeSort('email'),
                              ),
                              DataColumn(
                                label: const Text('Role'),
                                onSort: (_, __) => _changeSort('role'),
                              ),
                              DataColumn(
                                label: const Text('Created At'),
                                onSort: (_, __) => _changeSort('createdAt'),
                              ),
                              DataColumn(
                                label: const Text('Visit Count'),
                                numeric: true,
                                onSort: (_, __) => _changeSort('visitCount'),
                              ),
                              DataColumn(
                                label: const Text('Last Visit'),
                                onSort: (_, __) => _changeSort('lastVisit'),
                              ),
                              DataColumn(
                                label: const Text('Profile'),
                              ),
                              const DataColumn(
                                label: Text('Actions'),
                              ),
                            ],
                            rows: _paginatedData.map((user) {
                              final createdAt = user['createdAt'] as Timestamp?;
                              final lastVisit = user['lastVisit'] as Timestamp?;

                              return DataRow(
                                cells: [
                                  DataCell(Text(user['name'])),
                                  DataCell(Text(user['email'])),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: user['role'] == 'Staff'
                                            ? const Color.fromARGB(255, 5, 77, 136).withAlpha(25)
                                            : Colors.green.withAlpha(25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        user['role'],
                                        style: TextStyle(
                                          color: user['role'] == 'Staff'
                                              ? const Color.fromARGB(255, 5, 77, 136)
                                              : Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(createdAt != null
                                        ? DateFormat('MMM d, yyyy')
                                            .format(createdAt.toDate())
                                        : 'N/A'),
                                  ),
                                  DataCell(
                                    Text(user['visitCount'].toString()),
                                  ),
                                  DataCell(
                                    Text(lastVisit != null
                                        ? DateFormat('MMM d, yyyy')
                                            .format(lastVisit.toDate())
                                        : 'N/A'),
                                  ),
                                  DataCell(
                                    _buildProfileImageCell(user),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility,
                                              color: Color.fromARGB(255, 5, 77, 136)),
                                          onPressed: () {
                                            // View user details
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Viewing details for ${user['name']}')),
                                            );
                                          },
                                          tooltip: 'View Details',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.orange),
                                          onPressed: () {
                                            // Edit user
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                  content: Text('Editing ${user['name']}')),
                                            );
                                          },
                                          tooltip: 'Edit User',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),

          // Pagination
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 1
                      ? () => _changePage(_currentPage - 1)
                      : null,
                  icon: const Icon(Icons.arrow_back_ios,
                      size: 20, color: Colors.black),
                ),
                ...List.generate(
                  _totalPages > 5 ? 5 : _totalPages,
                  (index) {
                    int pageNumber;
                    if (_totalPages <= 5) {
                      pageNumber = index + 1;
                    } else {
                      if (_currentPage <= 3) {
                        pageNumber = index + 1;
                      } else if (_currentPage >= _totalPages - 2) {
                        pageNumber = _totalPages - 4 + index;
                      } else {
                        pageNumber = _currentPage - 2 + index;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: InkWell(
                        onTap: () => _changePage(pageNumber),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pageNumber == _currentPage
                                ? const Color.fromARGB(255, 5, 77, 136)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              pageNumber.toString(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: pageNumber == _currentPage
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: _currentPage < _totalPages
                      ? () => _changePage(_currentPage + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios,
                      size: 20, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageCell(Map<String, dynamic> user) {
    final String? url = user['profileImageUrl'];
    final String? base64 = user['profileImageBase64'];
    final String name = user['name'] ?? '';

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(url),
        backgroundColor: Colors.grey.shade200,
      );
    } else if (base64 != null && base64.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: MemoryImage(base64Decode(base64)),
        backgroundColor: Colors.grey.shade200,
      );
    } else {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey.shade200,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF054D88)),
        ),
      );
    }
  }
}
