import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:meditrace/screens/auth/login_screen.dart'; // ✅ Import login screen

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
  bool _verified = false;

  // ✅ Validation patterns
  final RegExp _emailRegex =
  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  final RegExp _passwordRegex =
  RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{6,}$');

  Future<void> _findUser() async {
    final email = _emailController.text.trim();

    // ✅ 1. Check if email is empty
    if (email.isEmpty) {
      _showAlertDialog("Email Required", "Please enter your email address.");
      return;
    }

    // ✅ 2. Validate email format
    if (!_emailRegex.hasMatch(email)) {
      _showAlertDialog("Invalid Email", "Please enter a valid email format.");
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
      _securityQuestion = null;
      _verified = false;
    });

    try {
      final snapshot = await FirebaseDatabase.instance.ref('users').get();

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
    if (_answerController.text.trim().isEmpty) {
      _showAlertDialog("Missing Answer", "Please enter your security answer.");
      return;
    }

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

    // ✅ Check empty password
    if (newPass.isEmpty) {
      _showAlertDialog("Missing Password", "Please enter a new password.");
      return;
    }

    // ✅ Strong password validation
    if (!_passwordRegex.hasMatch(newPass)) {
      _showAlertDialog(
        "Weak Password",
        "Password must be at least 6 characters and include:\n• 1 uppercase letter\n• 1 lowercase letter\n• 1 number\n• 1 special character.",
      );
      return;
    }

    try {
      // Update Firebase Auth password (if logged in)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(newPass);
      }

      // Update password in Realtime DB
      final email = _emailController.text.trim();
      final snapshot = await FirebaseDatabase.instance.ref('users').get();

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
        _newPasswordController.clear();
      });

      // ✅ Show success dialog and navigate to LoginScreen
      _showSuccessDialog();

    } catch (e) {
      setState(() => _message = "❌ Failed to reset password: $e");
    }
  }

  // ✅ Alert dialog helper
  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ✅ Success dialog → redirect to login page
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Password Reset Successful",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "Your password has been successfully reset.\nPlease log in with your new credentials."),
        actions: [
          TextButton(
            child: const Text("Go to Login"),
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _answerController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step 1: Email input
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _findUser,
                  child: const Text("Find Account"),
                ),
                const SizedBox(height: 20),

                if (_securityQuestion != null && !_verified) ...[
                  Text(
                    "Security Question: $_securityQuestion",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _answerController,
                    decoration: const InputDecoration(
                      labelText: "Your Answer",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.question_answer_outlined),
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
                      prefixIcon: Icon(Icons.lock_outline),
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
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _message.startsWith("✅")
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
