import 'package:flutter/material.dart';
import 'package:vaccine_care/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageVaccinationsPage extends StatefulWidget {
  const ManageVaccinationsPage({super.key});

  @override
  State<ManageVaccinationsPage> createState() => _ManageVaccinationsPageState();
}

class _ManageVaccinationsPageState extends State<ManageVaccinationsPage> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('healthcareProviderEmail', isEqualTo: currentUser!.email)
          .get();

      final List<Map<String, dynamic>> schedules = [];

      for (final doc in querySnapshot.docs) {
        final patient = doc.data();
        final savedSchedules = patient['vaccinationSchedules'] as List<dynamic>? ?? [];

        for (int i = 0; i < savedSchedules.length; i++) {
          final schedule = savedSchedules[i];
          schedules.add({
            'patientId': doc.id,
            'scheduleIndex': i,
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

      // Sort by date and status (pending first)
      schedules.sort((a, b) {
        // First sort by status (Scheduled first, then others)
        if (a['status'] == 'Scheduled' && b['status'] != 'Scheduled') return -1;
        if (a['status'] != 'Scheduled' && b['status'] == 'Scheduled') return 1;

        // Then sort by date
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
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _updateVaccinationStatus(
    String patientId,
    int scheduleIndex,
    String newStatus,
  ) async {
    try {
      // Get the patient document
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get();

      if (!patientDoc.exists) {
        throw 'Patient not found';
      }

      final patientData = patientDoc.data()!;
      final schedules = List<Map<String, dynamic>>.from(
        patientData['vaccinationSchedules'] ?? []
      );

      if (scheduleIndex >= 0 && scheduleIndex < schedules.length) {
        // Update the status
        schedules[scheduleIndex]['status'] = newStatus;

        // Update the document
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .update({
          'vaccinationSchedules': schedules,
        });

        // Refresh the list
        await _loadSchedules();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vaccination marked as $newStatus'),
              backgroundColor: newStatus == 'Completed' ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  void _showStatusUpdateDialog(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Vaccination Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${schedule['childName']}'),
            Text('Vaccine: ${schedule['vaccine']}'),
            Text('Date: ${schedule['date']} at ${schedule['time']}'),
            const SizedBox(height: 16),
            const Text('Mark as:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateVaccinationStatus(
                schedule['patientId'],
                schedule['scheduleIndex'],
                'Completed',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Completed'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateVaccinationStatus(
                schedule['patientId'],
                schedule['scheduleIndex'],
                'Missed',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Missed'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Missed':
        return Colors.red;
      case 'Scheduled':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Vaccinations'),
        backgroundColor: Colors.blue.shade600,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
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
                      final isActionable = schedule['status'] == 'Scheduled';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: isActionable
                              ? () => _showStatusUpdateDialog(schedule)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with patient info and status
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: _getStatusColor(schedule['status']).withValues(alpha: 0.1),
                                      child: Icon(
                                        schedule['status'] == 'Completed'
                                            ? Icons.check_circle
                                            : schedule['status'] == 'Missed'
                                                ? Icons.cancel
                                                : Icons.schedule,
                                        color: _getStatusColor(schedule['status']),
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
                                        color: _getStatusColor(schedule['status']).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        schedule['status'],
                                        style: TextStyle(
                                          color: _getStatusColor(schedule['status']),
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
                                if (isActionable) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateVaccinationStatus(
                                            schedule['patientId'],
                                            schedule['scheduleIndex'],
                                            'Completed',
                                          ),
                                          icon: const Icon(Icons.check_circle),
                                          label: const Text('Mark Completed'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _updateVaccinationStatus(
                                            schedule['patientId'],
                                            schedule['scheduleIndex'],
                                            'Missed',
                                          ),
                                          icon: const Icon(Icons.cancel),
                                          label: const Text('Mark Missed'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
