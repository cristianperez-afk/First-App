import 'package:flutter/material.dart';
import 'package:vaccine_care/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reminder_logic.dart';

class ManageVaccinationsPage extends StatefulWidget {
  const ManageVaccinationsPage({super.key});

  @override
  State<ManageVaccinationsPage> createState() => _ManageVaccinationsPageState();
}

class _ManageVaccinationsPageState extends State<ManageVaccinationsPage> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _quickFilters = const [
    {'label': 'All', 'icon': Icons.apps},
    {'label': 'Completed', 'icon': Icons.check_circle},
    {'label': 'Missed', 'icon': Icons.cancel},
    {'label': 'Due Today', 'icon': Icons.today},
    {'label': 'Upcoming', 'icon': Icons.schedule},
  ];

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

        for (int i = 0; i < savedSchedules.length; i++) {
          final schedule = savedSchedules[i];
          final reminderStatus = VaccinationReminderLogic.statusFor(schedule);
          final scheduledDate = VaccinationReminderLogic.parseDate(
            schedule['scheduledDate'],
          );
          final originalStatus = (schedule['status'] ?? '')
              .toString()
              .toLowerCase();

          schedules.add({
            'patientId': doc.id,
            'scheduleIndex': i,
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
            'isActionable':
                originalStatus != 'completed' && originalStatus != 'missed',
            'notes': schedule['notes'] ?? '',
            'createdAt': schedule['createdAt'] ?? '',
            'scheduledDate': scheduledDate,
          });
        }
      }

      // Sort by reminder urgency and date.
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
      final schedules =
          (patientData['vaccinationSchedules'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

      if (scheduleIndex >= 0 && scheduleIndex < schedules.length) {
        // Update the status
        schedules[scheduleIndex]['status'] = newStatus;
        if (newStatus == 'Completed') {
          schedules[scheduleIndex]['completedAt'] = DateTime.now()
              .toIso8601String();
        } else {
          schedules[scheduleIndex].remove('completedAt');
        }

        // Update the document
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .update({'vaccinationSchedules': schedules});

        // Refresh the list
        await _loadSchedules();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vaccination marked as $newStatus'),
              backgroundColor: newStatus == 'Completed'
                  ? Colors.green
                  : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'missed':
      case 'overdue':
        return Colors.red;
      case 'due today':
        return Colors.deepOrange;
      case 'upcoming':
        return Colors.amber;
      case 'scheduled':
      default:
        return Colors.blueGrey;
    }
  }

  List<Map<String, dynamic>> _getFilteredSchedules() {
    if (_selectedFilter == 'All') return _schedules;
    return _schedules.where((schedule) {
      final status = (schedule['status'] ?? '').toString().toLowerCase();
      return status == _selectedFilter.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSchedules = _getFilteredSchedules();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Vaccinations'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
        child: Column(
          children: [
            SizedBox(
              height: 74,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                scrollDirection: Axis.horizontal,
                itemCount: _quickFilters.length,
                itemBuilder: (context, index) {
                  final filter = _quickFilters[index];
                  final label = filter['label'] as String;
                  final icon = filter['icon'] as IconData;
                  final isSelected = _selectedFilter == label;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : Colors.blueGrey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(label),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedFilter = label);
                      },
                      selectedColor: Colors.blue.shade600,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? Colors.blue.shade600
                            : Colors.blueGrey.shade100,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredSchedules.isEmpty
                  ? Center(
                      child: Text(
                        _selectedFilter == 'All'
                            ? 'No vaccination schedules found'
                            : 'No $_selectedFilter records found',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredSchedules.length,
                      itemBuilder: (context, index) {
                        final schedule = filteredSchedules[index];
                        final isActionable = schedule['isActionable'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          schedule['childName']?.toString()[0].toUpperCase() ?? 'U',
                                          style: const TextStyle(
                                            color: Color(0xFF3B82F6),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            schedule['childName'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Parent: ${schedule['parentName'] ?? ''}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(schedule['status']).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        schedule['status'].toString().toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(schedule['status']),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'VACCINE',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xFF94A3B8),
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                schedule['vaccine'] ?? 'None',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF3B82F6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                'SCHEDULED DATE',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xFF94A3B8),
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${schedule['date']} • ${schedule['time']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Text(
                                          schedule['location'] ?? 'Clinic',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (schedule['notes'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Notes: ${schedule['notes']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (isActionable) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () => _updateVaccinationStatus(
                                                schedule['patientId'],
                                                schedule['scheduleIndex'],
                                                'Missed',
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red[400],
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: BorderSide(color: Colors.red[100]!),
                                                ),
                                              ),
                                              child: const Text(
                                                'Mark Missed',
                                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _updateVaccinationStatus(
                                                schedule['patientId'],
                                                schedule['scheduleIndex'],
                                                'Completed',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E293B),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text(
                                                'Mark Completed',
                                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                            ),
                                          ),
                                        ],
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
            ),
          ],
        ),
      ),
    );
  }
}
