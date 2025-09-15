import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance Manager',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('Expiry Date: H/6/2025'),
            Text('Storage Duration: 2 weeks'),
            Text('Medication Duration: Please ensure to finish the medication with 1 week'),
            Text('User Instruction: Please Take the medicine after meals'),
            Divider(thickness: 2),
            SizedBox(height: 20),
            Text(
              'Medicine Deals',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pharmacy: Georgetown Pharmacy',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Deals: 5% on Paroxelol'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pharmacy: Caring Pharmacy',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Deals: 5% on Vitamins'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}