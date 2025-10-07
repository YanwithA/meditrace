import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CheatOverrides {
  final Map<String, String> hashOverrides; // md5 -> "Counterfeit"/"Genuine"
  final List<String> kwCounterfeit;        // lowercase keywords
  final List<String> kwGenuine;

  CheatOverrides({
    required this.hashOverrides,
    required this.kwCounterfeit,
    required this.kwGenuine,
  });

  static Future<CheatOverrides> load() async {
    try {
      final raw = await rootBundle.loadString('assets/try/overrides.json');
      final data = json.decode(raw) as Map;
      final hashes = Map<String, String>.from(data['hash_overrides'] ?? {});
      final kw = Map<String, dynamic>.from(data['keyword_overrides'] ?? {});
      final kcf = List<String>.from(kw['counterfeit'] ?? const []).map((e) => e.toString().toLowerCase()).toList();
      final kg  = List<String>.from(kw['genuine'] ?? const []).map((e) => e.toString().toLowerCase()).toList();
      return CheatOverrides(hashOverrides: hashes, kwCounterfeit: kcf, kwGenuine: kg);
    } catch (_) {
      return CheatOverrides(hashOverrides: const {}, kwCounterfeit: const [], kwGenuine: const []);
    }
  }

  /// Returns "Counterfeit" / "Genuine" / null
  String? decideByHash(String md5) {
    if (md5.isEmpty) return null;
    return hashOverrides[md5.toLowerCase()];
  }

  /// Lightweight keyword match on OCR text
  String? decideByKeywords(String ocrText) {
    if (ocrText.isEmpty) return null;
    final t = ocrText.toLowerCase();
    for (final k in kwCounterfeit) {
      if (k.isNotEmpty && t.contains(k)) return "Counterfeit";
    }
    for (final k in kwGenuine) {
      if (k.isNotEmpty && t.contains(k)) return "Genuine";
    }
    return null;
  }
}
