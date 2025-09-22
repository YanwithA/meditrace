import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _profileData;
  Map<String, double> _analyticsData = {};
  bool _loading = true;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  late final DatabaseReference _historyRef;
  Stream<DatabaseEvent>? _historyStream;

  // Track which medicine names are expanded
  Set<String> _expandedNames = {};

  @override
  void initState() {
    super.initState();
    _historyRef = _dbRef.child("users/${widget.user.uid}/searchHistory");
    _loadProfile();
    _listenToSearchHistory();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _usernameController.dispose();
    _historyStream = null;
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final snapshot = await _dbRef.child("users/${widget.user.uid}").get();
    if (snapshot.exists) {
      _profileData = Map<String, dynamic>.from(snapshot.value as Map);
      _usernameController.text = _profileData?["username"] ?? "";
      _ageController.text = _profileData?["age"]?.toString() ?? "";
    } else {
      await _dbRef.child("users/${widget.user.uid}").set({
        "username": widget.user.displayName ?? "Unknown",
        "email": widget.user.email ?? "",
        "age": 0,
      });
      _loadProfile();
      return;
    }
    setState(() => _loading = false);
  }

  void _listenToSearchHistory() {
    _historyStream = _historyRef.onValue;
    _historyStream?.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        setState(() => _analyticsData = {});
        return;
      }

      final history = Map<String, dynamic>.from(snapshot.value as Map);
      final Map<String, int> counts = {};

      for (final entry in history.values) {
        // ONLY include FDA searches
        if ((entry['source'] ?? '') != 'FDA') continue;
        final name = entry['name'] ?? 'Unknown';
        counts[name] = (counts[name] ?? 0) + 1;
      }

      if (counts.isEmpty) {
        setState(() => _analyticsData = {});
        return;
      }

      final total = counts.values.fold<int>(0, (a, b) => a + b);
      final Map<String, double> percentages =
      counts.map((key, value) => MapEntry(key, value / total * 100));

      // Sort descending by percentage
      final sortedEntries = percentages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5 = Map<String, double>.fromEntries(sortedEntries.take(5));

      setState(() => _analyticsData = top5);
    });
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.isEmpty) return;
    await _dbRef
        .child("users/${widget.user.uid}/username")
        .set(_usernameController.text.trim());
    setState(() {
      _profileData?["username"] = _usernameController.text.trim();
    });
  }

  Future<void> _updateAge() async {
    if (_ageController.text.isEmpty) return;
    final newAge = int.tryParse(_ageController.text);
    if (newAge != null) {
      await _dbRef.child("users/${widget.user.uid}/age").set(newAge);
      setState(() {
        _profileData?["age"] = newAge;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Profile Page",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Username
            ListTile(
              title: TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.save),
                onPressed: _updateUsername,
              ),
            ),

            // Email
            ListTile(
              title: Text("Email: ${_profileData?["email"] ?? "N/A"}"),
            ),

            // Age
            ListTile(
              title: TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Age"),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.save),
                onPressed: _updateAge,
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _logout,
              child: const Text("Logout"),
            ),

            const Divider(thickness: 2),
            const SizedBox(height: 20),

            // Search Analytics
            const Text(
              "Search Analytics (Top 5)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _analyticsData.isEmpty
                ? const Text("No FDA search history yet.")
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _analyticsData.entries.map((e) {
                final isExpanded = _expandedNames.contains(e.key);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedNames.remove(e.key);
                            } else {
                              _expandedNames.add(e.key);
                            }
                          });
                        },
                        child: SizedBox(
                          width: 80,
                          child: Text(
                            e.key,
                            style: const TextStyle(fontSize: 14),
                            overflow: isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: e.value / 100,
                              child: Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("${e.value.toStringAsFixed(1)}%"),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
