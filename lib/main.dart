// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Services
import 'package:meditrace/screens/services/roboflow_service.dart';
import 'package:meditrace/screens/services/notification_service.dart';

// Auth screens
import 'package:meditrace/screens/auth/login_screen.dart';
import 'package:meditrace/screens/auth/register_screen.dart';

// Feature screens (use aliases to avoid naming conflicts)
import 'package:meditrace/screens/home_screen.dart' as home show HomeScreen;
import 'package:meditrace/screens/history_screen.dart' as history show HistoryScreen;
import 'package:meditrace/screens/interaction_screen.dart' as interact show InteractionScreen;
import 'package:meditrace/screens/pharmacy_screen.dart' as pharmacy show PharmacyScreen;
import 'package:meditrace/screens/profile_screen.dart' as profile show ProfileScreen;
import 'package:meditrace/screens/notification_screen.dart' as notify show NotificationScreen;

// Optional: Roboflow client
final roboflow = RoboflowService(
  apiKey: 'l5QBgJv58xaL9eaCh4rq',
  modelId: 'medicine-box/1',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp();
  await NotificationService.init();

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
        '/notification': (context) => const notify.NotificationScreen(),
        '/history': (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) return history.HistoryScreen(user: user);
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return MainWrapper(user: snapshot.data!);
        }
        return const LoginScreen();
      },
    );
  }
}

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
    _screens = <Widget>[
      home.HomeScreen(user: widget.user),
      const notify.NotificationScreen(),
      const interact.InteractionScreen(),
      const pharmacy.PharmacyScreen(),
      profile.ProfileScreen(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: 'Notification'),
          BottomNavigationBarItem(icon: Icon(Icons.mediation), label: 'Interaction'),
          BottomNavigationBarItem(icon: Icon(Icons.local_pharmacy), label: 'Pharmacy'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
