// lib/screens/home_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Local services
import 'services/roboflow_service.dart';
import 'services/notification_service.dart';

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

  final DatabaseReference _dbUsers =
  FirebaseDatabase.instance.ref().child("users");
  List<Map<String, dynamic>> _recentHistory = [];

  // Roboflow models
  static const String _apiKey = 'l5QBgJv58xaL9eaCh4rq';
  static const String _boxModel = 'medicine-box-pcltm/2';
  static const String _counterfeitModel = 'counterfeit_med_detection-tvqcg/2';
  late final RoboflowService _rfBox;
  late final RoboflowService _rfCounterfeit;
  static const double _baseConf = 0.4;

  final TextRecognizer _textRecognizer = TextRecognizer();

  // Notify N days before expiry
  static const int _expiryLeadDays = 7;

  // debug scores (optional to show)
  double _lastCfScore = 0.0;
  double _lastAuScore = 0.0;

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

  // =========================
  // Recent history
  // =========================
  Future<void> _loadRecentHistory() async {
    try {
      final snap = await _dbUsers
          .child(widget.user.uid)
          .child("searchHistory")
          .get();
      if (!snap.exists) {
        if (!mounted) return;
        setState(() => _recentHistory = []);
        return;
      }
      final rawMap = Map<String, dynamic>.from((snap.value as Map));
      final items = <Map<String, dynamic>>[];

      for (final e in rawMap.entries) {
        final m = Map<String, dynamic>.from(e.value);
        items.add({
          'key': e.key,
          'name': m['name'] ?? '-',
          'status': m['status'] ?? '-',
          'dosage': m['dosage'] ?? '-',
          'expiry': m['expiry'] ?? '-',
          'description': m['description'] ?? '',
          'imagePath': m['imagePath'] ?? '',
          'timestamp': m['timestamp'] ?? '',
        });
      }

      items.sort((a, b) => (b['timestamp'] ?? '')
          .toString()
          .compareTo((a['timestamp'] ?? '').toString()));
      if (!mounted) return;
      setState(() => _recentHistory = items.take(10).toList());
    } catch (e) {
      if (mounted) _showSnack('Failed to load history: $e');
    }
  }

  Future<void> _confirmDelete(BuildContext context, String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text(
            'This will permanently remove the saved scan. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _deleteHistory(key);
    }
  }

  Future<void> _deleteHistory(String key) async {
    try {
      await _dbUsers
          .child(widget.user.uid)
          .child("searchHistory")
          .child(key)
          .remove();
      if (!mounted) return;
      _showSnack('Item deleted');
      _loadRecentHistory();
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e');
    }
  }

  // =========================
  // FDA Search
  // =========================
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
        "name": medicine['openfda']?['brand_name']?[0] ?? query,
        "status": "Genuine",
        "dosage": "Refer to professionals",
        "expiry": "Not provided",
        "description": medicine['indications_and_usage']?[0] ?? "No usage info.",
        "source": "FDA",
        "timestamp": DateTime.now().toIso8601String(),
      };

      await _dbUsers
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

  // =========================
  // Scan + models + OCR
  // =========================
  Future<void> _pickAndAnalyze(ImageSource source) async {
    try {
      setState(() => _isAnalyzing = true);

      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) {
        setState(() => _isAnalyzing = false);
        return;
      }
      final file = File(picked.path);

      // Run models
      final counterfeitRes = await _rfCounterfeit
          .inferImageFile(file, params: {"confidence": _baseConf.toString()});
      final boxRes = await _rfBox
          .inferImageFile(file, params: {"confidence": _baseConf.toString()});

      // OCR
      String ocrText = '';
      try {
        final inputImage = InputImage.fromFile(file);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        ocrText = recognizedText.text;
      } catch (_) {}

      // Decide + extract details
      final status = _decideAuthenticity(counterfeitRes, boxRes);
      final ocrDetails = _extractOcrDetails(ocrText);

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

  // =========================
  // Authenticity decision (stricter)
  // =========================
  String _decideAuthenticity(
      Map<String, dynamic> counterfeitRes,
      Map<String, dynamic> boxRes,
      ) {
    final predsC = (counterfeitRes['predictions'] as List?) ?? const [];
    final predsB = (boxRes['predictions'] as List?) ?? const [];

    double maxConf(List preds, String cls, {double minBoxArea = 400}) {
      double best = 0.0;
      for (final p in preds) {
        final cl = (p['class'] ?? '').toString().toLowerCase();
        if (cl != cls) continue;
        final w = (p['width'] ?? 0).toDouble();
        final h = (p['height'] ?? 0).toDouble();
        if (w <= 0 || h <= 0) continue;
        if ((w * h) < minBoxArea) continue;
        final conf = (p['confidence'] ?? 0).toDouble();
        if (conf > best) best = conf;
      }
      return best;
    }

    final cfC = maxConf(predsC, 'counterfeit');
    final cfB = maxConf(predsB, 'counterfeit');
    final auC = maxConf(predsC, 'authentic');
    final auB = maxConf(predsB, 'authentic');

    final maxCf = (cfC > cfB) ? cfC : cfB;
    final maxAu = (auC > auB) ? auC : auB;

    _lastCfScore = maxCf;
    _lastAuScore = maxAu;

    const double CF_STRONG = 0.55;
    const double AU_STRONG = 0.70;
    const double CF_QUIET = 0.25;
    const double AU_QUIET = 0.35;
    const double MARGIN = 0.20;

    if (maxCf >= CF_STRONG && maxAu <= AU_QUIET) return 'Counterfeit';
    if (maxAu >= AU_STRONG && maxCf <= CF_QUIET) return 'Genuine';
    if ((maxCf - maxAu) >= MARGIN) return 'Counterfeit';
    if ((maxAu - maxCf) >= MARGIN) return 'Genuine';
    return 'Not detected';
  }

  // =========================
  // OCR — expiry extraction
  // =========================
  final RegExp _reExpKw = RegExp(
    r'\b(exp|expiry|exp\.|exp\s*date|expiry\s*date|use\s*by|use\s*before|best\s*before|best\s*by|valid\s*till)\b',
    caseSensitive: false,
  );
  final RegExp _reMfdKw = RegExp(
    r'\b(mfd\.?|mfg\.?|manufactured|mfg\s*date|mfd\s*date|manufacture(?:d)?\s*date)\b',
    caseSensitive: false,
  );
  // matches day+month+year, month+year, or mm/yyyy, etc.
  final RegExp _reDate = RegExp(
    r'('
    r'\b[0-3]?\d[\/\-\s][0-1]?\d[\/\-\s]\d{2,4}\b'                // 21/5/2026 or 21-05-26
    r'|[0-3]?\d[\/\-\s][A-Za-z]{3,}[\/\-\s]\d{2,4}\b'             // 21 MAY 2026
    r'|[A-Za-z]{3,}\s*\d{2,4}\b'                                  // MAY 2026
    r'|\b[0-1]?\d[\/\-\s]\d{2,4}\b'                               // 05/2026
    r'|[0-3]?\d[A-Za-z]{3,}\d{2,4}\b'                             // 21MAY2026
    r')',
    caseSensitive: false,
  );

  String _findExpiryRaw(String fullText) {
    final text = fullText.replaceAll('\r', '');
    final lines = text.split('\n');

    String _wrapOnce(String s) {
      final up = s.trim().toUpperCase();
      return up.startsWith('EXP ') ? s.trim() : 'EXP ${s.trim()}';
    }

    // 1) Keyword and date on the same line
    for (final l in lines) {
      if (_reExpKw.hasMatch(l)) {
        final m = _reDate.firstMatch(l);
        if (m != null) return _wrapOnce(m.group(0)!);
      }
    }

    // 2) Keyword on line i, date on next line
    for (int i = 0; i < lines.length - 1; i++) {
      if (_reExpKw.hasMatch(lines[i])) {
        final mNext = _reDate.firstMatch(lines[i + 1]);
        if (mNext != null) return _wrapOnce(mNext.group(0)!);
      }
    }

    // 3) Soft window after keyword
    final soft = RegExp(
      r'(exp|expiry|exp\.|exp\s*date|expiry\s*date|use\s*by|best\s*before|valid\s*till)[^A-Za-z0-9]{0,20}([A-Za-z0-9/\-\s]{2,40})',
      caseSensitive: false,
    );
    final w = soft.firstMatch(text);
    if (w != null) {
      final m = _reDate.firstMatch(w.group(0)!);
      if (m != null) return _wrapOnce(m.group(0)!);
    }

    // 4) Fallback: any date (skip MFD/MFG lines + neighbors)
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (_reMfdKw.hasMatch(l)) continue;
      final m = _reDate.firstMatch(l);
      if (m != null) {
        if (i > 0 && _reMfdKw.hasMatch(lines[i - 1])) continue;
        if (i + 1 < lines.length && _reMfdKw.hasMatch(lines[i + 1])) continue;
        return _wrapOnce(m.group(0)!);
      }
    }

    return "Not Found";
  }

  DateTime? _parseExpiryDate(String raw) {
    if (raw.isEmpty || raw == "Not Found") return null;

    var t = raw
        .replaceAll(
        RegExp(r'\b(exp|expiry|expire|exp\.|date|use|by|before|best|valid|till)\b',
            caseSensitive: false),
        '')
        .replaceAll(RegExp(r'[^A-Za-z0-9/\-\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();

    const months = {
      'JAN': 1, 'JANUARY': 1,
      'FEB': 2, 'FEBRUARY': 2,
      'MAR': 3, 'MARCH': 3,
      'APR': 4, 'APRIL': 4,
      'MAY': 5,
      'JUN': 6, 'JUNE': 6,
      'JUL': 7, 'JULY': 7,
      'AUG': 8, 'AUGUST': 8,
      'SEP': 9, 'SEPT': 9, 'SEPTEMBER': 9,
      'OCT': 10, 'OCTOBER': 10,
      'NOV': 11, 'NOVEMBER': 11,
      'DEC': 12, 'DECEMBER': 12,
    };

    // 21/5/2026 or 21-05-26
    final dmyDigits = RegExp(r'^([0-3]?\d)[/\- ]([0-1]?\d)[/\- ](\d{2,4})$').firstMatch(t);
    if (dmyDigits != null) {
      final dd = int.tryParse(dmyDigits.group(1)!);
      final mm = int.tryParse(dmyDigits.group(2)!);
      var yy = int.tryParse(dmyDigits.group(3)!) ?? 0;
      if (yy < 100) yy += 2000;
      if (dd != null && mm != null && mm >= 1 && mm <= 12) {
        return DateTime(yy, mm, dd, 23, 59);
      }
    }

    // 21 MAY 2026
    final dmyWords =
    RegExp(r'^([0-3]?\d)[/\- ]([A-Z]{3,})[/\- ](\d{2,4})$').firstMatch(t);
    if (dmyWords != null) {
      final dd = int.tryParse(dmyWords.group(1)!);
      final mon = months[dmyWords.group(2)!];
      var yy = int.tryParse(dmyWords.group(3)!) ?? 0;
      if (yy < 100) yy += 2000;
      if (dd != null && mon != null) return DateTime(yy, mon, dd, 23, 59);
    }

    // 21MAY2026
    final packed = RegExp(r'^([0-3]?\d)\s*([A-Z]{3,})\s*(\d{2,4})$').firstMatch(t);
    if (packed != null) {
      final dd = int.tryParse(packed.group(1)!);
      final mon = months[packed.group(2)!];
      var yy = int.tryParse(packed.group(3)!) ?? 0;
      if (yy < 100) yy += 2000;
      if (dd != null && mon != null) return DateTime(yy, mon, dd, 23, 59);
    }

    // 20-JUN-2026 / 20 JUN 2026
    final dmy = RegExp(r'^([0-3]?\d)[/\- ]([0-1]?\d|[A-Z]{3,})[/\- ](\d{2,4})$')
        .firstMatch(t);
    if (dmy != null) {
      final dd = int.tryParse(dmy.group(1)!);
      final mmStr = dmy.group(2)!;
      final mon = months[mmStr] ?? int.tryParse(mmStr);
      var yy = int.tryParse(dmy.group(3)!) ?? 0;
      if (yy < 100) yy += 2000;
      if (dd != null && mon != null) return DateTime(yy, mon, dd, 23, 59);
    }

    // MM/YYYY or MM-YY
    final mmyy = RegExp(r'^([0-1]?\d)[/\- ](\d{2,4})$').firstMatch(t);
    if (mmyy != null) {
      final mm = int.tryParse(mmyy.group(1)!);
      var yy = int.tryParse(mmyy.group(2)!) ?? 0;
      if (yy < 100) yy += 2000;
      if (mm != null && mm >= 1 && mm <= 12) {
        final lastDay =
        DateTime(yy, mm + 1, 1).subtract(const Duration(days: 1));
        return DateTime(yy, mm, lastDay.day, 23, 59);
      }
    }

    // JUN 2026
    final monYear = RegExp(r'^([A-Z]{3,})\s+(\d{2,4})$').firstMatch(t);
    if (monYear != null) {
      final mon = months[monYear.group(1)!];
      var yy = int.tryParse(monYear.group(2)!) ?? 0;
      if (yy < 100) yy += 2000;
      if (mon != null) {
        final lastDay =
        DateTime(yy, mon + 1, 1).subtract(const Duration(days: 1));
        return DateTime(yy, mon, lastDay.day, 23, 59);
      }
    }

    // Short "MAY24"
    final myShort = RegExp(r'^([A-Z]{3,})(\d{2})$').firstMatch(t);
    if (myShort != null) {
      final mon = months[myShort.group(1)!];
      var yy = int.tryParse(myShort.group(2)!) ?? 0;
      if (yy < 100) yy += 2000;
      if (mon != null) {
        final lastDay =
        DateTime(yy, mon + 1, 1).subtract(const Duration(days: 1));
        return DateTime(yy, mon, lastDay.day, 23, 59);
      }
    }

    return null;
  }

  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _createExpiryAlertAndSchedule({
    required String medName,
    required DateTime expiryDate,
  }) async {
    // Always write the record so NotificationScreen can display it
    final alertsRef = _dbUsers.child(widget.user.uid).child('expiryAlerts');
    final alertDate =
    expiryDate.subtract(const Duration(days: _expiryLeadDays));

    final ref = alertsRef.push();
    final data = {
      "medicine": medName,
      "expiryIso": expiryDate.toIso8601String(),
      "alertIso": alertDate.toIso8601String(),
      "leadDays": _expiryLeadDays,
      "createdAt": DateTime.now().toIso8601String(),
      "notified": false,
    };
    await ref.set(data);

    // Schedule if alert date is in the future
    if (alertDate.isAfter(DateTime.now())) {
      await NotificationService.scheduleOneTimeNotification(
        id: ref.key!.hashCode,
        title: "Expiry Alert",
        body:
        "$medName is expiring in $_expiryLeadDays days (on ${_fmt(expiryDate)}).",
        dateTime: alertDate,
      );
    }
  }

  // =========================
  // OCR – medical-aware details
  // =========================

  // Strength like "5 mg", "5 mg/5 mL", "500mcg", "325 mg per 5 mL"
  final RegExp _reStrength = RegExp(
    r'\b\d{1,4}(?:\.\d+)?\s*(?:mg|mcg|µg|g|mL|ml)\s*(?:\/\s*\d{1,4}(?:\.\d+)?\s*(?:mL|ml|L|l))?(?:\s*per\s*\d{1,4}(?:\.\d+)?\s*(?:mL|ml))?',
    caseSensitive: false,
  );

  // Quantity / pack size like "4 fl oz (118 mL)", "120 mL", "100 tablets"
  final RegExp _reQuantity = RegExp(
    r'(\b\d{1,4}(?:\.\d+)?\s*(?:mL|ml|L|l|fl\s*oz|oz)\b(?:\s*\(\s*\d{1,4}(?:\.\d+)?\s*mL\s*\))?)'
    r'|(\b\d{1,4}\s*(?:tablets?|tabs?|capsules?|caps?|caplets?|sachets?|vials?|ampoules?|pcs|count)\b)',
    caseSensitive: false,
  );

  // Storage phrases
  final RegExp _reStorageLine = RegExp(
    r'\b(store|storage|keep|temperature|room\s*temperature|cool\s*dry\s*place|protect\s*from|avoid\s*sunlight)\b',
    caseSensitive: false,
  );

  final List<RegExp> _descCueRegexes = [
    RegExp(r'\bbox\b|\bblister\b|\bpack\b', caseSensitive: false),
    RegExp(r'\bdirections?\b|\bdose|dosage\b', caseSensitive: false),
    RegExp(r'\bwarning|caution|contraindication|precaution\b',
        caseSensitive: false),
  ];

  String _pullParagraphAfter(RegExp re, List<String> lines,
      {int lookAhead = 1}) {
    for (int i = 0; i < lines.length; i++) {
      if (re.hasMatch(lines[i])) {
        final buff = StringBuffer(lines[i]);
        for (int k = 1; k <= lookAhead && i + k < lines.length; k++) {
          final next = lines[i + k].trim();
          if (next.isEmpty) break;
          if (RegExp(r'^[A-Z ]{3,}$').hasMatch(next)) break; // all-caps heading
          buff.write(' $next');
        }
        return buff.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return '';
  }

  Map<String, String> _extractOcrDetails(String text) {
    final cleaned = text.replaceAll('\r', '');
    final lines = cleaned
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // ===== NAME (heuristic) =====
    final knownNames = [
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
    if (name == "Unknown" && lines.isNotEmpty) {
      String best = "";
      double bestScore = 0;
      for (final l in lines.take(6)) {
        final letters = l.replaceAll(RegExp(r'[^A-Za-z]'), '');
        if (letters.isEmpty) continue;
        final upper = letters.replaceAll(RegExp(r'[^A-Z]'), '');
        final ratio = upper.length / letters.length;
        final score = ratio * (l.length.clamp(0, 30));
        if (score > bestScore) {
          bestScore = score;
          best = l;
        }
      }
      if (bestScore > 8) {
        final bigWord = best
            .split(RegExp(r'\s+'))
            .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), ''))
            .where((w) => w.length >= 3)
            .fold<String>("", (a, b) => b.length > a.length ? b : a);
        if (bigWord.isNotEmpty) {
          name =
          '${bigWord[0].toUpperCase()}${bigWord.substring(1).toLowerCase()}';
        }
      }
    }

    // ===== Strength / Dosage =====
    String dosage = '';
    String best = '';
    for (final m in _reStrength.allMatches(cleaned)) {
      final s = m.group(0)!.trim();
      if (s.length > best.length) best = s;
    }
    dosage = best;
    if (dosage.isEmpty) {
      final fallback = RegExp(
        r'(\b\d{1,4}\s?(?:mg|mcg|g|ml)\b|\b\d{1,4}\s?(?:tablets?|capsules?|caplets?)\b)',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (fallback != null) dosage = fallback.group(0)!.trim();
    }
    final strength = dosage.isEmpty ? "Not Found" : dosage;

    // ===== Quantity / Pack Size =====
    String quantity = '';
    String bestQ = '';
    for (final m in _reQuantity.allMatches(cleaned)) {
      final s = m.group(0)!.trim();
      if (s.length > bestQ.length) bestQ = s;
    }
    quantity = bestQ;

    // ===== Storage (line + likely continuation) =====
    String storage = _pullParagraphAfter(_reStorageLine, lines, lookAhead: 1);

    // ===== Expiry =====
    final expiryRaw = _findExpiryRaw(cleaned);

    // ===== Rich description =====
    final parts = <String>[];
    if (quantity.isNotEmpty) parts.add('Quantity: $quantity');
    if (dosage != "Not Found") parts.add('Strength: $dosage');
    if (storage.isNotEmpty) parts.add('Storage: $storage');

    if (parts.length < 2) {
      for (final re in _descCueRegexes) {
        final p = _pullParagraphAfter(re, lines, lookAhead: 0);
        if (p.isNotEmpty && !parts.any((x) => x.contains(p))) {
          parts.add(p);
          if (parts.length >= 3) break;
        }
      }
    }

    final description =
    parts.isEmpty ? lines.take(3).join(' ') : parts.join(' • ');

    return {
      "name": name,
      "expiry": expiryRaw,
      "dosage": dosage,          // label kept as "Dosage"
      "description": description // storage + quantity + strength
    };
  }

  String _toTitle(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  // =========================
  // Dialog + Save + Schedule
  // =========================
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
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Status: $status",
                  style: TextStyle(
                    color: isCounterfeit
                        ? Colors.red
                        : (isGenuine ? Colors.green : Colors.orange),
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              Text(
                  "Scores — CF: ${_lastCfScore.toStringAsFixed(2)} | AU: ${_lastAuScore.toStringAsFixed(2)}"),
              const SizedBox(height: 8),
              Text("Name: ${ocrDetails["name"]}"),
              Text("Dosage: ${ocrDetails["dosage"]}"),
              Text("Expiry: ${ocrDetails["expiry"]}"),
              const SizedBox(height: 6),
              Text("Description: ${ocrDetails["description"]}"),
              if (imagePath.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(),
                const Text('Scanned image preview:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SizedBox(
                    height: 160,
                    width: double.infinity,
                    child:
                    Image.file(File(imagePath), fit: BoxFit.contain)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _saveScanResult(
                status: status,
                counterfeitRes: counterfeitRes,
                boxRes: boxRes,
                imagePath: imagePath,
                ocrDetails: ocrDetails,
              );
            },
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
    try {
      final record = {
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

      await _dbUsers
          .child(widget.user.uid)
          .child("searchHistory")
          .push()
          .set(record);

      // Parse expiry and create alert record (always), schedule if future
      final parsedExpiry = _parseExpiryDate(ocrDetails["expiry"] ?? "");
      if (parsedExpiry != null) {
        await _createExpiryAlertAndSchedule(
          medName:
          (ocrDetails["name"]?.isNotEmpty ?? false) ? ocrDetails["name"]! : "Medicine",
          expiryDate: parsedExpiry,
        );
      }

      if (!mounted) return;
      _showSnack('Scan saved successfully!');
      _loadRecentHistory();
    } catch (e) {
      if (mounted) _showSnack('Save failed: $e');
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('MediTrace',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
          // Search
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 20.0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingSearch) const LinearProgressIndicator(),
          const SizedBox(height: 20),

          // Scan area
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
                color: const Color(0xFF2E86AB),
                borderRadius: BorderRadius.circular(16.0)),
            child: Column(children: [
              const Text('Scan and identify the medicine',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                    _isAnalyzing ? null : () => _pickAndAnalyze(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                    _isAnalyzing ? null : () => _pickAndAnalyze(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black),
                  ),
                ),
              ]),
              if (_isAnalyzing) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(backgroundColor: Colors.white),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // Recent Activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Activity",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            Column(
              children: _recentHistory.map((h) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    title: Text(h['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text("Status: ${h['status']} • Dosage: ${h['dosage']}"),
                        const SizedBox(height: 6),
                        Text("Expiry: ${h['expiry']}"),
                        const SizedBox(height: 6),
                        Text("Description: ${h['description']}",
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: IconButton(
                      icon:
                      const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        final key = h['key'] as String?;
                        if (key != null) _confirmDelete(context, key);
                      },
                      tooltip: 'Delete',
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(h['name'] ?? 'Details'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Status: ${h['status']}"),
                                const SizedBox(height: 6),
                                Text("Dosage: ${h['dosage']}"),
                                const SizedBox(height: 6),
                                Text("Expiry: ${h['expiry']}"),
                                const SizedBox(height: 12),
                                const Text("Description:",
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(h['description'] ?? ''),
                                if ((h['imagePath'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 160,
                                    width: double.infinity,
                                    child: Image.file(File(h['imagePath']),
                                        fit: BoxFit.contain),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(c).pop(),
                                child: const Text('Close')),
                            TextButton(
                              onPressed: () {
                                Navigator.of(c).pop();
                                final key = h['key'] as String?;
                                if (key != null) _confirmDelete(context, key);
                              },
                              child: const Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
        ]),
      ),
    );
  }

  // ===== utils =====
  Future<String> _md5OfFile(File f) async {
    final bytes = await f.readAsBytes();
    final digest = md5.convert(Uint8List.fromList(bytes));
    return digest.toString();
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}
