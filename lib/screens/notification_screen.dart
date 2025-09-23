import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../screens/services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  final _titleController = TextEditingController();
  TimeOfDay? _pickedTime;
  // 1=Mon..7=Sun
  List<int> _selectedDays = [];
  List<Map<String, dynamic>> _reminders = [];

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  StreamSubscription<DatabaseEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _listenReminders();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _listenReminders() {
    final user = _auth.currentUser;
    if (user == null) return;

    _sub?.cancel();
    _sub = _db.child("users/${user.uid}/reminders").onValue.listen((event) {
      if (!mounted) return;

      if (!event.snapshot.exists) {
        setState(() => _reminders = []);
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
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
          'time': (m['time'] ?? '').toString(),
          'days': days,
          'enabled': (m['enabled'] == true),
        });
      });

      setState(() => _reminders = list);
    });
  }

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
      "time":
      "${_pickedTime!.hour.toString().padLeft(2, '0')}:${_pickedTime!.minute.toString().padLeft(2, '0')}",
      "days": _selectedDays,
      "enabled": true,
    };

    final ref = _db.child("users/${user.uid}/reminders").push();
    await ref.set(reminder);

    // schedule now
    final baseId = ref.key!.hashCode;
    final now = DateTime.now();
    for (final d in _selectedDays) {
      await NotificationService.scheduleWeeklyNotification(
        id: baseId + d,
        title: "MediTrace Reminder",
        body: "Take your ${reminder['title']}",
        weekday: d,
        time: DateTime(now.year, now.month, now.day, _pickedTime!.hour, _pickedTime!.minute),
      );
    }

    // reset inputs
    setState(() {
      _titleController.clear();
      _pickedTime = null;
      _selectedDays = [];
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
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Reminder deleted")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel =
    _pickedTime == null ? "No time selected" : "Time: ${_pickedTime!.format(context)}";

    return Scaffold(
      appBar: AppBar(title: const Text("Medication Reminders")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              final dayNum = i + 1;
              final selected = _selectedDays.contains(dayNum);
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      if (!_selectedDays.contains(dayNum)) {
                        _selectedDays.add(dayNum);
                      }
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
          const Divider(thickness: 2, height: 32),

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
                final days = ((r['days'] as List?) ?? const [])
                    .map((e) => (e as num).toInt()).toList();
                final daysLabel =
                days.isEmpty ? "No days" : days.map((d) => _weekdayLabels[d - 1]).join(", ");
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
