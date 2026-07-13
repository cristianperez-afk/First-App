import 'package:flutter/material.dart';
import 'package:vaccine_care/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reminder_logic.dart';

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
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .get();

      final List<Map<String, dynamic>> schedules = [];

      for (final doc in querySnapshot.docs) {
        final patient = doc.data();
        final savedSchedules =
            patient['vaccinationSchedules'] as List<dynamic>? ?? [];

        for (final schedule in savedSchedules) {
          final reminderStatus = VaccinationReminderLogic.statusFor(schedule);
          final scheduledDate = VaccinationReminderLogic.parseDate(
            schedule['scheduledDate'],
          );
          final originalStatus = (schedule['status'] ?? '')
              .toString()
              .toLowerCase();

          schedules.add({
            'patientId': doc.id,
            'childName': patient['childName'],
            'parentName': patient['parentName'],
            'parentEmail': patient['email'],
            'vaccine': schedule['vaccineName'] ?? 'Unknown Vaccine',
            'date': scheduledDate != null
                ? scheduledDate.toString().split(' ')[0]
                : 'TBD',
            'time': scheduledDate != null ? _formatTime(scheduledDate) : 'TBD',
            'location': schedule['location'] ?? 'Clinic',
            'status': originalStatus == 'missed'
                ? 'Missed'
                : VaccinationReminderLogic.statusLabel(reminderStatus),
            'statusKey': reminderStatus.name,
            'notes': schedule['notes'] ?? '',
            'createdAt': schedule['createdAt'] ?? '',
            'scheduledDate': scheduledDate,
          });
        }
      }

      schedules.sort((a, b) {
        final aStatus = VaccinationReminderStatus.values.firstWhere(
          (status) => status.name == a['statusKey'],
          orElse: () => VaccinationReminderStatus.scheduled,
        );
        final bStatus = VaccinationReminderStatus.values.firstWhere(
          (status) => status.name == b['statusKey'],
          orElse: () => VaccinationReminderStatus.scheduled,
        );

        final priorityComparison = VaccinationReminderLogic.sortPriority(
          aStatus,
        ).compareTo(VaccinationReminderLogic.sortPriority(bStatus));
        if (priorityComparison != 0) {
          return priorityComparison;
        }

        final aDate = a['scheduledDate'] as DateTime?;
        final bDate = b['scheduledDate'] as DateTime?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading schedules: $e')));
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Vaccination Schedules', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
          ? const Center(child: Text('No vaccination schedules found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top Section (Patient Info)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  schedule['childName']?.toString()[0].toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schedule['childName'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Parent: ${schedule['parentName'] ?? ''}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(schedule['status']).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    schedule['status'],
                                    style: TextStyle(
                                      color: _getStatusColor(schedule['status']),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Dashed Divider
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC), 
                              borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(builder: (context, constraints) {
                              return Flex(
                                direction: Axis.horizontal,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: List.generate(
                                  (constraints.constrainWidth() / 8).floor(),
                                  (index) => Container(width: 4, height: 1, color: Colors.grey[300]),
                                ),
                              );
                            }),
                          ),
                          Container(
                            width: 16,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                            ),
                          ),
                        ],
                      ),

                      // Bottom Section (Vaccine Details)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('VACCINE', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      const SizedBox(height: 4),
                                      Text(
                                        schedule['vaccine'] ?? 'None',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('DATE & TIME', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${schedule['date']} • ${schedule['time']}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    schedule['location'] ?? 'Clinic',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (schedule['notes'].isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Notes: ${schedule['notes']}',
                                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'due today':
        return Colors.deepOrange;
      case 'overdue':
        return Colors.red;
      case 'upcoming':
        return Colors.amber;
      case 'scheduled':
      default:
        return Colors.blueGrey;
    }
  }
}
