import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool vaccinationReminders = true;
  bool appointmentUpdates = true;
  bool healthTips = false;
  bool emergencyAlerts = true; // always on

  int reminderDays = 3;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.email)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          vaccinationReminders = data['vaccinationReminders'] ?? true;
          appointmentUpdates = data['appointmentUpdates'] ?? true;
          healthTips = data['healthTips'] ?? false;
          reminderDays = data['reminderDays'] ?? 3;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.email)
          .update({
            'vaccinationReminders': vaccinationReminders,
            'appointmentUpdates': appointmentUpdates,
            'healthTips': healthTips,
            'reminderDays': reminderDays,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save settings')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildSwitch(
            title: 'Vaccination Reminders',
            subtitle: 'Get notified before vaccination dates',
            value: vaccinationReminders,
            onChanged: (val) => setState(() => vaccinationReminders = val),
          ),

          if (vaccinationReminders) _buildReminderOptions(),

          _buildSwitch(
            title: 'Appointment Updates',
            subtitle: 'Confirmations and changes',
            value: appointmentUpdates,
            onChanged: (val) => setState(() => appointmentUpdates = val),
          ),

          _buildSwitch(
            title: 'Health Tips',
            subtitle: 'Post-vaccination care tips',
            value: healthTips,
            onChanged: (val) => setState(() => healthTips = val),
          ),

          _buildSwitch(
            title: 'Emergency Alerts',
            subtitle: 'Critical health alerts (always enabled)',
            value: emergencyAlerts,
            onChanged: null,
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saveSettings,
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
  Widget _buildReminderOptions() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reminder Timing',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: reminderDays,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notify me before',
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 day before')),
                DropdownMenuItem(value: 3, child: Text('3 days before')),
                DropdownMenuItem(value: 7, child: Text('7 days before')),
              ],
              onChanged: (value) =>
                  setState(() => reminderDays = value ?? 3),
              onSaved: (value) =>
                  reminderDays = value ?? 3,
            ),
          ],
        ),
      ),
    );
  }
}
