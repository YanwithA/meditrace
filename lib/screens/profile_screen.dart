import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileScreen extends StatefulWidget {
  final User user; // Pass logged-in Firebase user

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _profileData;
  bool _loading = true;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final snapshot = await _dbRef.child("users/${widget.user.uid}").get();
    if (snapshot.exists) {
      setState(() {
        _profileData = Map<String, dynamic>.from(snapshot.value as Map);
        _usernameController.text = _profileData?["username"] ?? "";
        _ageController.text = _profileData?["age"]?.toString() ?? "";
        _loading = false;
      });
    } else {
      // If user profile doesn’t exist, create a default one
      await _dbRef.child("users/${widget.user.uid}").set({
        "username": widget.user.displayName ?? "Unknown",
        "email": widget.user.email ?? "",
        "age": 0,
      });
      _loadProfile();
    }
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.isEmpty) return;
    await _dbRef
        .child("users/${widget.user.uid}/username")
        .set(_usernameController.text.trim());
    setState(() {
      _profileData?["username"] = _usernameController.text.trim();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Username updated successfully ✅")),
    );
  }

  Future<void> _updateAge() async {
    if (_ageController.text.isEmpty) return;
    final newAge = int.tryParse(_ageController.text);
    if (newAge != null) {
      await _dbRef.child("users/${widget.user.uid}/age").set(newAge);
      setState(() {
        _profileData?["age"] = newAge;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Age updated successfully ✅")),
      );
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Profile Page",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Username (editable)
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

            // Email (read-only)
            ListTile(
              title: Text("Email: ${_profileData?["email"] ?? "N/A"}"),
            ),

            // Age (editable)
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

            // Example Analytics
            const Text(
              "Monthly search analytics report",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Panadol 48%"),
            const Text("Humira 18%"),
            const Text("Ozempic 18%"),
            const Text("Patanol 12%"),
            const Text("Lyrica 4%"),
          ],
        ),
      ),
    );
  }
}
