import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save scan result to database
  static Future<void> saveScanResult({
    required String medicineName,
    required String status,
    required String dosage,
    required String expiryDate,
    required List<String> sideEffects,
    required Map<String, dynamic> roboflowResult,
    String? imagePath,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final scanData = {
      'medicineName': medicineName,
      'status': status,
      'dosage': dosage,
      'expiryDate': expiryDate,
      'sideEffects': sideEffects,
      'roboflowResult': roboflowResult,
      'imagePath': imagePath,
      'scanDate': DateTime.now().toIso8601String(),
      'userId': user.uid,
    };

    // Save to user's scan history
    final scanRef = _database.child('users/${user.uid}/scanHistory').push();
    await scanRef.set(scanData);

    // Also add to recent scans for quick access
    final recentScansRef = _database.child('users/${user.uid}/recentScans');
    await recentScansRef.set(scanData);
  }

  // Get user's scan history
  static Future<List<Map<String, dynamic>>> getScanHistory() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final snapshot = await _database.child('users/${user.uid}/scanHistory').get();

    if (!snapshot.exists) return [];

    final List<Map<String, dynamic>> scans = [];
    final data = snapshot.value as Map<dynamic, dynamic>;

    data.forEach((key, value) {
      scans.add(Map<String, dynamic>.from(value as Map));
    });

    // Sort by scan date (newest first)
    scans.sort((a, b) =>
        DateTime.parse(b['scanDate']).compareTo(DateTime.parse(a['scanDate']))
    );

    return scans;
  }

  // Get recent scans (last 5)
  static Future<List<Map<String, dynamic>>> getRecentScans() async {
    final allScans = await getScanHistory();
    return allScans.take(5).toList();
  }

  // Delete a scan result
  static Future<void> deleteScanResult(String scanId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _database.child('users/${user.uid}/scanHistory/$scanId').remove();
  }
}