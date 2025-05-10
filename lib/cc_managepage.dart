import 'package:flutter/material.dart';

class ManagePage extends StatelessWidget {
  const ManagePage ({super.key});
  @override
  Widget build(BuildContext context) {
     final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'November 2024',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: screenWidth * 0.08,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Add dropdown action here
            },
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black, size: 28),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                String day = ['S', 'M', 'T', 'W', 'T', 'F', 'S'][index];
                bool isActive = index == 0; // Highlight today's date
                return Column(
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isActive ? const Color.fromARGB(255, 5, 77, 136) : Colors.transparent,
                      child: Text(
                        (17 + index).toString(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 24),

          // Scheduled Today Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Scheduled Today',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by visitor name',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scheduled Visitors List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                _buildVisitorCard(
                  name: 'Evan Garcia',
                  type: 'In-person visit',
                  time: '10:00 AM - 11:00 AM',
                  imageUrl: 'https://pbs.twimg.com/media/FcgtuuJaMAA-JD-.jpg', // Replace with real image URL
                  onApprove: () {},
                  onDecline: () {},
                ),
                _buildVisitorCard(
                  name: 'Katarina Reyes',
                  type: 'Virtual visit',
                  time: '3:00 PM - 4:00 PM',
                  imageUrl: 'https://pbs.twimg.com/media/FtGhtzmaUAMpsGc.jpg',
                  onApprove: () {},
                  onDecline: () {},
                ),
                _buildVisitorCard(
                  name: 'Joanne Ramos',
                  type: 'Virtual visit',
                  time: '9:00 AM - 10:00 AM',
                  imageUrl: 'https://pbs.twimg.com/media/FxJUoDVWIAAX2dq.jpg',
                  onStart: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build Visitor Card Widget
  Widget _buildVisitorCard({
    required String name,
    required String type,
    required String time,
    required String imageUrl, // New parameter for image URL
    VoidCallback? onApprove,
    VoidCallback? onDecline,
    VoidCallback? onStart,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(imageUrl), // Load image from the URL
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$type - $time',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (onApprove != null && onDecline != null) ...[
              IconButton(
                onPressed: onApprove,
                icon: const Icon(Icons.check_circle, color: Color.fromARGB(255, 5, 77, 136), size: 40),
              ),
              IconButton(
                onPressed: onDecline,
                icon: const Icon(Icons.cancel, color: Color.fromARGB(255, 150, 62, 62), size: 40),
              ),
            ],
            if (onStart != null)
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
