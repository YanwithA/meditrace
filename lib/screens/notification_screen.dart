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

  // ===== Expiry Alerts =====
  List<Map<String, dynamic>> _expiryAlerts = [];
  StreamSubscription<DatabaseEvent>? _alertsSub;

  // ===== Reminders =====
  final _titleController = TextEditingController();
  TimeOfDay? _pickedTime;
  List<int> _selectedDays = []; // 1=Mon..7=Sun
  List<Map<String, dynamic>> _reminders = [];
  StreamSubscription<DatabaseEvent>? _remindersSub;

  static const _weekdayLabels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  @override
  void initState() {
    super.initState();
    _listenAlerts();
    _listenReminders();
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _remindersSub?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  // ---- Live listeners ----
  void _listenAlerts() {
    final user = _auth.currentUser;
    if (user == null) return;

    _alertsSub?.cancel();
    _alertsSub = _db.child("users/${user.uid}/expiryAlerts").onValue.listen((event) {
      if (!mounted) return;

      if (!event.snapshot.exists) {
        setState(() => _expiryAlerts = []);
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final list = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final m = Map<String, dynamic>.from(value as Map);
        list.add({
          "key": key,
          "medicine": (m["medicine"] ?? "").toString(),
          "expiryIso": (m["expiryIso"] ?? "").toString(),
          "alertIso": (m["alertIso"] ?? "").toString(),
          "leadDays": (m["leadDays"] ?? 7) as int,
          "notified": m["notified"] == true,
        });
      });

      // sort by expiry (soonest first)
      list.sort((a, b) {
        final da = DateTime.tryParse(a["expiryIso"] ?? "") ?? DateTime(2100);
        final db = DateTime.tryParse(b["expiryIso"] ?? "") ?? DateTime(2100);
        return da.compareTo(db);
      });

      setState(() => _expiryAlerts = list);
    });
  }

  void _listenReminders() {
    final user = _auth.currentUser;
    if (user == null) return;

    _remindersSub?.cancel();
    _remindersSub = _db.child("users/${user.uid}/reminders").onValue.listen((event) {
      if (!mounted) return;

      if (!event.snapshot.exists) {
        setState(() => _reminders = []);
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final list = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final m = Map<String, dynamic>.from(value as Map);
        final daysRaw = (m['days'] as List?) ?? const [];
        final days = daysRaw.map((e) => (e as num).toInt()).toList();
        list.add({
          'key': key,
          'notifBaseId': key.hashCode,
          'title': (m['title'] ?? '').toString(),
          'time': (m['time'] ?? '').toString(), // "HH:MM"
          'days': days,
          'enabled': (m['enabled'] == true),
        });
      });

      setState(() => _reminders = list);
    });
  }

  // ---- Helpers for expiry cards ----
  Color _expiryColor(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    if (diff < 0) return Colors.grey;     // expired
    if (diff <= 3) return Colors.red;      // urgent
    if (diff <= 14) return Colors.orange;  // soon
    return Colors.green;                   // safe
  }

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}";

  String _daysLeftLabel(DateTime? expiry) {
    if (expiry == null) return "";
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff < 0) return "Expired ${diff.abs()} day(s) ago";
    if (diff == 0) return "Expires today";
    if (diff == 1) return "1 day left";
    return "$diff days left";
  }

  // ---- Reminder actions ----
  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
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
      "time": "${_pickedTime!.hour.toString().padLeft(2,'0')}:${_pickedTime!.minute.toString().padLeft(2,'0')}",
      "days": _selectedDays,
      "enabled": true,
    };

    final ref = _db.child("users/${user.uid}/reminders").push();
    await ref.set(reminder);

    // schedule local weekly notifications (one per selected day)
    final baseId = ref.key!.hashCode;
    final now = DateTime.now();
    for (final d in _selectedDays) {
      await NotificationService.scheduleWeeklyNotification(
        id: baseId + d,
        title: "MediTrace Reminder",
        body: "Take your ${reminder['title']}",
        weekday: d, // 1..7 (Mon..Sun)
        time: DateTime(now.year, now.month, now.day, _pickedTime!.hour, _pickedTime!.minute),
      );
    }

    setState(() {
      _titleController.clear();
      _pickedTime = null;
      _selectedDays = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder added')));
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
      final timeStr = (reminder['time'] ?? '').toString();
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder deleted")));
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _pickedTime == null ? "No time selected" : "Time: ${_pickedTime!.format(context)}";

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications & Reminders")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ===== Expiry Alerts =====
          const Text("⚠️ Expiry Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (_expiryAlerts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text("No expiry alerts yet."),
            )
          else
            Column(
              children: _expiryAlerts.map((a) {
                final med = (a["medicine"] ?? "Medicine").toString();
                final expiryIso = (a["expiryIso"] ?? "").toString();
                final expiry = DateTime.tryParse(expiryIso);
                final color = expiry != null ? _expiryColor(expiry) : Colors.grey;
                final dateLabel = expiry != null ? _fmtDate(expiry) : "(unknown)";
                final daysLabel = _daysLeftLabel(expiry);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: color, width: 6), top: BorderSide(color: Colors.grey.shade300), right: BorderSide(color: Colors.grey.shade300), bottom: BorderSide(color: Colors.grey.shade300)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: color, size: 28),
                    title: Text(med, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text("Expires: $dateLabel • $daysLabel"),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const SizedBox(height: 12),

          // ===== Add Reminder =====
          const Text("Medication Reminders", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              final label = _weekdayLabels[i];
              final dayNum = i + 1; // 1..7
              final selected = _selectedDays.contains(dayNum);
              return ChoiceChip(
                label: Text(label),
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

          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const SizedBox(height: 12),

          // ===== Existing Reminders =====
          const Text("Your Reminders", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                final days = ((r['days'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
                final daysLabel = days.isEmpty ? "No days" : days.map((d) => _weekdayLabels[d - 1]).join(", ");
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
