import 'package:flutter/material.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class ParentScheduleTab extends StatefulWidget {
  const ParentScheduleTab({super.key});

  @override
  State<ParentScheduleTab> createState() => _ParentScheduleTabState();
}

class _ParentScheduleTabState extends State<ParentScheduleTab> {
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _vaccinations = [];
  bool _isLoading = true;
  bool _vaccinationReminders = true;
  int _reminderDays = 3;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndVaccinations();
  }

  Future<void> _loadSettingsAndVaccinations() async {
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // Load notification settings
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.email)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        _vaccinationReminders = data['vaccinationReminders'] ?? true;
        _reminderDays = data['reminderDays'] ?? 3;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('email', isEqualTo: currentUser!.email)
          .get();

      final List<Map<String, dynamic>> vaccinations = [];

      for (final doc in querySnapshot.docs) {
        final patient = doc.data();
        final savedSchedules = patient['vaccinationSchedules'] as List<dynamic>? ?? [];

        for (final schedule in savedSchedules) {
          final scheduledDate = schedule['scheduledDate'] != null
              ? DateTime.parse(schedule['scheduledDate']).toLocal()
              : null;
          vaccinations.add({
            'childName': patient['childName'],
            'vaccine': schedule['vaccineName'] ?? 'Unknown Vaccine',
            'date': scheduledDate != null
                ? scheduledDate.toString().split(' ')[0]
                : 'TBD',
            'time': scheduledDate != null
                ? _formatTime(scheduledDate)
                : 'TBD',
            'provider': 'Healthcare Provider',
            'location': schedule['location'] ?? 'Clinic',
            'status': schedule['status'] ?? 'Scheduled',
            'type': schedule['status'] == 'Completed' ? 'completed' : 'upcoming',
            'notes': schedule['notes'] ?? '',
            'scheduledDate': scheduledDate,
          });

          // Schedule notification if reminders are enabled
          if (_vaccinationReminders && scheduledDate != null && schedule['status'] != 'Completed') {
            final notificationId = '${doc.id}_${schedule['vaccineName']}_${scheduledDate.millisecondsSinceEpoch}'.hashCode.abs();
            await NotificationService.scheduleVaccinationReminder(
              id: notificationId,
              title: 'Vaccination Reminder',
              body: '${patient['childName']} has a ${schedule['vaccineName']} scheduled for ${scheduledDate.toString().split(' ')[0]} at ${schedule['location'] ?? 'Clinic'}',
              scheduledTime: scheduledDate,
              daysBefore: _reminderDays,
            );
          }
        }

        // If no schedules, add basic info
        if (savedSchedules.isEmpty) {
          vaccinations.add({
            'childName': patient['childName'],
            'vaccine': patient['nextVaccine'] ?? 'Initial Assessment',
            'date': patient['nextDue'] ?? 'TBD',
            'time': '9:00 AM',
            'provider': 'Healthcare Provider',
            'location': patient['nextLocation'] ?? 'Clinic',
            'status': patient['status'] == 'New Patient' ? 'Scheduled' : 'Completed',
            'type': patient['status'] == 'New Patient' ? 'upcoming' : 'completed',
            'notes': 'Please bring vaccination card',
          });
        }
      }

      setState(() {
        _vaccinations = vaccinations;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vaccinations: $e')),
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

  // Dynamic vaccination schedule data based on parent's children
  List<Map<String, dynamic>> get vaccinations => _vaccinations;

  List<Map<String, dynamic>> get filteredVaccinations {
    return vaccinations.where((vac) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Upcoming') return vac['type'] == 'upcoming';
      if (_selectedFilter == 'Completed') return vac['type'] == 'completed';
      if (_selectedFilter == 'Pending') return vac['type'] == 'pending';
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vaccination Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track and manage your children\'s vaccinations',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Quick Stats
              /*  Row(
                  children: [
                    Expanded(
                      child: _buildHeaderStatCard(
                        '0',
                        'Upcoming',
                        Icons.event,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHeaderStatCard(
                        '0',
                        'Completed',
                        Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHeaderStatCard(
                        '0',
                        'Pending',
                        Icons.schedule,
                      ),
                    ),
                  ],
                ),*/
              ],
            ),
          ),

          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', vaccinations.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Upcoming',
                    vaccinations.where((v) => v['type'] == 'upcoming').length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Completed',
                    vaccinations.where((v) => v['type'] == 'completed').length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Pending',
                    vaccinations.where((v) => v['type'] == 'pending').length,
                  ),
                ],
              ),
            ),
          ),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredVaccinations.length} Record${filteredVaccinations.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Vaccinations List
          Expanded(
            child: filteredVaccinations.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredVaccinations.length,
                    itemBuilder: (context, index) {
                      final vaccination = filteredVaccinations[index];
                      return _buildVaccinationCard(vaccination);
                    },
                  ),
          ),
        ],
      ),
    );
  }

 /* Widget _buildHeaderStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }*/

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildVaccinationCard(Map<String, dynamic> vaccination) {
    Color statusColor;
    IconData statusIcon;

    switch (vaccination['type']) {
      case 'upcoming':
        statusColor = Colors.blue;
        statusIcon = Icons.event;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          _showVaccinationDetails(vaccination);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vaccination['vaccine'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              vaccination['childName'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      vaccination['status'],
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          vaccination['date'],
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          vaccination['time'],
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              if (vaccination['type'] == 'upcoming') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    
                  ],
                ),
              ],
              if (vaccination['type'] == 'pending') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showScheduleDialog(vaccination);
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Schedule Appointment'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No vaccinations found',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing the filter',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showVaccinationDetails(Map<String, dynamic> vaccination) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                vaccination['vaccine'],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                vaccination['childName'],
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Status', vaccination['status']),
              _buildDetailRow('Date', vaccination['date']),
              _buildDetailRow('Time', vaccination['time']),
              _buildDetailRow('Provider', vaccination['provider']),
              _buildDetailRow('Location', vaccination['location']),
              _buildDetailRow('Notes', vaccination['notes']),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showScheduleDialog(Map<String, dynamic> vaccination) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Appointment'),
        content: Text(
          'Schedule ${vaccination['vaccine']} for ${vaccination['childName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening appointment scheduler...')),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
