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
        final item = Map<String, dynamic>.from(e.value);
        item['key'] = e.key; // store Firebase key for deletion
        return item;
      }).toList();

      setState(() {
        _history = history.reversed.toList(); // latest first
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteHistory(String key) async {
    await _dbRef
        .child(widget.user.uid)
        .child("searchHistory")
        .child(key)
        .remove();

    setState(() {
      _history.removeWhere((item) => item['key'] == key);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("History entry deleted")),
    );
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
            margin: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            elevation: 4,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _deleteHistory(item['key']);
                    },
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Status: ${item['status'] ?? 'N/A'}",
                    style: TextStyle(
                      color: (item['status'] == 'Genuine')
                          ? Colors.green
                          : (item['status'] == 'Counterfeit')
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                  if (item['dosage'] != null)
                    Text("Dosage: ${item['dosage']}"),
                  if (item['expiry'] != null)
                    Text("Expiry: ${item['expiry']}"),
                  if (item['description'] != null)
                    Text("Description: ${item['description']}"),
                  if (item['timestamp'] != null)
                    Text(
                      "Scanned At: ${item['timestamp']}",
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
