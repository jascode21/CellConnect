import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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
      //print('Error fetching dashboard data: $e');
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
        // Generate hourly labels
        for (int i = 0; i < 24; i++) {
          final hour = (startDate.hour + i) % 24;
          labels.add('${hour}:00');
          visitCounts[labels.last] = 0;
        }
        break;
      case 'Week':
        startDate = endDate.subtract(const Duration(days: 6));
        // Generate daily labels for the week
        for (int i = 0; i <= 6; i++) {
          final day = startDate.add(Duration(days: i));
          labels.add(DateFormat('E').format(day));
          visitCounts[labels.last] = 0;
        }
        break;
      case 'Month':
        startDate = DateTime(endDate.year, endDate.month, 1);
        // Generate weekly labels for the month
        for (int i = 1; i <= 4; i++) {
          labels.add('Week $i');
          visitCounts[labels.last] = 0;
        }
        break;
      case 'Year':
        startDate = DateTime(endDate.year, 1, 1);
        // Generate monthly labels for the year
        for (int i = 0; i < 12; i++) {
          labels.add(DateFormat('MMM').format(DateTime(endDate.year, i + 1)));
          visitCounts[labels.last] = 0;
        }
        break;
      default:
        startDate = endDate.subtract(const Duration(days: 6));
        // Default to weekly view
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
            // Calculate which week of the month
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
      //print('Error generating chart data: $e');
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
    // In a real app, this would generate and download a CSV file
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting data to CSV...')),
    );
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
            color: Colors.black,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/logIn');
            },
            icon: const Icon(
              Icons.logout,
              color: Colors.black,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tab Bar: Day, Week, Month, Year
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTabButton('Day', _activeTab == 'Day'),
                        _buildTabButton('Week', _activeTab == 'Week'),
                        _buildTabButton('Month', _activeTab == 'Month'),
                        _buildTabButton('Year', _activeTab == 'Year'),
                      ],
                    ),
                    const SizedBox(height: 24),
            
                    // Top Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard(
                          icon: Icons.people,
                          title: 'Users',
                          value: formatter.format(_totalUsers),
                          change: '+${formatter.format(_userChange)}',
                          isIncrease: true,
                        ),
                        _buildStatCard(
                          icon: Icons.schedule,
                          title: 'Schedule Requests',
                          value: formatter.format(_totalRequests),
                          change: '+${formatter.format(_requestChange)}',
                          isIncrease: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
            
                    // Total Visits Chart
                    const Text(
                      'Total Visits',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Column(
                        children: [
                          // Bar Graph
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: _barGroups.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No visit data available',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : BarChart(
                                      BarChartData(
                                        alignment: BarChartAlignment.spaceAround,
                                        maxY: _calculateMaxY(),
                                        barTouchData: BarTouchData(
                                          enabled: true,
                                          touchTooltipData: BarTouchTooltipData(
                                            tooltipBgColor: Colors.blueGrey,
                                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                              return BarTooltipItem(
                                                '${_barLabels[group.x.toInt()]}: ${rod.toY.toInt()}',
                                                const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
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
                                                      fontWeight: FontWeight.bold,
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
                                                    fontWeight: FontWeight.bold,
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
                          ),
                          const SizedBox(height: 16),
            
                          // CSV Button
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _exportToCSV,
                              icon: const Icon(
                                Icons.file_download,
                                color: Color.fromARGB(255, 255, 255, 255),
                              ),
                              label: const Text(
                                'CSV',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
    
    // Round up to the nearest 5 or 10 for better readability
    if (maxY <= 10) {
      return (maxY / 2).ceil() * 2.0 + 2;
    } else if (maxY <= 50) {
      return (maxY / 5).ceil() * 5.0 + 5;
    } else {
      return (maxY / 10).ceil() * 10.0 + 10;
    }
  }

  // Build Tab Button
  Widget _buildTabButton(String label, bool isActive) {
    return TextButton(
      onPressed: () => _changeTab(label),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? Colors.black : Colors.grey,
        ),
      ),
    );
  }

  // Build Statistic Card
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String change,
    required bool isIncrease,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color.fromARGB(255, 5, 77, 136), size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isIncrease
                      ? const Color.fromARGB(255, 40, 102, 42)
                      : const Color.fromARGB(255, 150, 62, 62),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isIncrease
                        ? const Color.fromARGB(255, 40, 102, 42)
                        : const Color.fromARGB(255, 150, 62, 62),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
