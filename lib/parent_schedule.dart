import 'package:flutter/material.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reminder_logic.dart';

class ParentScheduleTab extends StatefulWidget {
  const ParentScheduleTab({super.key});

  @override
  State<ParentScheduleTab> createState() => _ParentScheduleTabState();
}

class _ParentScheduleTabState extends State<ParentScheduleTab> {
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _vaccinations = [];
  bool _isLoading = true;
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
        _reminderDays = data['reminderDays'] ?? 3;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('email', isEqualTo: currentUser!.email)
          .get();

      final List<Map<String, dynamic>> vaccinations = [];

      for (final doc in querySnapshot.docs) {
        final patient = doc.data();
        final savedSchedules =
            patient['vaccinationSchedules'] as List<dynamic>? ?? [];

        for (final schedule in savedSchedules) {
          final reminderStatus = VaccinationReminderLogic.statusFor(
            schedule,
            reminderDays: _reminderDays,
          );
          final scheduledDate = VaccinationReminderLogic.parseDate(
            schedule['scheduledDate'],
          );
          final originalStatus = (schedule['status'] ?? '')
              .toString()
              .toLowerCase();

          vaccinations.add({
            'childName': patient['childName'],
            'vaccine': schedule['vaccineName'] ?? 'Unknown Vaccine',
            'date': scheduledDate != null
                ? scheduledDate.toString().split(' ')[0]
                : 'TBD',
            'time': scheduledDate != null ? _formatTime(scheduledDate) : 'TBD',
            'provider': 'Healthcare Provider',
            'location': schedule['location'] ?? 'Clinic',
            'status': originalStatus == 'missed'
                ? 'Missed'
                : VaccinationReminderLogic.statusLabel(reminderStatus),
            'statusKey': reminderStatus.name,
            'notes': schedule['notes'] ?? '',
            'scheduledDate': scheduledDate,
            'leadDays': _reminderDays,
          });
        }

        // If no schedules, add basic info
        if (savedSchedules.isEmpty) {
          final fallbackDueDate = VaccinationReminderLogic.parseDate(
            patient['nextDue'],
          );
          final fallbackStatus = VaccinationReminderLogic.statusFor({
            'scheduledDate': fallbackDueDate?.toIso8601String(),
            'status': patient['status'],
          }, reminderDays: _reminderDays);
          vaccinations.add({
            'childName': patient['childName'],
            'vaccine': patient['nextVaccine'] ?? 'Initial Assessment',
            'date': patient['nextDue'] ?? 'TBD',
            'time': '9:00 AM',
            'provider': 'Healthcare Provider',
            'location': patient['nextLocation'] ?? 'Clinic',
            'status': VaccinationReminderLogic.statusLabel(fallbackStatus),
            'statusKey': fallbackStatus.name,
            'notes': 'Please bring vaccination card',
            'scheduledDate': fallbackDueDate,
            'leadDays': _reminderDays,
          });
        }
      }

      vaccinations.sort((a, b) {
        final aStatus = VaccinationReminderStatus.values.firstWhere(
          (status) => status.name == a['statusKey'],
          orElse: () => VaccinationReminderStatus.scheduled,
        );
        final bStatus = VaccinationReminderStatus.values.firstWhere(
          (status) => status.name == b['statusKey'],
          orElse: () => VaccinationReminderStatus.scheduled,
        );

        final statusComparison = VaccinationReminderLogic.sortPriority(
          aStatus,
        ).compareTo(VaccinationReminderLogic.sortPriority(bStatus));

        if (statusComparison != 0) {
          return statusComparison;
        }

        final aDate = a['scheduledDate'] as DateTime?;
        final bDate = b['scheduledDate'] as DateTime?;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return aDate.compareTo(bDate);
      });

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
      if (_selectedFilter == 'All') {
        return true;
      }
      if (_selectedFilter == 'Upcoming') {
        return vac['statusKey'] == 'upcoming';
      }
      if (_selectedFilter == 'Due Today') {
        return vac['statusKey'] == 'dueToday';
      }
      if (_selectedFilter == 'Overdue') {
        return vac['statusKey'] == 'overdue';
      }
      if (_selectedFilter == 'Completed') {
        return vac['statusKey'] == 'completed';
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    return SafeArea(
      child: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      // Normally back, but this is a tab so maybe just do nothing or icon
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const Text(
                  'Schedules',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _buildFilterChip('All', vaccinations.length),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    'Upcoming',
                    vaccinations
                        .where((v) => v['statusKey'] == 'upcoming')
                        .length,
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    'Due Today',
                    vaccinations
                        .where((v) => v['statusKey'] == 'dueToday')
                        .length,
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    'Overdue',
                    vaccinations
                        .where((v) => v['statusKey'] == 'overdue')
                        .length,
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    'Completed',
                    vaccinations
                        .where((v) => v['statusKey'] == 'completed')
                        .length,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

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

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildVaccinationCard(Map<String, dynamic> vaccination) {
    final childName = vaccination['childName']?.toString() ?? '';
    final vaccineName = vaccination['vaccine']?.toString() ?? '';
    final dateText = vaccination['date']?.toString() ?? 'TBD';
    final timeText = vaccination['time']?.toString() ?? 'TBD';
    final location = vaccination['location']?.toString() ?? 'Clinic';
    final status = vaccination['status']?.toString() ?? 'Scheduled';

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
          // Card Header: Patient & Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    childName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                _buildStatusPill(status),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          
          // Card Body: Vaccination Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vaccineName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B82F6),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildRecordItem(Icons.calendar_today_outlined, 'Date', dateText),
                    ),
                    Expanded(
                      child: _buildRecordItem(Icons.access_time, 'Time', timeText),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecordItem(Icons.location_on_outlined, 'Location', location),
              ],
            ),
          ),

          // Card Footer: Action
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: TextButton(
              onPressed: () => _showVaccinationDetails(vaccination),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Full Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16, color: Color(0xFF1E293B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        break;
      case 'overdue':
      case 'missed':
        color = Colors.red;
        break;
      case 'due today':
        color = Colors.orange;
        break;
      default:
        color = const Color(0xFF3B82F6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRecordItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
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
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
