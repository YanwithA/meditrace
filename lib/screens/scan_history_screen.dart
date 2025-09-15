import 'package:flutter/material.dart';

void main() {
  runApp(const MediTraceApp());
}

class MediTraceApp extends StatelessWidget {
  const MediTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTrace',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => const HomeScreen(),
        '/notification': (context) => const NotificationScreen(),
        '/interaction': (context) => const InteractionScreen(),
        '/pharmacy': (context) => const PharmacyScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/scan': (context) => const ScanScreen(),
        '/medicine-detail': (context) => const MedicineDetailScreen(),
        '/scan-history': (context) => const ScanHistoryScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'Paracetamol',
    'Ibuprofen',
    'Naproxen'
  ];

  final List<Map<String, dynamic>> recentScans = [
    {
      'name': 'Panadol Paracetamol',
      'status': 'Genuine',
      'dosage': 'Tablets',
      'expiry': 'SEP 2025',
    },
    {
      'name': 'Pepcid',
      'status': 'Genuine',
      'dosage': 'Tablets',
      'expiry': 'NOV 2025',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '9:41',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/notification');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search medicine...',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Categories
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ChoiceChip(
                      label: Text(categories[index]),
                      selected: _selectedCategory == categories[index],
                      selectedColor: const Color(0xFF2E86AB),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = categories[index];
                        });
                      },
                      labelStyle: TextStyle(
                        color: _selectedCategory == categories[index]
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Paracetamol Section
            const Text(
              'Paracetamol',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            // Medicine Card
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/medicine-detail');
              },
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Icon(Icons.medication,
                          color: Color(0xFF2E86AB), size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Panadol Paracetamol',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '10 Tablets',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Scan Section
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/scan');
              },
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E86AB),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan and identify the medicine',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Verify authenticity and get details',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Scan History Header with View All button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/scan-history');
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF2E86AB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentScans.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medicine name: ${recentScans[index]['name']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Medicine Status: ${recentScans[index]['status']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: recentScans[index]['status'] == 'Genuine'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dosage: ${recentScans[index]['dosage']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expiry Date: ${recentScans[index]['expiry']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Navigate to different screens
          if (index == 1) {
            Navigator.pushNamed(context, '/notification');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/interaction');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/pharmacy');
          } else if (index == 4) {
            Navigator.pushNamed(context, '/profile');
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Notification',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mediation),
            label: 'Interaction',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_pharmacy),
            label: 'Pharmacy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Scan History Screen
class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const ScanHistoryList(),
      bottomNavigationBar: _buildBottomNavBar(context, 0),
    );
  }
}

class ScanHistoryList extends StatelessWidget {
  const ScanHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data for scan history
    final List<Map<String, dynamic>> scanHistory = [
      {
        'name': 'Panadol Paracetamol',
        'status': 'Genuine',
        'dosage': 'Tablets',
        'expiry': 'SEP 2025',
        'sideEffects': [
          'diarrhea',
          'increased sweating',
          'loss of appetite',
          'nausea or vomiting',
          'stomach cramps or pain',
          'swelling, pain, or tenderness in the upper abdomen or stomach area'
        ],
        'date': 'Today, 9:30 AM'
      },
      {
        'name': 'Pepcid',
        'status': 'Genuine',
        'dosage': 'Tablets',
        'expiry': 'NOV 2025',
        'sideEffects': [
          'headache',
          'dizziness',
          'constipation or diarrhea'
        ],
        'date': 'Yesterday, 3:45 PM'
      },
      {
        'name': 'Amoxicillin',
        'status': 'Counterfeit',
        'dosage': 'Capsules',
        'expiry': 'MAR 2024',
        'sideEffects': [
          'rash',
          'nausea',
          'vomiting',
          'diarrhea'
        ],
        'date': 'Oct 12, 2023, 11:20 AM'
      },
      {
        'name': 'Lipitor',
        'status': 'Genuine',
        'dosage': 'Tablets',
        'expiry': 'JAN 2026',
        'sideEffects': [
          'muscle pain',
          'joint pain',
          'constipation',
          'nausea'
        ],
        'date': 'Oct 10, 2023, 2:15 PM'
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: scanHistory.length,
      itemBuilder: (context, index) {
        final item = scanHistory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item['status'] == 'Genuine'
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item['status'] == 'Genuine' ? Icons.verified : Icons.warning,
                color: item['status'] == 'Genuine' ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              item['name'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              item['date'],
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              item['status'],
              style: TextStyle(
                color: item['status'] == 'Genuine' ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Dosage', item['dosage']),
                    _buildDetailRow('Expiry Date', item['expiry']),
                    const SizedBox(height: 8),
                    const Text(
                      'Side effects:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...item['sideEffects'].map<Widget>((effect) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                        child: Text(
                          '• $effect',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Bottom Navigation Bar Widget
BottomNavigationBar _buildBottomNavBar(BuildContext context, int currentIndex) {
  return BottomNavigationBar(
    currentIndex: currentIndex,
    onTap: (index) {
      if (index == 0) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (index == 1) {
        Navigator.pushNamed(context, '/notification');
      } else if (index == 2) {
        Navigator.pushNamed(context, '/interaction');
      } else if (index == 3) {
        Navigator.pushNamed(context, '/pharmacy');
      } else if (index == 4) {
        Navigator.pushNamed(context, '/profile');
      }
    },
    type: BottomNavigationBarType.fixed,
    items: const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.notifications_none),
        label: 'Notification',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.mediation),
        label: 'Interaction',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.local_pharmacy),
        label: 'Pharmacy',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
    ],
  );
}

// Placeholder screens for navigation
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('Notification Screen')),
      bottomNavigationBar: _buildBottomNavBar(context, 1),
    );
  }
}

class InteractionScreen extends StatelessWidget {
  const InteractionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interactions')),
      body: const Center(child: Text('Interaction Screen')),
      bottomNavigationBar: _buildBottomNavBar(context, 2),
    );
  }
}

class PharmacyScreen extends StatelessWidget {
  const PharmacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacies')),
      body: const Center(child: Text('Pharmacy Screen')),
      bottomNavigationBar: _buildBottomNavBar(context, 3),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile Screen')),
      bottomNavigationBar: _buildBottomNavBar(context, 4),
    );
  }
}

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Medicine')),
      body: const Center(child: Text('Scan Screen')),
    );
  }
}

class MedicineDetailScreen extends StatelessWidget {
  const MedicineDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Details')),
      body: const Center(child: Text('Medicine Detail Screen')),
    );
  }
}