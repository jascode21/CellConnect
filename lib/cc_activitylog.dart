import 'package:flutter/material.dart';

class ActivityLog extends StatelessWidget {
  const ActivityLog({super.key});

  @override
  Widget build(BuildContext context) {
     final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Activity Log',
          style: TextStyle(fontFamily: 'Inter', fontSize: screenWidth * 0.08, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Row
            Row(
              children: [
                // Date Range Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    items: ['Date Range']
                        .map((filter) => DropdownMenuItem<String>(
                              value: filter,
                              child: Text(
                                filter,
                                style: const TextStyle(fontFamily: 'Inter'),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {},
                    decoration: InputDecoration(
                      labelText: 'Date Range',
                      labelStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Activity Type Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    items: ['Activity Type']
                        .map((filter) => DropdownMenuItem<String>(
                              value: filter,
                              child: Text(
                                filter,
                                style: const TextStyle(fontFamily: 'Inter'),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {},
                    decoration: InputDecoration(
                      labelText: 'Activity Type',
                      labelStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section Header
            const Text(
              'November 17, 2024 - Today',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Activity List
            Expanded(
              child: ListView(
                children: [
                  ActivityEntry(
                    icon: Icons.check_circle_outline,
                    title: 'Virtual Visit Ended',
                    subtitle: 'Concluded the virtual session with the inmate.',
                    time: '10:00 AM',
                    name: 'Joanne Ramos',
                    imageUrl: 'https://pbs.twimg.com/media/FxJUoDVWIAAX2dq.jpg',
                  ),
                  ActivityEntry(
                    icon: Icons.logout,
                    title: 'Logged out',
                    subtitle: 'Successfully logged out of the system.',
                    time: '10:00 PM',
                    name: 'Rafael Cruz',
                    imageUrl: 'https://pbs.twimg.com/media/GQSohVhbUAAwUfc.jpg',
                  ),
                  ActivityEntry(
                    icon: Icons.calendar_today_outlined,
                    title: 'Visit Scheduled',
                    subtitle: 'Submitted an in-person visit schedule.',
                    time: '9:34 AM',
                    name: 'Evan Garcia',
                    imageUrl: 'https://pbs.twimg.com/media/FcgtuuJaMAA-JD-.jpg',
                  ),
                  ActivityEntry(
                    icon: Icons.login,
                    title: 'Logged in',
                    subtitle: 'Successfully logged into the system.',
                    time: '9:21 AM',
                    name: 'Mark Liwayway',
                    imageUrl: 'https://pbs.twimg.com/media/Eqt5qhoWMAAG4hG.jpg',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final String name;
  final String imageUrl;

  const ActivityEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.name,
    required this.imageUrl,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row for Icon, Title, and Time
          Row(
            children: [
              Icon(
                icon,
                color: const Color.fromARGB(255, 5, 77, 136),
                size: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Subtitle
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          // Row for Profile Picture and Name
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage(imageUrl),
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Divider(thickness: 1, color: Colors.grey),
        ],
      ),
    );
  }
}
