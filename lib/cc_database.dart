import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

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
      setState(() => _isLoading = true);

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

      // Convert to CSV
      final csvData = const ListToCsvConverter().convert(rows);

      // Show preview modal
      if (!mounted) return;
      
      final shouldProceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
                        color: const Color(0xFF054D88).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.preview,
                        color: Color(0xFF054D88),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CSV Preview',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF054D88),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF054D88).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_filteredData.length} users',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF054D88),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
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
                      const Text(
                        'The following data will be exported:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF054D88),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Headers
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF054D88).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Email',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Role',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Visits',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Sample data (first 5 rows)
                            ...rows.sublist(1, rows.length > 6 ? 6 : rows.length).map((row) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row[0].toString(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row[1].toString(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      row[2].toString(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      row[4].toString(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            if (rows.length > 6) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '... and ${rows.length - 6} more rows',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'File Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'The CSV file will be saved to your Downloads folder with timestamp for easy identification.',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer with actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.download),
                      label: const Text('Download CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF054D88),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (shouldProceed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // Get downloads directory
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }

      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '${directory.path}/users_$timestamp.csv';

      // Write to file
      final File file = File(filePath);
      await file.writeAsString(csvData);

      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CSV file saved to Downloads: ${file.path.split('/').last}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  final result = await OpenFile.open(file.path);
                  if (result.type != ResultType.done) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Error opening file: ${result.message}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Error opening file: $e',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red,
        ),
      );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error exporting to CSV: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
          ),
      );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            color: const Color(0xFF054D88),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _exportToCSV,
              icon: const Icon(Icons.download, size: 20, color: Colors.white),
              label: const Text(
                'Export CSV',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF054D88),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
        children: [
          // Search bar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF054D88)),
                hintText: 'Search by name, email, or role',
                  hintStyle: TextStyle(
                  fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey.shade500,
                ),
                filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF054D88)),
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
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                              Icons.search_off,
                                  size: 48,
                              color: Colors.grey.shade400,
                            ),
                              ),
                              const SizedBox(height: 24),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  const Color(0xFF054D88).withOpacity(0.05),
                            ),
                                dataRowMinHeight: 72,
                                dataRowMaxHeight: 72,
                                horizontalMargin: 24,
                                columnSpacing: 24,
                            columns: [
                              DataColumn(
                                    label: const Text(
                                      'Name',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                onSort: (_, __) => _changeSort('name'),
                              ),
                              DataColumn(
                                    label: const Text(
                                      'Email',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                                onSort: (_, __) => _changeSort('email'),
                              ),
                                  const DataColumn(
                                    label: Text(
                                      'Profile',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                              ),
                                    ),
                              ),
                              const DataColumn(
                                    label: Text(
                                      'Actions',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF054D88),
                                      ),
                                    ),
                              ),
                            ],
                            rows: _paginatedData.map((user) {
                              return DataRow(
                                onSelectChanged: (selected) {
                                  if (selected == true) {
                                    Navigator.pushNamed(
                                      context,
                                      '/userDetails',
                                      arguments: user['id'],
                                    );
                                  }
                                },
                                cells: [
                                  DataCell(
                                        Text(
                                          user['name'],
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          user['email'],
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    _buildProfileImageCell(user),
                                  ),
                                  DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.orange,
                                          size: 22,
                                        ),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Editing ${user['name']}'),
                                              backgroundColor: Colors.orange,
                                            ),
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
          ),

          // Pagination
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 1
                      ? () => _changePage(_currentPage - 1)
                      : null,
                    icon: Icon(
                      Icons.arrow_back_ios,
                      size: 18,
                      color: _currentPage > 1 ? const Color(0xFF054D88) : Colors.grey.shade400,
                    ),
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
                            width: 36,
                            height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pageNumber == _currentPage
                                  ? const Color(0xFF054D88)
                                : Colors.transparent,
                              border: pageNumber == _currentPage
                                  ? null
                                  : Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                          ),
                          child: Center(
                            child: Text(
                              pageNumber.toString(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                color: pageNumber == _currentPage
                                    ? Colors.white
                                      : const Color(0xFF054D88),
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
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: _currentPage < _totalPages ? const Color(0xFF054D88) : Colors.grey.shade400,
                    ),
                ),
              ],
            ),
          ),
        ],
        ),
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
