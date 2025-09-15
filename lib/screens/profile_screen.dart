import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile page',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ListTile(
              title: Text('Username: Mr Lim'),
            ),
            ListTile(
              title: Text('Age: 38'),
            ),
            ListTile(
              title: Text('Email: lim123@gmail.com'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: Text('Logout'),
            ),
            Divider(thickness: 2),
            SizedBox(height: 20),
            Text(
              'Monthly search analytics report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('Panadol 48%'),
            Text('Humira 18%'),
            Text('Ozempio 18%'),
            Text('Patanol 12%'),
            Text('Lyrica 4%'),
            Divider(thickness: 2),
            SizedBox(height: 20),
            Text(
              'Frequently Asked Questions (FAQ)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('A. How do I scan medicine packaging?'),
            Text('B. Doesn\'t be age, top "scan" and point your camera at the medicine table. Ensure good hygiene and voice.'),
            Text('C. Can MedTrace read handwritten labels?'),
            Text('D. It works best on printed text but may struggle with handwriting. Try typing details manually if needed.'),
            Divider(thickness: 2),
            SizedBox(height: 20),
            Text(
              'All Analytics report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('Monthly search analytics report'),
            Text('Jan'),
            Text('Panadol 48%'),
            Text('Humira 18%'),
            Text('Ozempio 18%'),
            Text('Patanol 12%'),
            Text('Lyrica 4%'),
            SizedBox(height: 10),
            Text('Feb'),
            Text('Panadol 48%'),
          ],
        ),
      ),
    );
  }
}