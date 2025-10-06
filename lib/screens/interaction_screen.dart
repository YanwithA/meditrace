// lib/screens/interaction_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InteractionScreen extends StatefulWidget {
  const InteractionScreen({Key? key}) : super(key: key);

  @override
  State<InteractionScreen> createState() => _InteractionScreenState();
}

class _InteractionScreenState extends State<InteractionScreen> {
  final TextEditingController _drugAController = TextEditingController();
  final TextEditingController _drugBController = TextEditingController();

  Map<String, dynamic>? _drugAData;
  Map<String, dynamic>? _drugBData;
  String _resultMessage = "";
  bool _loading = false;

  Future<void> _checkInteraction() async {
    final drugA = _drugAController.text.trim();
    final drugB = _drugBController.text.trim();

    if (drugA.isEmpty || drugB.isEmpty) {
      setState(() => _resultMessage = "⚠️ Please enter both medicine names.");
      return;
    }

    setState(() {
      _loading = true;
      _resultMessage = "";
      _drugAData = null;
      _drugBData = null;
    });

    try {
      final urlA =
          "https://api.fda.gov/drug/label.json?search=openfda.brand_name:${Uri.encodeComponent(drugA)}&limit=1";
      final urlB =
          "https://api.fda.gov/drug/label.json?search=openfda.brand_name:${Uri.encodeComponent(drugB)}&limit=1";

      final resA = await http.get(Uri.parse(urlA));
      final resB = await http.get(Uri.parse(urlB));

      if (resA.statusCode != 200 || resB.statusCode != 200) {
        setState(() => _resultMessage =
        "❌ FDA API error: ${resA.statusCode} / ${resB.statusCode}");
        return;
      }

      final dataA = json.decode(resA.body);
      final dataB = json.decode(resB.body);

      if ((dataA['results'] as List).isEmpty ||
          (dataB['results'] as List).isEmpty) {
        setState(() =>
        _resultMessage = "⚠️ Could not find information for one or both drugs.");
        return;
      }

      _drugAData = _extractDrugInfo(dataA['results'][0], drugA);
      _drugBData = _extractDrugInfo(dataB['results'][0], drugB);

      setState(() => _resultMessage =
      "⚠️ This information is not a substitute for professional medical advice. Please consult a doctor or pharmacist.");
    } catch (e) {
      setState(() => _resultMessage = "❌ Request failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _extractDrugInfo(Map<String, dynamic> raw, String name) {
    String joinList(List<dynamic>? list) =>
        (list ?? []).map((e) => e.toString()).join("\n");

    return {
      "name": name,
      "warnings": joinList(raw['warnings']),
      "adverse_reactions": joinList(raw['adverse_reactions']),
      "drug_interactions": joinList(raw['drug_interactions']),
    };
  }

  Widget _buildDrugSection(String title, Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _collapsibleText("Warnings", data["warnings"]),
          const SizedBox(height: 6),
          _collapsibleText("Adverse Reactions", data["adverse_reactions"]),
          const SizedBox(height: 6),
          _collapsibleText("Drug Interactions", data["drug_interactions"]),
        ]),
      ),
    );
  }

  Widget _collapsibleText(String header, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text(header,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(content),
        ),
      ],
    );
  }

  void _startOver() {
    _drugAController.clear();
    _drugBController.clear();
    setState(() {
      _drugAData = null;
      _drugBData = null;
      _resultMessage = "";
    });
  }

  @override
  void dispose() {
    _drugAController.dispose();
    _drugBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Drug Interaction Checker")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Drug A input with delete button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _drugAController,
                    decoration: const InputDecoration(
                      labelText: "First Medicine",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _drugAController.clear();
                    setState(() => _drugAData = null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Drug B input with delete button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _drugBController,
                    decoration: const InputDecoration(
                      labelText: "Second Medicine",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _drugBController.clear();
                    setState(() => _drugBData = null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _checkInteraction,
                    child: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text("Check Interaction"),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _startOver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Text("Start Over"),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Result message
            if (_resultMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_resultMessage),
              ),
            const SizedBox(height: 12),

            // Drug info sections
            _buildDrugSection("Drug A", _drugAData),
            _buildDrugSection("Drug B", _drugBData),
          ],
        ),
      ),
    );
  }
}
