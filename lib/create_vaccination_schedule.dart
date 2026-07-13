import 'package:flutter/material.dart';
import 'package:vaccine_care/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reminder_logic.dart';

class VaccinationSchedulePage extends StatefulWidget {
  const VaccinationSchedulePage({super.key});

  @override
  State<VaccinationSchedulePage> createState() =>
      _VaccinationSchedulePageState();
}

class _VaccinationSchedulePageState extends State<VaccinationSchedulePage> {
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    if (currentUser == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    setState(() => _loading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('patients')
          .get();

      setState(() {
        _patients = snapshot.docs.map((doc) {
          final data = doc.data();
          return {...data, 'id': doc.id};
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Get schedules for current healthcare provider's patients
    final schedules = _patients;

    return Scaffold(
      appBar: AppBar(title: const Text('Vaccination Schedules'), elevation: 0),
      body: Column(
        children: [
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Schedules',
                    '${schedules.length}',
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'This Week',
                    '${schedules.where((s) => s['nextDue'] != null && _isThisWeek(s['nextDue'])).length}',
                    Icons.event,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // Scheduled Vaccinations List
          Expanded(
            child: schedules.isEmpty
                ? const Center(child: Text('No vaccination schedules found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final patient = schedules[index];
                      return _buildScheduleCard(
                        childName: patient['childName'] ?? 'Unknown',
                        vaccine: patient['nextVaccine'] ?? 'Not scheduled',
                        date: patient['nextDue'] ?? 'TBD',
                        time: '9:00 AM', // Default time
                        status: patient['status'] == 'New Patient'
                            ? 'Upcoming'
                            : 'Completed',
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateVaccinationSchedulePage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'CREATE SCHEDULE',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard({
    required String childName,
    required String vaccine,
    required String date,
    required String time,
    required String status,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'upcoming':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        childName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.vaccines_rounded, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              vaccine,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildInfoItem(Icons.calendar_today_rounded, date),
                const SizedBox(width: 24),
                _buildInfoItem(Icons.access_time_rounded, time),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  bool _isThisWeek(String? dateString) {
    if (dateString == null) return false;
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          date.isBefore(endOfWeek.add(const Duration(days: 1)));
    } catch (e) {
      return false;
    }
  }
}

class CreateVaccinationSchedulePage extends StatefulWidget {
  const CreateVaccinationSchedulePage({super.key});

  @override
  State<CreateVaccinationSchedulePage> createState() =>
      _CreateVaccinationSchedulePageState();
}

class _CreateVaccinationSchedulePageState
    extends State<CreateVaccinationSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _selectedPatientIds = [];
  final List<VaccineScheduleItem> _vaccineSchedules = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _patients = [];
  bool _loadingPatients = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    if (currentUser == null) return;

    setState(() => _loadingPatients = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('patients')
          .get();

      setState(() {
        _patients = snapshot.docs.map((doc) {
          final data = doc.data();
          return {...data, 'id': doc.id};
        }).toList();
        _loadingPatients = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPatients = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Vaccination Schedule'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Schedule Vaccinations',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create vaccination schedule for a child',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 32),

                      // Patient Selection
                      _buildSectionHeader(
                        'Select Patients',
                        'Assign these vaccinations to one or more children.',
                      ),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _loadingPatients
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Loading patients...'),
                                  ],
                                ),
                              )
                            : _patients.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: Text('No patients found')),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _patients.length,
                                itemBuilder: (context, index) {
                                  final patient = _patients[index];
                                  final isSelected = _selectedPatientIds
                                      .contains(patient['id']);
                                  return CheckboxListTile(
                                    title: Text(
                                      '${patient['childName']} (${patient['parentName']})',
                                    ),
                                    subtitle: Text(
                                      'Age: ${patient['age'] ?? 'N/A'}',
                                    ),
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedPatientIds.add(
                                            patient['id'],
                                          );
                                        } else {
                                          _selectedPatientIds.remove(
                                            patient['id'],
                                          );
                                        }
                                      });
                                    },
                                    dense: true,
                                  );
                                },
                              ),
                      ),
                      if (_selectedPatientIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${_selectedPatientIds.length} patient(s) selected',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),

                      // Vaccine Schedules Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Vaccine Schedules',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addVaccineSchedule,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add Vaccine'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // List of Vaccine Schedules
                      if (_vaccineSchedules.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.none),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.vaccines_rounded,
                                    size: 40,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Vaccines Added',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add at least one vaccine to the schedule',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                TextButton.icon(
                                  onPressed: _addVaccineSchedule,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text(
                                    'ADD FIRST VACCINE',
                                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF3B82F6),
                                    backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._vaccineSchedules.asMap().entries.map((entry) {
                          final index = entry.key;
                          final schedule = entry.value;
                          return _buildVaccineScheduleCard(schedule, index);
                        }),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSchedule,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Schedule',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaccineScheduleCard(VaccineScheduleItem schedule, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'VACCINE ${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _editVaccineSchedule(index),
                  icon: const Icon(Icons.edit_note_rounded, size: 22),
                  color: const Color(0xFF64748B),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => _removeVaccineSchedule(index),
                  icon: const Icon(Icons.delete_outline_rounded, size: 22),
                  color: Colors.redAccent,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.vaccines_rounded, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        schedule.vaccineName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildItemInfo(Icons.calendar_today_rounded, 
                      '${schedule.scheduledDate.toLocal()}'.split(' ')[0]),
                    const SizedBox(width: 24),
                    _buildItemInfo(Icons.access_time_rounded, 
                      '${schedule.scheduledDate.hour.toString().padLeft(2, '0')}:${schedule.scheduledDate.minute.toString().padLeft(2, '0')}'),
                  ],
                ),
                if (schedule.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            schedule.notes,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF3B82F6),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _addVaccineSchedule() {
    showDialog(
      context: context,
      builder: (context) => VaccineScheduleDialog(
        onSave: (schedule) {
          setState(() {
            _vaccineSchedules.add(schedule);
          });
        },
      ),
    );
  }

  void _editVaccineSchedule(int index) {
    showDialog(
      context: context,
      builder: (context) => VaccineScheduleDialog(
        initialSchedule: _vaccineSchedules[index],
        onSave: (schedule) {
          setState(() {
            _vaccineSchedules[index] = schedule;
          });
        },
      ),
    );
  }

  void _removeVaccineSchedule(int index) {
    setState(() {
      _vaccineSchedules.removeAt(index);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vaccine removed')));
  }

  Future<void> _saveSchedule() async {
    if (_selectedPatientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one patient')),
      );
      return;
    }

    if (_vaccineSchedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one vaccine')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save vaccination schedules for each selected patient
      final vaccinationSchedules = _vaccineSchedules
          .map(
            (schedule) => {
              'vaccineName': schedule.vaccineName,
              'scheduledDate': schedule.scheduledDate.toIso8601String(),
              'notes': schedule.notes,
              'location': schedule.location,
              'status': 'Scheduled',
              'doseIntervalDays':
                  VaccinationReminderLogic.defaultDoseIntervalDays(
                    schedule.vaccineName,
                  ),
              'reminderLeadDays': 3,
              'createdAt': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      // Update each selected patient
      for (final patientId in _selectedPatientIds) {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .update({
              'vaccinationSchedules': FieldValue.arrayUnion(
                vaccinationSchedules,
              ),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // Update next vaccine info for dashboard display
        if (_vaccineSchedules.isNotEmpty) {
          final nextSchedule = _vaccineSchedules.reduce(
            (a, b) => a.scheduledDate.isBefore(b.scheduledDate) ? a : b,
          );
          final nextIntervalDays =
              VaccinationReminderLogic.defaultDoseIntervalDays(
                nextSchedule.vaccineName,
              );
          final followUpDate = nextIntervalDays > 0
              ? nextSchedule.scheduledDate.add(Duration(days: nextIntervalDays))
              : null;
          await FirebaseFirestore.instance
              .collection('patients')
              .doc(patientId)
              .update({
                'nextVaccine': nextSchedule.vaccineName,
                'nextDue': nextSchedule.scheduledDate.toIso8601String().split(
                  'T',
                )[0],
                'nextLocation': nextSchedule.location,
                'nextDoseIntervalDays': nextIntervalDays,
                if (followUpDate != null)
                  'nextFollowUpDue': followUpDate.toIso8601String().split(
                    'T',
                  )[0],
              });
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vaccination schedule created successfully for ${_selectedPatientIds.length} patient(s)!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vaccination schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Vaccine Schedule Dialog
class VaccineScheduleDialog extends StatefulWidget {
  final VaccineScheduleItem? initialSchedule;
  final String? initialVaccineName;
  final Function(VaccineScheduleItem) onSave;

  const VaccineScheduleDialog({
    super.key,
    this.initialSchedule,
    this.initialVaccineName,
    required this.onSave,
  });

  @override
  State<VaccineScheduleDialog> createState() => _VaccineScheduleDialogState();
}

class _VaccineScheduleDialogState extends State<VaccineScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _vaccineName;
  late DateTime _scheduledDate;
  late String _notes;
  late String _location;

  final List<String> _vaccines = [
    'MMR (Measles, Mumps, Rubella)',
    'DTaP (Diphtheria, Tetanus, Pertussis)',
    'Polio (IPV)',
    'Hepatitis B',
    'Hib (Haemophilus influenzae type b)',
    'Varicella (Chickenpox)',
    'PCV13 (Pneumococcal)',
    'Rotavirus',
    'Hepatitis A',
    'Meningococcal',
    'HPV (Human Papillomavirus)',
    'Influenza (Flu)',
    'COVID-19',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _vaccineName =
        widget.initialSchedule?.vaccineName ??
        widget.initialVaccineName ??
        _vaccines.first;
    _scheduledDate = widget.initialSchedule?.scheduledDate ?? DateTime.now();
    _notes = widget.initialSchedule?.notes ?? '';
    _location = widget.initialSchedule?.location ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialSchedule == null ? 'Add Vaccine' : 'Edit Vaccine',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vaccine Name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _vaccineName,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _vaccines.map((vaccine) {
                  return DropdownMenuItem(
                    value: vaccine,
                    child: Text(
                      vaccine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                selectedItemBuilder: (context) {
                  return _vaccines.map((vaccine) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        vaccine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList();
                },
                onChanged: (value) {
                  setState(() {
                    _vaccineName = value!;
                  });
                },
                onSaved: (value) {
                  _vaccineName = value!;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Scheduled Date & Time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduledDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null && mounted) {
                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_scheduledDate),
                    );
                    if (time != null) {
                      setState(() {
                        _scheduledDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Text('${_scheduledDate.toLocal()}'.split('.')[0]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Notes (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Additional notes...',
                ),
                onChanged: (value) {
                  _notes = value;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _location,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Clinic name, hospital, or location...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
                onChanged: (value) {
                  _location = value;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(
                VaccineScheduleItem(
                  vaccineName: _vaccineName,
                  scheduledDate: _scheduledDate,
                  notes: _notes,
                  location: _location,
                ),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Data Model
class VaccineScheduleItem {
  final String vaccineName;
  final DateTime scheduledDate;
  final String notes;
  final String location;

  VaccineScheduleItem({
    required this.vaccineName,
    required this.scheduledDate,
    required this.notes,
    required this.location,
  });
}
