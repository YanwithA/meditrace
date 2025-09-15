import 'package:flutter/material.dart';

class PharmacyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nearby Pharmacy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
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
                    Text('Location: Golden Triangle'),
                    Text('Distance: 5km'),
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