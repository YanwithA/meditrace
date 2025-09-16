import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import 'scan_screen.dart';
import 'medicine_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref().child("users");
  List<Map<String, dynamic>> _recentHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentHistory();
  }

  Future<void> _loadRecentHistory() async {
    final snapshot =
    await _dbRef.child(widget.user.uid).child("searchHistory").get();

    if (snapshot.exists) {
      final data = snapshot.value as Map;
      final history = data.entries.map((e) {
        final val = Map<String, dynamic>.from(e.value);
        return val;
      }).toList();

      setState(() {
        _recentHistory = history.reversed.take(3).toList();
      });
    }
  }

  Future<void> _searchMedicine(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final url =
          "https://api.fda.gov/drug/label.json?search=openfda.brand_name:$query&limit=1";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null && data['results'].isNotEmpty) {
          final medicine = data['results'][0];

          final medicineData = {
            "name": medicine['openfda']?['brand_name']?[0] ?? query,
            "status": "Genuine",
            "dosage": medicine['dosage_and_administration']?[0] ?? "Unknown",
            "expiry": "Not provided",
            "side_effects": medicine['adverse_reactions'] != null
                ? [medicine['adverse_reactions'][0]]
                : ["No side effects listed"],
          };

          await _dbRef
              .child(widget.user.uid)
              .child("searchHistory")
              .push()
              .set(medicineData);

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MedicineDetailScreen(medicineData: medicineData),
              ),
            );
          }

          _loadRecentHistory();
        } else {
          _showError("No results found for $query");
        }
      } else {
        _showError("API error: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'MediTrace',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/notification');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: _searchMedicine,
                decoration: InputDecoration(
                  hintText: 'Search medicine...',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading) const Center(child: CircularProgressIndicator()),

            // 🔹 Scan Medicine Button
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanScreen(user: widget.user),
                  ),
                );

                if (result != null && result is Map<String, dynamic>) {
                  await _dbRef
                      .child(widget.user.uid)
                      .child("searchHistory")
                      .push()
                      .set(result);

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MedicineDetailScreen(medicineData: result),
                      ),
                    );
                  }

                  _loadRecentHistory();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E86AB),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan Medicine',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Use camera to verify and get details',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Recent Searches / Scans
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/history');
                  },
                  child: const Text("View All"),
                ),
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentHistory.length,
              itemBuilder: (context, index) {
                final item = _recentHistory[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Name: ${item['name']}"),
                      Text("Status: ${item['status']}"),
                      Text("Dosage: ${item['dosage']}"),
                      Text("Expiry: ${item['expiry']}"),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),


    );
  }
}
