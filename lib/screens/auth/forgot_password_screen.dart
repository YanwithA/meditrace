import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _answerController = TextEditingController();
  final _newPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String? _securityQuestion;
  String? _correctAnswer;
  String _message = '';
  bool _isLoading = false;
  bool _verified = false; // track if security question was passed

  Future<void> _findUser() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final email = _emailController.text.trim();
      final snapshot =
      await FirebaseDatabase.instance.ref('users').get();

      if (!snapshot.exists) {
        setState(() => _message = "❌ No users found in database.");
        return;
      }

      Map data = snapshot.value as Map;
      bool found = false;

      data.forEach((key, value) {
        if (value['email'] == email) {
          _securityQuestion = value['securityQuestion'];
          _correctAnswer = value['securityAnswer'];
          found = true;
        }
      });

      if (!found) {
        setState(() => _message = "❌ No account found with this email.");
      }
    } catch (e) {
      setState(() => _message = "❌ Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAnswer() async {
    if (_answerController.text.trim().toLowerCase() ==
        _correctAnswer?.toLowerCase()) {
      setState(() {
        _verified = true;
        _message = "✅ Security answer correct. Please set a new password.";
      });
    } else {
      setState(() => _message = "❌ Incorrect answer. Try again.");
    }
  }

  Future<void> _resetPassword() async {
    final newPass = _newPasswordController.text.trim();
    if (newPass.length < 6) {
      setState(() => _message = "❌ Password must be at least 6 characters.");
      return;
    }

    try {
      // Update Firebase Auth password
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(newPass);
      }

      // Also update in Realtime DB
      final email = _emailController.text.trim();
      final snapshot =
      await FirebaseDatabase.instance.ref('users').get();

      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) async {
          if (value['email'] == email) {
            await FirebaseDatabase.instance
                .ref('users/$key/password')
                .set(newPass);
          }
        });
      }

      setState(() {
        _message = "✅ Password successfully reset!";
        _verified = false;
      });
    } catch (e) {
      setState(() => _message = "❌ Failed to reset password: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step 1: Email input
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _findUser,
                child: const Text("Find Account"),
              ),
              const SizedBox(height: 20),

              if (_securityQuestion != null && !_verified) ...[
                Text("Security Question: $_securityQuestion"),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _answerController,
                  decoration: const InputDecoration(
                    labelText: "Your Answer",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _verifyAnswer,
                  child: const Text("Verify Answer"),
                ),
              ],

              if (_verified) ...[
                TextFormField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _resetPassword,
                  child: const Text("Reset Password"),
                ),
              ],

              const SizedBox(height: 20),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
              if (_message.isNotEmpty)
                Text(
                  _message,
                  style: TextStyle(
                      color: _message.startsWith("✅")
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
