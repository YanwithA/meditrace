import 'package:flutter/material.dart';

class MedicineDetailScreen extends StatelessWidget {
  final Map<String, dynamic> medicineData;

  const MedicineDetailScreen({super.key, required this.medicineData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(medicineData['name'] ?? 'Medicine Details'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medicineData['name'] ?? 'Unknown Medicine',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (medicineData['status'] != null)
                Text(
                  "Status: ${medicineData['status']}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: medicineData['status'].toString().contains('Genuine')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              const SizedBox(height: 12),
              if (medicineData['dosage'] != null)
                Text("Dosage: ${medicineData['dosage']}",
                    style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              const SizedBox(height: 20),
              if (medicineData['side_effects'] != null &&
                  (medicineData['side_effects'] as List).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Side Effects:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...List.generate(
                      (medicineData['side_effects'] as List).length,
                          (index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("• "),
                            Expanded(
                              child: Text(
                                medicineData['side_effects'][index],
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
