import 'package:flutter/material.dart';
import 'package:vaccine_care/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewSchedulesPage extends StatefulWidget {
  const ViewSchedulesPage({super.key});

  @override
  State<ViewSchedulesPage> createState() => _ViewSchedulesPageState();
}

class _ViewSchedulesPageState extends State<ViewSchedulesPage> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    if (currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('healthcareProviderEmail', isEqualTo: currentUser!.email)
          .get();

      final List<Map<String, dynamic>> schedules = [];

      for (final doc in querySnapshot.docs) {
        final patient = doc.data();
        final savedSchedules = patient['vaccinationSchedules'] as List<dynamic>? ?? [];

        for (final schedule in savedSchedules) {
          schedules.add({
            'patientId': doc.id,
            'childName': patient['childName'],
            'parentName': patient['parentName'],
            'parentEmail': patient['email'],
            'vaccine': schedule['vaccineName'] ?? 'Unknown Vaccine',
            'date': schedule['scheduledDate'] != null
                ? DateTime.parse(schedule['scheduledDate']).toLocal().toString().split(' ')[0]
                : 'TBD',
            'time': schedule['scheduledDate'] != null
                ? _formatTime(DateTime.parse(schedule['scheduledDate']).toLocal())
                : 'TBD',
            'location': schedule['location'] ?? 'Clinic',
            'status': schedule['status'] ?? 'Scheduled',
            'notes': schedule['notes'] ?? '',
            'createdAt': schedule['createdAt'] ?? '',
          });
        }
      }

      // Sort by date
      schedules.sort((a, b) {
        if (a['date'] == 'TBD' && b['date'] == 'TBD') return 0;
        if (a['date'] == 'TBD') return 1;
        if (b['date'] == 'TBD') return -1;
        return a['date'].compareTo(b['date']);
      });

      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading schedules: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccination Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? const Center(
                  child: Text('No vaccination schedules found'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = _schedules[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with patient info
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                  child: Text(
                                    schedule['childName'][0].toUpperCase(),
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        schedule['childName'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Parent: ${schedule['parentName']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: schedule['status'] == 'Completed'
                                        ? Colors.green[100]
                                        : Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    schedule['status'],
                                    style: TextStyle(
                                      color: schedule['status'] == 'Completed'
                                          ? Colors.green[800]
                                          : Colors.orange[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Vaccine details
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.vaccines, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          schedule['vaccine'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[900],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${schedule['date']} at ${schedule['time']}',
                                              style: TextStyle(color: Colors.blue[800]),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              schedule['location'],
                                              style: TextStyle(color: Colors.blue[800]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (schedule['notes'].isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Notes: ${schedule['notes']}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}