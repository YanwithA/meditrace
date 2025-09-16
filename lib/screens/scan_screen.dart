import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanScreen extends StatefulWidget {
  final User user;
  const ScanScreen({super.key, required this.user});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _image;
  String medicineName = '';
  String expiryDate = '';
  String dosage = '';

  final ImagePicker _picker = ImagePicker();
  final textRecognizer = TextRecognizer();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _processImage(File(pickedFile.path));
    }
  }

  Future<void> _processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText =
    await textRecognizer.processImage(inputImage);

    String text = recognizedText.text;

    setState(() {
      medicineName = _extractMedicineName(text);
      expiryDate = _extractExpiryDate(text);
      dosage = _extractDosage(text);
    });
  }

  String _extractMedicineName(String text) {
    List<String> keywords = ["Paracetamol", "Ibuprofen", "Panadol", "Naproxen"];
    for (var word in keywords) {
      if (text.toLowerCase().contains(word.toLowerCase())) {
        return word;
      }
    }
    return "Unknown";
  }

  String _extractExpiryDate(String text) {
    final regex = RegExp(r'(EXP|Exp|Expiry|Expire)[^\n]*');
    final match = regex.firstMatch(text);
    return match != null ? match.group(0)! : "Not Found";
  }

  String _extractDosage(String text) {
    final regex = RegExp(r'(\d+\s?(mg|MG|tablet|Tablets|capsule|Capsules))');
    final match = regex.firstMatch(text);
    return match != null ? match.group(0)! : "Not Found";
  }

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  void _saveAndReturn() {
    Navigator.pop(context, {
      'name': medicineName,
      'expiry': expiryDate,
      'dosage': dosage,
      'status': 'Genuine (OCR)',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Medicine")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_image != null) Image.file(_image!, height: 200),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Capture Image"),
            ),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: const Text("Pick from Gallery"),
            ),
            const SizedBox(height: 20),
            if (medicineName.isNotEmpty) ...[
              Text("💊 Medicine Name: $medicineName",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text("📅 Expiry Date: $expiryDate",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text("💊 Dosage: $dosage",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveAndReturn,
                child: const Text("✅ Save to History"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
