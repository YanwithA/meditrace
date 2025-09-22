// lib/screens/home_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ✅ Roboflow service (make sure file is at lib/services/roboflow_service.dart)
import 'package:meditrace/screens/services/roboflow_service.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoadingSearch = false;
  bool _isAnalyzing = false;

  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref().child("users");
  List<Map<String, dynamic>> _recentHistory = [];

  // === Roboflow setup (two models) ===
  static const String _apiKey = 'l5QBgJv58xaL9eaCh4rq'; // your PRIVATE key
  static const String _boxModel = 'medicine-box-pcltm/1';
  static const String _counterfeitModel = 'counterfeit_med_detection-tvqcg/1';

  late final RoboflowService _rfBox;
  late final RoboflowService _rfCounterfeit;

  // We’ll still keep a base threshold, but decision logic below overrides carefully.
  static const double _baseConf = 0.4;

  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _rfBox = RoboflowService(apiKey: _apiKey, modelId: _boxModel);
    _rfCounterfeit =
        RoboflowService(apiKey: _apiKey, modelId: _counterfeitModel);
    _loadRecentHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ------------------------------
  // Recent history
  // ------------------------------
  Future<void> _loadRecentHistory() async {
    final snap =
    await _dbRef.child(widget.user.uid).child("searchHistory").get();
    if (!snap.exists) {
      setState(() => _recentHistory = []);
      return;
    }

    final raw = Map<String, dynamic>.from(snap.value as Map);
    final items = <Map<String, dynamic>>[];

    for (final e in raw.entries) {
      final m = Map<String, dynamic>.from(e.value);
      items.add({
        'source': m['source'] ?? 'Unknown',
        'name': m['name'] ?? '-',
        'status': m['status'] ?? '-',
        'dosage': m['dosage'] ?? '-',
        'expiry': m['expiry'] ?? '-',
        'description': m['description'] ?? '',
        'ocrText': m['ocrText'] ?? '',
        'timestamp': m['timestamp'] ?? '',
      });
    }

    items.sort((a, b) => (b['timestamp'] ?? '')
        .toString()
        .compareTo((a['timestamp'] ?? '').toString()));

    setState(() {
      _recentHistory = items.take(10).toList();
    });
  }

  // -----------------------------------------
  // FDA Search (returns important usage)
  // -----------------------------------------
  Future<void> _searchMedicine(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoadingSearch = true);

    try {
      final url =
          "https://api.fda.gov/drug/label.json?search=openfda.brand_name:${Uri.encodeComponent(query)}&limit=1";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) {
        _showSnack("FDA API error: ${res.statusCode}");
        return;
      }

      final data = json.decode(res.body);
      if (data['results'] == null || (data['results'] as List).isEmpty) {
        _showSnack('No results found for "$query".');
        return;
      }

      final medicine = data['results'][0];

      final medicineData = {
        "source": "FDA",
        "name": medicine['openfda']?['brand_name']?[0] ?? query,
        "status": "Genuine",
        "dosage": medicine['dosage_and_administration']?[0] ?? "Unknown",
        // You said interaction page doesn’t need expiry; we keep a placeholder.
        "expiry": "Not provided",
        "description":
        medicine['indications_and_usage']?[0] ?? "No usage info.",
        "timestamp": DateTime.now().toIso8601String(),
      };

      await _dbRef
          .child(widget.user.uid)
          .child("searchHistory")
          .push()
          .set(medicineData);

      _loadRecentHistory();
    } catch (e) {
      _showSnack("Search error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  // ---------------------------------------------------
  // Scan (Camera or Gallery) + run both RF models + OCR
  // ---------------------------------------------------
  Future<void> _pickAndAnalyze(ImageSource source) async {
    try {
      setState(() => _isAnalyzing = true);

      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) {
        setState(() => _isAnalyzing = false);
        return;
      }
      final file = File(picked.path);

      // 1) Counterfeit model
      final counterfeitRes =
      await _rfCounterfeit.inferImageFile(file, params: {
        "confidence": _baseConf.toString(),
      });

      // 2) Box/authentic model
      final boxRes = await _rfBox.inferImageFile(file, params: {
        "confidence": _baseConf.toString(),
      });

      // 3) OCR
      String ocrText = '';
      try {
        final inputImage = InputImage.fromFile(file);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        ocrText = recognizedText.text;
      } catch (_) {}

      final ocrDetails = _extractOcrDetails(ocrText);

      // 4) Decide authenticity using stricter logic
      final status = _decideAuthenticity(counterfeitRes, boxRes);

      setState(() => _isAnalyzing = false);

      if (!mounted) return;
      _showScanResultDialog(
        status: status,
        counterfeitRes: counterfeitRes,
        boxRes: boxRes,
        imagePath: picked.path,
        ocrDetails: ocrDetails,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showSnack('Scan error: $e');
      }
    }
  }

  // ------------------------------
  // Authenticity decision (stricter)
  // Priority:
  // 1) If ANY model predicts 'counterfeit' with >= 0.40 -> Counterfeit
  // 2) Else if ANY model predicts 'authentic' with >= 0.60 -> Genuine
  // 3) Else Not detected
  // ------------------------------
  String _decideAuthenticity(
      Map<String, dynamic> counterfeitRes, Map<String, dynamic> boxRes) {
    final predsC = (counterfeitRes['predictions'] as List?) ?? const [];
    final predsB = (boxRes['predictions'] as List?) ?? const [];

    double _maxConf(List preds, String cls) => preds
        .where((p) => ((p['class'] ?? '').toString().toLowerCase()) == cls)
        .map((p) => (p['confidence'] ?? 0).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    final confCounterfeit = [
      _maxConf(predsC, 'counterfeit'),
      _maxConf(predsB, 'counterfeit')
    ].reduce((a, b) => a > b ? a : b);

    final confAuthentic = [
      _maxConf(predsC, 'authentic'),
      _maxConf(predsB, 'authentic')
    ].reduce((a, b) => a > b ? a : b);

    debugPrint(
        "DEBUG AUTH: counterfeit=$confCounterfeit, authentic=$confAuthentic");

    if (confCounterfeit >= 0.40) return 'Counterfeit'; // counterfeit wins
    if (confAuthentic >= 0.60) return 'Genuine';
    return 'Not detected';
  }

  // ---------------------------------------
  // OCR details (Name / Dosage / Expiry / Description)
  // ---------------------------------------
  Map<String, String> _extractOcrDetails(String text) {
    final cleaned = text.replaceAll('\r', '');
    final lines = cleaned
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // --- NAME heuristics ---
    // 1) If we find a known drug family/brand in the text, use it.
    final knownNames = [
      // common brands/generics
      'Paracetamol',
      'Acetaminophen',
      'Ibuprofen',
      'Aspirin',
      'Naproxen',
      'Panadol',
      'Amoxicillin',
      'Excedrin',
      'Caffeine',
      'Loratadine',
      'Cetirizine',
      'Dextromethorphan',
      'Guaifenesin',
      'Omeprazole',
      'Loperamide',
    ];

    String name = "Unknown";
    for (final w in knownNames) {
      if (cleaned.toLowerCase().contains(w.toLowerCase())) {
        name = w;
        break;
      }
    }

    // 2) If still Unknown, pick a likely BRAND line (mostly uppercase & long).
    if (name == "Unknown") {
      String best = "";
      double bestScore = 0;
      for (final l in lines.take(6)) {
        // Score by uppercase ratio & length (brand text tends to be like "EXCEDRIN")
        final letters = l.replaceAll(RegExp(r'[^A-Za-z]'), '');
        if (letters.isEmpty) continue;
        final upper = letters.replaceAll(RegExp(r'[^A-Z]'), '');
        final ratio = upper.length / letters.length;
        final score = ratio * (l.length.clamp(0, 30)); // prefer bold long words
        if (score > bestScore) {
          bestScore = score;
          best = l;
        }
      }
      if (bestScore > 8) {
        // extract a dominant word (strip symbols)
        final bigWord = best
            .split(RegExp(r'\s+'))
            .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), ''))
            .where((w) => w.length >= 3)
            .fold<String>("", (a, b) => b.length > a.length ? b : a);
        if (bigWord.isNotEmpty) name = _toTitle(bigWord);
      }
    }

    // --- DOSAGE (mg/mcg/g/ml and unit count like CAPLETS/TABLETS/CAPSULES) ---
    // e.g. "500 mg", "500MG", "2ml", "100 CAPLETS", "50 tablets"
    final dosageRegex = RegExp(
        r'(\b\d{1,4}\s?(?:mg|mcg|g|ml)\b|\b\d{1,4}\s?(?:tablets?|capsules?|caplets?)\b)',
        caseSensitive: false);
    final dosageMatch = dosageRegex.firstMatch(cleaned);
    final dosage = dosageMatch != null ? dosageMatch.group(0)! : "Not Found";

    // --- EXPIRY ---
    // Look for a line containing EXP/Expiry/Expire, or typical date patterns.
    final expiryLine = RegExp(r'\b(?:EXP|Exp|Expiry|Expire)\b[^\n]*')
        .firstMatch(cleaned)
        ?.group(0);
    String expiry = expiryLine ?? "Not Found";
    if (expiry == "Not Found") {
      final dateLike = RegExp(
          r'\b(0?[1-9]|1[0-2])[/\- ](0?[1-9]|[12]\d|3[01])[/\- ](\d{2,4})\b') // 09/24/2025
          .firstMatch(cleaned)
          ?.group(0);
      if (dateLike != null) expiry = "EXP $dateLike";
    }

    // --- DESCRIPTION ---
    // Compact first 1–2 lines that aren't just headers
    final description = lines.take(2).join(' ');

    return {
      "name": name,
      "expiry": expiry,
      "dosage": dosage,
      "description": description
    };
  }

  String _toTitle(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  // -------------------
  // Result dialog + save
  // -------------------
  void _showScanResultDialog({
    required String status,
    required Map<String, dynamic> counterfeitRes,
    required Map<String, dynamic> boxRes,
    required String imagePath,
    required Map<String, String> ocrDetails,
  }) {
    final isGenuine = status == 'Genuine';
    final isCounterfeit = status == 'Counterfeit';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCounterfeit
            ? 'Counterfeit Detected'
            : isGenuine
            ? 'Medicine Verified'
            : 'Medicine Not Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Status: $status",
              style: TextStyle(
                color: isCounterfeit
                    ? Colors.red
                    : (isGenuine ? Colors.green : Colors.orange),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text("Name: ${ocrDetails["name"]}"),
            Text("Dosage: ${ocrDetails["dosage"]}"),
            Text("Expiry: ${ocrDetails["expiry"]}"),
            Text("Description: ${ocrDetails["description"]}"),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _saveScanResult(
              status: status,
              counterfeitRes: counterfeitRes,
              boxRes: boxRes,
              imagePath: imagePath,
              ocrDetails: ocrDetails,
            ),
            child: const Text('Save Scan'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveScanResult({
    required String status,
    required Map<String, dynamic> counterfeitRes,
    required Map<String, dynamic> boxRes,
    required String imagePath,
    required Map<String, String> ocrDetails,
  }) async {
    final record = {
      "source": "Roboflow (box+counterfeit)",
      "name": ocrDetails["name"],
      "status": status,
      "dosage": ocrDetails["dosage"],
      "expiry": ocrDetails["expiry"],
      "description": ocrDetails["description"],
      "ocrText":
      "${ocrDetails["name"]}\n${ocrDetails["dosage"]}\n${ocrDetails["expiry"]}\n${ocrDetails["description"]}",
      "rf_box": boxRes,
      "rf_counterfeit": counterfeitRes,
      "imagePath": imagePath,
      "timestamp": DateTime.now().toIso8601String(),
    };

    await _dbRef
        .child(widget.user.uid)
        .child("searchHistory")
        .push()
        .set(record);
    if (!mounted) return;
    Navigator.of(context).pop(); // close dialog
    _showSnack('Scan saved successfully!');
    _loadRecentHistory();
  }

  // -------------------
  // Helpers
  // -------------------
  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // -------------------
  // UI
  // -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'MediTrace',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/notification'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Search Bar (FDA)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: TextField(
              controller: _searchController,
              onSubmitted: _searchMedicine,
              decoration: InputDecoration(
                hintText: 'Search medicine (FDA)…',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => _searchController.clear(),
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingSearch) const LinearProgressIndicator(),
          const SizedBox(height: 20),

          // Scan section (Gallery + Camera)
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: const Color(0xFF2E86AB),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              children: [
                const Text(
                  'Scan and identify the medicine',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing
                            ? null
                            : () => _pickAndAnalyze(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2E86AB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing
                            ? null
                            : () => _pickAndAnalyze(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2E86AB),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent Activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activity',
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/history'),
                  child: const Text("View All")),
            ],
          ),
          if (_recentHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Text("No recent activity yet."),
            )
          else
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
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Source: ${item['source']}"),
                      Text("Name: ${item['name']}"),
                      Text("Status: ${item['status']}"),
                      Text("Dosage: ${item['dosage']}"),
                      Text("Expiry: ${item['expiry']}"),
                      if ((item['description'] as String?)?.isNotEmpty ??
                          false)
                        Text("Description: ${item['description']}"),
                    ],
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }
}
