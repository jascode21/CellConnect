import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final TextEditingController textEditingController = TextEditingController();
  HomePage({super.key, required String role, required String userName});

  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, <user>!',style: TextStyle(fontFamily:'Inter', fontSize: screenWidth * 0.08, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('You do not have a scheduled visit for <insert date today>',
            style: TextStyle(fontFamily: 'Inter',fontSize: 16),
      ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/inPersonVisit');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                alignment: Alignment.centerLeft,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Schedule in-person visit', style: TextStyle(fontFamily: 'Inter',fontSize: 16, color: Color.fromARGB(255, 255, 255, 255))),
                  Icon(Icons.arrow_forward, color: Color.fromARGB(255, 255, 255, 255)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/virtualVisit');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                alignment: Alignment.centerLeft,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                 Text('Book a virtual visit', style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color.fromARGB(255, 255, 255, 255))),
                  Icon(Icons.arrow_forward, color: Color.fromARGB(255, 255, 255, 255)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Virtual visitation room:',style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const TextField(decoration: InputDecoration(labelText: 'Visitation code:', border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 5, 77, 136),
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                )
              ),
              child: const Text('Enter room', style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 255, 255, 255))
              ),
            ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
              onPressed: () { 
                // Implement Report a Problem functionality
              },
              child: const Text(
                'Did not receive visitation code? Report a Problem',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
