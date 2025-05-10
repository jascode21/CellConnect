import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab Bar: Day, Week, Month, Year
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabButton('Day', false),
                _buildTabButton('Week', true), // Active tab
                _buildTabButton('Month', false),
                _buildTabButton('Year', false),
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
                  value: '1,600',
                  change: '+500',
                  isIncrease: true,
                ),
                _buildStatCard(
                  icon: Icons.schedule,
                  title: 'Schedule Requests',
                  value: '810',
                  change: '+120',
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
                  // Bar Graph Placeholder
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Center(
                        child: Text(
                          'This is the bar graph',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CSV Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Add CSV functionality
                      },
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
    );
  }

  // Build Tab Button
  Widget _buildTabButton(String label, bool isActive) {
    return TextButton(
      onPressed: () {
        // Handle Tab Press
      },
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
