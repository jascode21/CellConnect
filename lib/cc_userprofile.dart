import 'package:flutter/material.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage ({super.key});
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: screenWidth * 0.08,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture and Name
            CircleAvatar(
              radius: 50,
              backgroundImage: const NetworkImage(
                'https://pbs.twimg.com/media/Eqt5qhoWMAAG4hG.jpg',
              ),
              onBackgroundImageError: (error, stackTrace) {
                print("Image failed to load: $error");
              },
            ),
            const SizedBox(height: 16),

            // User's Name
            const Text(
              'Mark Liwayway',
              style: TextStyle(
                fontFamily: 'Inter', // Inter font for the name
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),

            // Verified Visitor with Icon
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified,
                  color: Colors.blue,
                  size: 18,
                ),
                SizedBox(width: 4),
                Text(
                  'Verified visitor',
                  style: TextStyle(
                    fontFamily: 'Inter', // Inter font for "Verified visitor"
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Email Field
            const ProfileField(
              label: 'Email',
              icon: Icons.email,
              value: 'mark.liwayway@email.com',
            ),

            // Password Field
            const ProfileField(
              label: 'Password',
              icon: Icons.lock,
              value: '***************',
              isPassword: true,
            ),

            // Inmate Field
            const ProfileField(
              label: 'Inmate',
              icon: Icons.person,
              value: 'Carlo Liwayway',
            ),

            // Relationship Field
            const ProfileField(
              label: 'Relationship',
              icon: Icons.group,
              value: 'Brother',
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool isPassword;

  const ProfileField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter', // Inter font for labels
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 5, 77, 136),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color.fromARGB(255, 5, 77, 136),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Inter', // Inter font for values
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              if (isPassword)
                const Icon(
                  Icons.visibility_off,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
