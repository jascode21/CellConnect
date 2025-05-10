import 'package:flutter/material.dart';

class DatabasePage extends StatelessWidget {
  const DatabasePage({super.key});

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
              onPressed: () {
                // Add CSV download logic here
              },
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
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                hintText: 'Search',
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

          // Placeholder for Database Info
          Expanded(
            child: Center(
              child: Text(
                'This is info from the database',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),

          // Pagination and Bottom Navigation Bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    // Pagination logic for "Previous"
                  },
                  icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
                ),
                const Text(
                  '1',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Pagination logic for "Next"
                  },
                  icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
