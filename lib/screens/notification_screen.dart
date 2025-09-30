// lib/screens/notification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  // ===== Expiry alerts (top) =====
  StreamSubscription<DatabaseEvent>? _alertsSub;
  List<Map<String, dynamic>> _alerts = [];

  // ===== Reminders =====
  StreamSubscription<DatabaseEvent>? _remSub;
  final _titleController = TextEditingController();
  TimeOfDay? _pickedTime;
  final List<int> _selectedDays = []; // 1..7 (Mon..Sun)
  List<Map<String, dynamic>> _reminders = [];

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _listenAlerts();
    _listenReminders();
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _remSub?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  // ---------- Alerts ----------
  void _listenAlerts() {
    final user = _auth.currentUser;
    if (user == null) return;

    _alertsSub?.cancel();
    _alertsSub = _db.child("users/${user.uid}/expiryAlerts").onValue.listen((ev) {
      if (!mounted) return;

      if (!ev.snapshot.exists) {
        setState(() => _alerts = []);
        return;
      }

      final data = Map<String, dynamic>.from(ev.snapshot.value as Map);
      final list = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final m = Map<String, dynamic>.from(value as Map);
        list.add({
          'key': key,
          'medicine': (m['medicine'] ?? '').toString(),
          'expiryIso': (m['expiryIso'] ?? '').toString(),
          'alertIso': (m['alertIso'] ?? '').toString(),
          'leadDays': (m['leadDays'] is num) ? (m['leadDays'] as num).toInt() : 7,
          'notified': m['notified'] == true,
          'createdAt': (m['createdAt'] ?? '').toString(),
        });
      });

      // Sort by nearest expiry first
      list.sort((a, b) {
        final da = DateTime.tryParse(a['expiryIso'] ?? '') ?? DateTime(2100);
        final db = DateTime.tryParse(b['expiryIso'] ?? '') ?? DateTime(2100);
        return da.compareTo(db);
      });

      setState(() => _alerts = list);
    });
  }

  // ---------- Reminders ----------
  void _listenReminders() {
    final user = _auth.currentUser;
    if (user == null) return;

    _remSub?.cancel();
    _remSub = _db.child("users/${user.uid}/reminders").onValue.listen((ev) {
      if (!mounted) return;

      if (!ev.snapshot.exists) {
        setState(() => _reminders = []);
        return;
      }

      final data = Map<String, dynamic>.from(ev.snapshot.value as Map);
      final list = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final m = Map<String, dynamic>.from(value as Map);
        final days = ((m['days'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList();

        list.add({
          'key': key,
          'notifBaseId': key.hashCode,
          'title': (m['title'] ?? '').toString(),
          'time': (m['time'] ?? '').toString(), // "HH:mm"
          'days': days,
          'enabled': m['enabled'] == true,
        });
      });

      setState(() => _reminders = list);
    });
  }

  // ---------- UI helpers ----------
  Color _expiryColor(DateTime expiry) {
    final now = DateTime.now();
    final d = expiry.difference(now).inDays;
    if (d < 0) return Colors.grey;
    if (d <= 3) return Colors.red;
    if (d <= 14) return Colors.orange;
    return Colors.green;
  }

  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // ---------- Add reminder ----------
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _pickedTime = picked);
  }

  Future<void> _addReminder() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }
    if (_pickedTime == null || _selectedDays.isEmpty || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name, pick a time, and choose at least one day.')),
      );
      return;
    }

    final reminder = {
      "title": _titleController.text.trim(),
      "time": "${_pickedTime!.hour.toString().padLeft(2, '0')}:${_pickedTime!.minute.toString().padLeft(2, '0')}",
      "days": _selectedDays,
      "enabled": true,
    };

    final ref = _db.child("users/${user.uid}/reminders").push();
    await ref.set(reminder);

    // schedule notifications
    final baseId = ref.key!.hashCode;
    final now = DateTime.now();
    for (final d in _selectedDays) {
      await NotificationService.scheduleWeeklyNotification(
        id: baseId + d,
        title: "MediTrace Reminder",
        body: "Take your ${reminder['title']}",
        weekday: d, // 1 = Mon .. 7 = Sun
        time: DateTime(now.year, now.month, now.day, _pickedTime!.hour, _pickedTime!.minute),
      );
    }

    setState(() {
      _titleController.clear();
      _pickedTime = null;
      _selectedDays.clear();
    });
  }

  Future<void> _toggleReminder({
    required String key,
    required int notifBaseId,
    required Map<String, dynamic> reminder,
    required bool enable,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.child("users/${user.uid}/reminders/$key").update({"enabled": enable});

    final days = ((reminder['days'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();

    if (!enable) {
      for (final d in days) {
        await NotificationService.cancelNotification(notifBaseId + d);
      }
    } else {
      final timeStr = (reminder['time'] ?? '').toString(); // "HH:mm"
      if (!timeStr.contains(':')) return;
      final parts = timeStr.split(':');
      final hour = int.tryParse(parts[0]) ?? 9;
      final minute = int.tryParse(parts[1]) ?? 0;

      final now = DateTime.now();
      for (final d in days) {
        await NotificationService.scheduleWeeklyNotification(
          id: notifBaseId + d,
          title: "MediTrace Reminder",
          body: "Take your ${reminder['title']}",
          weekday: d,
          time: DateTime(now.year, now.month, now.day, hour, minute),
        );
      }
    }
  }

  Future<void> _deleteReminder({
    required String key,
    required int notifBaseId,
    required List<int> days,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.child("users/${user.uid}/reminders/$key").remove();
    for (final d in days) {
      await NotificationService.cancelNotification(notifBaseId + d);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reminder deleted")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel =
    _pickedTime == null ? "No time selected" : "Time: ${_pickedTime!.format(context)}";

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications & Reminders")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ===== Expiry Alerts =====
          const Text("⚠️ Expiry Alerts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_alerts.isEmpty)
            const Text("No expiry alerts yet.")
          else
            Column(
              children: _alerts.map((a) {
                final med = a["medicine"] ?? "Medicine";
                final expiryIso = (a["expiryIso"] ?? '').toString();
                final alertIso = (a["alertIso"] ?? '').toString();

                final expiry = DateTime.tryParse(expiryIso);
                final alert = DateTime.tryParse(alertIso);
                final color = expiry != null ? _expiryColor(expiry) : Colors.grey;

                final expiryStr = expiry != null ? _fmt(expiry) : "(unknown)";
                final subtitle = StringBuffer("Expires: $expiryStr");
                if (alert != null) {
                  final isPast = alert.isBefore(DateTime.now());
                  subtitle.write(isPast
                      ? " • Alert date passed"
                      : " • Alert on ${_fmt(alert)}");
                }

                return Card(
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: color),
                    title: Text(med),
                    subtitle: Text(subtitle.toString()),
                  ),
                );
              }).toList(),
            ),

          const Divider(height: 32, thickness: 2),

          // ===== Add Reminder =====
          const Text("Medication Reminders",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: "Medicine Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(timeLabel),
              const Spacer(),
              ElevatedButton(onPressed: _pickTime, child: const Text("Pick Time")),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final dayNum = i + 1;
              final selected = _selectedDays.contains(dayNum);
              return ChoiceChip(
                label: Text(_weekdayLabels[i]),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      if (!_selectedDays.contains(dayNum)) _selectedDays.add(dayNum);
                    } else {
                      _selectedDays.remove(dayNum);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addReminder,
              child: const Text("Add Reminder"),
            ),
          ),

          const Divider(height: 32, thickness: 2),

          // ===== Existing Reminders =====
          const Text("Your Reminders",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_reminders.isEmpty)
            const Text("No reminders set yet.")
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reminders.length,
              itemBuilder: (ctx, i) {
                final r = _reminders[i];
                final key = r['key'] as String;
                final notifBaseId = r['notifBaseId'] as int;
                final title = (r['title'] ?? 'Unknown').toString();
                final time = (r['time'] ?? '').toString();
                final days = ((r['days'] as List?) ?? const [])
                    .map((e) => (e as num).toInt())
                    .toList();
                final daysLabel = days.isEmpty
                    ? "No days"
                    : days.map((d) => _weekdayLabels[d - 1]).join(", ");
                final enabled = r['enabled'] == true;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text("⏰ $time • Days: $daysLabel"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: enabled,
                          onChanged: (val) => _toggleReminder(
                            key: key,
                            notifBaseId: notifBaseId,
                            reminder: r,
                            enable: val,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete reminder',
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteReminder(
                            key: key,
                            notifBaseId: notifBaseId,
                            days: days,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }
}
