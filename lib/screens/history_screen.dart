import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class HistoryScreen extends StatefulWidget {
  final User user;
  const HistoryScreen({super.key, required this.user});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref().child("users");
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final snapshot =
    await _dbRef.child(widget.user.uid).child("searchHistory").get();

    if (snapshot.exists) {
      final data = snapshot.value as Map;
      final history = data.entries.map((e) {
        return Map<String, dynamic>.from(e.value);
      }).toList();

      setState(() {
        _history = history.reversed.toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        backgroundColor: Colors.blue,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? const Center(child: Text("No history found."))
          : ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return Card(
            margin:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              title: Text(item['name'] ?? 'Unknown'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Status: ${item['status']}"),
                  Text("Dosage: ${item['dosage']}"),
                  Text("Expiry: ${item['expiry']}"),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
