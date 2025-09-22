import 'package:flutter/material.dart';

class InteractionScreen extends StatefulWidget {
  const InteractionScreen({super.key});

  @override
  State<InteractionScreen> createState() => _InteractionScreenState();
}

class _InteractionScreenState extends State<InteractionScreen> {
  final TextEditingController _drug1Controller = TextEditingController();
  final TextEditingController _drug2Controller = TextEditingController();

  String? _severity;
  String? _description;

  ///interactions map
  final Map<String, Map<String, Map<String, String>>> interactions = {
    "aspirin": {
      "ibuprofen": {
        "severity": "Moderate",
        "description":
        "Ibuprofen may reduce the cardioprotective antiplatelet effect of aspirin, especially if taken before aspirin. This could decrease aspirin’s effectiveness in preventing heart attack or stroke."
      },
      "warfarin": {
        "severity": "High",
        "description":
        "Both aspirin and warfarin thin the blood. When taken together, they greatly increase the risk of severe bleeding (gastrointestinal or intracranial). This combination should be used only under strict medical supervision."
      },
      "clopidogrel": {
        "severity": "High",
        "description":
        "Aspirin plus clopidogrel significantly increases bleeding risk. While sometimes prescribed together for heart conditions, this requires close monitoring by a doctor."
      }
    },
    "warfarin": {
      "ibuprofen": {
        "severity": "High",
        "description":
        "NSAIDs like ibuprofen can cause stomach ulcers and bleeding. Combining with warfarin increases bleeding risk even further, including life-threatening internal bleeding."
      },
      "paracetamol": {
        "severity": "Low",
        "description":
        "Occasional paracetamol (acetaminophen) use is usually safe with warfarin, but regular or high doses may increase warfarin’s effect, raising bleeding risk. INR monitoring may be needed."
      },
      "amiodarone": {
        "severity": "High",
        "description":
        "Amiodarone can strongly increase warfarin’s blood-thinning effect, raising the risk of major bleeding. Dose adjustment and close INR monitoring are required."
      }
    },
    "ibuprofen": {
      "paracetamol": {
        "severity": "Low",
        "description":
        "Ibuprofen and paracetamol are often used together safely for short-term pain relief. However, excessive use of either drug can cause liver (paracetamol) or kidney/stomach (ibuprofen) damage."
      },
      "prednisone": {
        "severity": "Moderate",
        "description":
        "Both ibuprofen and corticosteroids (like prednisone) can irritate the stomach lining. Using them together raises the risk of stomach ulcers or bleeding."
      }
    },
    "clopidogrel": {
      "omeprazole": {
        "severity": "Moderate",
        "description":
        "Omeprazole may reduce the effectiveness of clopidogrel by blocking its activation in the liver, lowering its ability to prevent clots. Alternative acid reducers (like pantoprazole) are preferred."
      }
    },
    "metformin": {
      "alcohol": {
        "severity": "High",
        "description":
        "Heavy alcohol use while on metformin increases the risk of lactic acidosis, a rare but potentially fatal condition. Avoid excessive drinking while taking metformin."
      }
    },
    "lisinopril": {
      "potassium": {
        "severity": "High",
        "description":
        "ACE inhibitors like lisinopril can raise potassium levels. Taking potassium supplements or salt substitutes may lead to dangerous hyperkalemia (irregular heartbeat, cardiac arrest)."
      },
      "ibuprofen": {
        "severity": "Moderate",
        "description":
        "Ibuprofen can reduce the blood-pressure-lowering effect of lisinopril and may worsen kidney function when combined, especially in older adults or those with kidney disease."
      }
    },
    "statins": {
      "grapefruit": {
        "severity": "Moderate",
        "description":
        "Grapefruit juice can increase the blood level of certain statins (simvastatin, atorvastatin), raising the risk of liver damage and muscle breakdown (rhabdomyolysis)."
      }
    }
  };


  void _checkInteraction() {
    final drug1 = _drug1Controller.text.trim().toLowerCase();
    final drug2 = _drug2Controller.text.trim().toLowerCase();

    setState(() {
      _severity = null;
      _description = null;
    });

    if (drug1.isEmpty || drug2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter both medicines")),
      );
      return;
    }

    // Look for drug1 -> drug2
    if (interactions.containsKey(drug1) &&
        interactions[drug1]!.containsKey(drug2)) {
      setState(() {
        _severity = interactions[drug1]![drug2]!["severity"];
        _description = interactions[drug1]![drug2]!["description"];
      });
    }
    // Look for drug2 -> drug1
    else if (interactions.containsKey(drug2) &&
        interactions[drug2]!.containsKey(drug1)) {
      setState(() {
        _severity = interactions[drug2]![drug1]!["severity"];
        _description = interactions[drug2]![drug1]!["description"];
      });
    } else {
      setState(() {
        _severity = "Unknown";
        _description = "No major interaction found in database.";
      });
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case "high":
        return Colors.red;
      case "moderate":
        return Colors.orange;
      case "low":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Drug Interaction Checker"),
        backgroundColor: const Color(0xFF2E86AB),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter two medicines to check interactions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Drug 1
              TextField(
                controller: _drug1Controller,
                decoration: InputDecoration(
                  labelText: "First Medicine",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.medication),
                ),
              ),
              const SizedBox(height: 16),

              // Drug 2
              TextField(
                controller: _drug2Controller,
                decoration: InputDecoration(
                  labelText: "Second Medicine",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.medical_services),
                ),
              ),
              const SizedBox(height: 20),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _checkInteraction,
                  icon: const Icon(Icons.search),
                  label: const Text("Check Interaction"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E86AB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Results
              if (_severity != null && _description != null)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning,
                            color: _getSeverityColor(_severity!),
                            size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Severity: $_severity",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: _getSeverityColor(_severity!),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _description!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
