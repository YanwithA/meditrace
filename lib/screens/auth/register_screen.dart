import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:meditrace/main.dart';
import 'package:meditrace/screens/auth/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _answerController = TextEditingController();

  String _selectedQuestion = "What is your pet's name?";
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // 1️⃣ Create user in Firebase Auth
        UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user!;

        // 2️⃣ Save username + security info in Realtime DB
        await FirebaseDatabase.instance.ref("users/${user.uid}").set({
          "username": _usernameController.text.trim(),
          "email": user.email,
          "securityQuestion": _selectedQuestion,
          "securityAnswer": _answerController.text.trim().toLowerCase(),
          "createdAt": DateTime.now().toIso8601String(),
        });

        // 3️⃣ Navigate to MainWrapper
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainWrapper(user: user)),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Registration failed';
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'The account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is not valid.';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      }

      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Column(
              children: [
                Image.asset('assets/images/meditrace_logo.png', height: 120),
                const SizedBox(height: 20),
                const Text('MediTrace',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
                const SizedBox(height: 8),
                const Text('Your Personal Medication Manager',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 40),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildInputField(
                    controller: _usernameController,
                    label: "Username",
                    prefixIcon: Icons.person_outline,
                    validator: (v) =>
                    v == null || v.isEmpty ? 'Enter your username' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _emailController,
                    label: "Email",
                    prefixIcon: Icons.email_outlined,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Enter your email'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _passwordController,
                    label: "Password",
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    validator: (v) =>
                    v != null && v.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _confirmPasswordController,
                    label: "Confirm Password",
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedQuestion,
                    items: const [
                      DropdownMenuItem(
                          value: "What is your pet's name?",
                          child: Text("What is your pet's name?")),
                      DropdownMenuItem(
                          value: "What is your favourite color?",
                          child: Text("What is your favourite color?")),
                      DropdownMenuItem(
                          value: "What city were you born in?",
                          child: Text("What city were you born in?")),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedQuestion = v ?? _selectedQuestion),
                    decoration: InputDecoration(
                      labelText: "Security Question",
                      prefixIcon: const Icon(Icons.question_mark_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _answerController,
                    label: "Security Answer",
                    prefixIcon: Icons.help_outline,
                    validator: (v) =>
                    v == null || v.isEmpty ? 'Enter your answer' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Register',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account?"),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        ),
                        child: const Text('Login',
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
