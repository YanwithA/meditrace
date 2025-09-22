// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditrace/screens/services/roboflow_service.dart';

import 'package:meditrace/screens/auth/login_screen.dart';
import 'package:meditrace/screens/auth/register_screen.dart';

// Import screens using prefixes to avoid name collisions
import 'package:meditrace/screens/home_screen.dart' as home_screen;
import 'package:meditrace/screens/history_screen.dart' as history_screen;
import 'package:meditrace/screens/interaction_screen.dart' as interaction_screen;
import 'package:meditrace/screens/pharmacy_screen.dart' as pharmacy_screen;
import 'package:meditrace/screens/profile_screen.dart' as profile_screen;
import 'package:meditrace/screens/notification_screen.dart' as notification_screen;


// Global Roboflow client instance (equivalent to Python InferenceHTTPClient setup)
final roboflow = RoboflowService(
  apiKey: 'l5QBgJv58xaL9eaCh4rq',
  modelId: 'medicine-box/1',
  // apiHost defaults to 'serverless.roboflow.com'
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MediTraceApp());
}

class MediTraceApp extends StatelessWidget {
  const MediTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTrace',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        // history route - builds only when user is available
        '/history': (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            return history_screen.HistoryScreen(user: user);
          }
          // if no user, send to login
          return const LoginScreen();
        },
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // logged in -> show main wrapper (tabs)
        if (snapshot.hasData && snapshot.data != null) {
          return MainWrapper(user: snapshot.data!);
        }

        // not logged in -> show login
        return const LoginScreen();
      },
    );
  }
}

/// MainWrapper holds the BottomNavigationBar and switches screens
class MainWrapper extends StatefulWidget {
  final User user;
  const MainWrapper({super.key, required this.user});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // Build the screens list here, referencing the proper prefixed classes
    _screens = <Widget>[
      home_screen.HomeScreen(user: widget.user),
      notification_screen.NotificationScreen(),
      interaction_screen.InteractionScreen(),
      pharmacy_screen.PharmacyScreen(),
      profile_screen.ProfileScreen(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // show the currently selected screen
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none), label: 'Notification'),
          BottomNavigationBarItem(
              icon: Icon(Icons.mediation), label: 'Interaction'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_pharmacy), label: 'Pharmacy'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}