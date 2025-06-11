import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:open_file/open_file.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  String _activeTab = 'Week';
  int _totalUsers = 0;
  int _userChange = 0;
  int _totalRequests = 0;
  int _requestChange = 0;
  List<BarChartGroupData> _barGroups = [];
  List<String> _barLabels = [];
  
  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch user statistics
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final totalUsers = usersSnapshot.docs.length;
      
      // Calculate new users in the last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final newUsers = usersSnapshot.docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(thirtyDaysAgo);
      }).length;
      
      // Fetch visit requests
      final visitsSnapshot = await FirebaseFirestore.instance
          .collection('visits')
          .get();
      
      final totalRequests = visitsSnapshot.docs.length;
      
      // Calculate new requests in the last 30 days
      final newRequests = visitsSnapshot.docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(thirtyDaysAgo);
      }).length;
      
      // Generate chart data based on active tab
      await _generateChartData(_activeTab);
      
      if (mounted) {
        setState(() {
          _totalUsers = totalUsers;
          _userChange = newUsers;
          _totalRequests = totalRequests;
          _requestChange = newRequests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard data: $e')),
        );
      }
    }
  }
  
  Future<void> _generateChartData(String period) async {
    DateTime startDate;
    DateTime endDate = DateTime.now();
    List<String> labels = [];
    Map<String, int> visitCounts = {};
    
    // Set date range based on selected period
    switch (period) {
      case 'Day':
        startDate = DateTime(endDate.year, endDate.month, endDate.day).subtract(const Duration(hours: 23));
        for (int i = 0; i < 24; i++) {
          final hour = (startDate.hour + i) % 24;
          labels.add('${hour}:00');
          visitCounts[labels.last] = 0;
        }
        break;
      case 'Week':
        startDate = endDate.subtract(const Duration(days: 6));
        for (int i = 0; i <= 6; i++) {
          final day = startDate.add(Duration(days: i));
          labels.add(DateFormat('E').format(day));
          visitCounts[labels.last] = 0;
        }
        break;
      case 'Month':
        startDate = DateTime(endDate.year, endDate.month, 1);
        for (int i = 1; i <= 4; i++) {
          labels.add('Week $i');
          visitCounts[labels.last] = 0;
        }
        break;
      case 'Year':
        startDate = DateTime(endDate.year, 1, 1);
        for (int i = 0; i < 12; i++) {
          labels.add(DateFormat('MMM').format(DateTime(endDate.year, i + 1)));
          visitCounts[labels.last] = 0;
        }
        break;
      default:
        startDate = endDate.subtract(const Duration(days: 6));
        for (int i = 0; i <= 6; i++) {
          final day = startDate.add(Duration(days: i));
          labels.add(DateFormat('E').format(day));
          visitCounts[labels.last] = 0;
        }
    }
    
    try {
      // Fetch visits within the date range
      final visitsSnapshot = await FirebaseFirestore.instance
          .collection('visits')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      // Count visits for each label
      for (final doc in visitsSnapshot.docs) {
        final visitDate = (doc.data()['date'] as Timestamp).toDate();
        String label;
        
        switch (period) {
          case 'Day':
            label = '${visitDate.hour}:00';
            break;
          case 'Week':
            label = DateFormat('E').format(visitDate);
            break;
          case 'Month':
            final dayOfMonth = visitDate.day;
            final weekOfMonth = ((dayOfMonth - 1) ~/ 7) + 1;
            label = 'Week $weekOfMonth';
            break;
          case 'Year':
            label = DateFormat('MMM').format(visitDate);
            break;
          default:
            label = DateFormat('E').format(visitDate);
        }
        
        visitCounts[label] = (visitCounts[label] ?? 0) + 1;
      }
      
      // Create bar chart groups
      final barGroups = <BarChartGroupData>[];
      for (int i = 0; i < labels.length; i++) {
        final count = visitCounts[labels[i]] ?? 0;
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: const Color(0xFF054D88),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          ),
        );
      }
      
      if (mounted) {
        setState(() {
          _barGroups = barGroups;
          _barLabels = labels;
        });
      }
    } catch (e) {
      // Create empty chart if there's an error
      final barGroups = <BarChartGroupData>[];
      for (int i = 0; i < labels.length; i++) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: 0,
                color: const Color(0xFF054D88),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          ),
        );
      }
      
      if (mounted) {
        setState(() {
          _barGroups = barGroups;
          _barLabels = labels;
        });
      }
    }
  }
  
  Future<void> _exportToCSV() async {
    try {
      setState(() => _isLoading = true);

      // Prepare CSV data
      final header = ['Period', 'Visit Count'];
      final rows = <List<dynamic>>[];
      for (int i = 0; i < _barLabels.length; i++) {
        final count = _barGroups[i].barRods.first.toY.toInt();
        rows.add([_barLabels[i], count]);
      }
      rows.add([]);
      rows.add(['Summary Statistics']);
      rows.add(['Total Users', _totalUsers]);
      rows.add(['New Users (Last 30 Days)', _userChange]);
      rows.add(['Total Visit Requests', _totalRequests]);
      rows.add(['New Requests (Last 30 Days)', _requestChange]);
      rows.add(['Export Date', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())]);
      rows.insert(0, header);

      // Convert to CSV
      final csvData = const ListToCsvConverter().convert(rows);

      // Show preview modal consistent with DatabasePage
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
                              'Dashboard Data',
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
                            // Headers for Visit Statistics
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
                                      'Period',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Visit Count',
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
                            // Visit Statistics Data
                            ...rows.sublist(1, rows.length > 6 ? 6 : _barLabels.length + 1).map((row) => Padding(
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
                                    child: Text(
                                      row[1].toString(),
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
                            const SizedBox(height: 16),
                            // Summary Statistics Section
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
                                      'Summary Statistics',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...rows.sublist(_barLabels.length + 2).map((row) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row[0]?.toString() ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      row.length > 1 ? row[1]?.toString() ?? '' : '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            )),
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
      final String filePath = '${directory.path}/dashboard_stats_$timestamp.csv';

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
  
  void _changeTab(String tab) {
    if (_activeTab != tab) {
      setState(() {
        _activeTab = tab;
        _isLoading = true;
      });
      _generateChartData(tab).then((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final formatter = NumberFormat('#,###');
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: screenWidth * 0.08,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF054D88),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/logIn');
            },
            icon: const Icon(
              Icons.logout,
              color: Color(0xFF054D88),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: Container(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tab Bar: Day, Week, Month, Year
                      Container(
                        padding: const EdgeInsets.all(4),
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
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTabButton('Day', _activeTab == 'Day'),
                            _buildTabButton('Week', _activeTab == 'Week'),
                            _buildTabButton('Month', _activeTab == 'Month'),
                            _buildTabButton('Year', _activeTab == 'Year'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
              
                      // Top Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.people,
                              title: 'Total Users',
                              value: formatter.format(_totalUsers),
                              change: '+${formatter.format(_userChange)}',
                              isIncrease: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.schedule,
                              title: 'Schedule Requests',
                              value: formatter.format(_totalRequests),
                              change: '+${formatter.format(_requestChange)}',
                              isIncrease: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
              
                      // Total Visits Chart
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Visits',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF054D88),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _exportToCSV,
                                    icon: const Icon(
                                      Icons.file_download,
                                      size: 18,
                                      color: Colors.white,
                                    ),
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
                                ],
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _barGroups.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(24),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.bar_chart,
                                                size: 48,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No visit data available',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : BarChart(
                                        BarChartData(
                                          alignment: BarChartAlignment.spaceAround,
                                          maxY: _calculateMaxY(),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData: BarTouchTooltipData(
                                              tooltipBgColor: const Color(0xFF054D88),
                                              tooltipPadding: const EdgeInsets.all(8),
                                              tooltipMargin: 8,
                                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                return BarTooltipItem(
                                                  '${_barLabels[group.x.toInt()]}: ${rod.toY.toInt()}',
                                                  const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          titlesData: FlTitlesData(
                                            show: true,
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  if (value < 0 || value >= _barLabels.length) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 8.0),
                                                    child: Text(
                                                      _barLabels[value.toInt()],
                                                      style: const TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF054D88),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 30,
                                                getTitlesWidget: (value, meta) {
                                                  if (value == 0) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF054D88),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(
                                              sideTitles: SideTitles(showTitles: false),
                                            ),
                                            rightTitles: const AxisTitles(
                                              sideTitles: SideTitles(showTitles: false),
                                            ),
                                          ),
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: false,
                                            getDrawingHorizontalLine: (value) {
                                              return FlLine(
                                                color: Colors.grey.shade200,
                                                strokeWidth: 1,
                                              );
                                            },
                                          ),
                                          borderData: FlBorderData(show: false),
                                          barGroups: _barGroups,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  double _calculateMaxY() {
    if (_barGroups.isEmpty) return 10;
    
    double maxY = 0;
    for (final group in _barGroups) {
      for (final rod in group.barRods) {
        if (rod.toY > maxY) {
          maxY = rod.toY;
        }
      }
    }
    
    if (maxY <= 10) {
      return (maxY / 2).ceil() * 2.0 + 2;
    } else if (maxY <= 50) {
      return (maxY / 5).ceil() * 5.0 + 5;
    } else {
      return (maxY / 10).ceil() * 10.0 + 10;
    }
  }

  Widget _buildTabButton(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeTab(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF054D88).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? const Color(0xFF054D88) : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String change,
    required bool isIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF054D88).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF054D88),
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF054D88),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isIncrease
                  ? const Color(0xFF28A745).withOpacity(0.1)
                  : const Color(0xFFDC3545).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isIncrease ? const Color(0xFF28A745) : const Color(0xFFDC3545),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isIncrease ? const Color(0xFF28A745) : const Color(0xFFDC3545),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}