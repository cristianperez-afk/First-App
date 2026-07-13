import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vaccine_care/main.dart';
import 'package:vaccine_care/patient.dart';
import 'package:vaccine_care/healthcare_profile.dart';
import 'package:vaccine_care/qr_code_scanner.dart';
import 'package:vaccine_care/view_rec.dart';
import 'package:vaccine_care/generate_report.dart';
import 'package:vaccine_care/add_patient.dart';
import 'package:vaccine_care/create_vaccination_schedule.dart';
import 'package:vaccine_care/head_rhu_dashboard.dart';
import 'view_schedules.dart';
import 'manage_vaccinations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ui_utils.dart';

class HealthcareProviderDashboard extends StatefulWidget {
  const HealthcareProviderDashboard({super.key});

  @override
  State<HealthcareProviderDashboard> createState() =>
      _HealthcareProviderDashboardState();
}

class _HealthcareProviderDashboardState
    extends State<HealthcareProviderDashboard> {
  int _selectedIndex = 0;
  int _totalPatients = 0;
  bool _isLoadingStats = true;
  int? _selectedQuickActionIndex;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .get();

      setState(() {
        _totalPatients = querySnapshot.docs.length;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() => _isLoadingStats = false);
    }
  }

  List<Map<String, dynamic>> get todaysAppointments {
    return globalPatients
        .where(
          (patient) => patient['healthcareProviderEmail'] == currentUser?.email,
        )
        .where((patient) {
          final nextDue = patient['nextDue'];
          if (nextDue == null) return false;
          final today = DateTime.now().toIso8601String().split('T')[0];
          return nextDue == today;
        })
        .map(
          (patient) => {
            'childName': patient['childName'],
            'parentName': patient['parentName'],
            'time': '9:00 AM',
            'vaccine': patient['nextVaccine'] ?? 'Not scheduled',
            'status': patient['status'] == 'New Patient'
                ? 'pending'
                : 'completed',
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          Container(color: const Color(0xFFF8FAFC)),
          Positioned(
            top: 200,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(child: _buildCurrentTab()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFF2196F3),
          unselectedItemColor: Colors.grey[400],
          elevation: 0,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Patients',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.vaccines_outlined),
              activeIcon: Icon(Icons.vaccines),
              label: 'Vaccinations',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            if (currentUser?.userType == 'head_of_rhu')
              const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings_outlined),
                activeIcon: Icon(Icons.admin_panel_settings),
                label: 'Approvals',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    if (_selectedIndex == 0) return _buildHomeTab();
    if (_selectedIndex == 1) return _buildPatientsTab();
    if (_selectedIndex == 2) return _buildVaccinationsTab();
    if (_selectedIndex == 3) return _buildProfileTab();
    if (_selectedIndex == 4 && currentUser?.userType == 'head_of_rhu') {
      return const HeadRhuDashboard();
    }
    return _buildHomeTab();
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Stack(
        children: [
          // Background Gradient Header
          ClinicalHeader(
            title: 'Dashboard',
            subtitle: currentUser?.fullName ?? 'Healthcare Provider',
            trailing: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          // Main Content overlapping
          Padding(
            padding: const EdgeInsets.only(top: 150, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Overview Card
                ClinicalCard(
                  child: Column(
                    children: [
                      // Top Row (Stats)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PATIENT DATABASE',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isLoadingStats ? '...' : '$_totalPatients Patients',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.assignment_ind_outlined,
                              color: Color(0xFF3B82F6),
                              size: 22,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'TODAY\'S SCHEDULE',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${todaysAppointments.length} Appts',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Color(0xFFF3F4F6)),
                      ),
                      // Middle Row (Action)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QUICK VALIDATION',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Row(
                                  children: [
                                    Text(
                                      'Scan Patient QR',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(
                                      Icons.qr_code_scanner_rounded,
                                      size: 18,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Black CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QRScannerPage(),
                              ),
                            );
                            if (result != null && mounted) {
                              _handleQRScanResult(result);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'OPEN SCANNER',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Quick Actions Label
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Actions Horizontal Scroll
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      _buildActionCard(
                        'View Schedules',
                        Icons.calendar_today_outlined,
                        const Color(0xFF3B82F6),
                        actionIndex: 0,
                      ),
                      const SizedBox(width: 10),
                      _buildActionCard(
                        'Schedule Vax',
                        Icons.vaccines_outlined,
                        const Color(0xFF3B82F6),
                        actionIndex: 1,
                      ),
                      const SizedBox(width: 10),
                      _buildActionCard(
                        'Add Patient',
                        Icons.person_add_outlined,
                        const Color(0xFF3B82F6),
                        actionIndex: 2,
                      ),
                      const SizedBox(width: 10),
                      _buildActionCard(
                        'Gen. Report',
                        Icons.assessment_outlined,
                        const Color(0xFF3B82F6),
                        actionIndex: 3,
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Today's Appointments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Today\'s Appointments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedIndex = 2),
                      child: const Text(
                        'View All',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Appointments List
                todaysAppointments.isEmpty
                    ? Center(
                        child: Text(
                          'No appointments scheduled for today',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todaysAppointments.length,
                        itemBuilder: (context, index) {
                          return _buildAppointmentCard(
                            todaysAppointments[index],
                          );
                        },
                      ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color, {
    required int actionIndex,
  }) {
    final isActive = _selectedQuickActionIndex == actionIndex;
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedQuickActionIndex = actionIndex);
        await Future.delayed(const Duration(milliseconds: 140));
        if (!mounted) return;

        if (label == 'View Records') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ViewRecordsPage()),
          );
        } else if (label == 'Scan QR Code') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QRScannerPage()),
          );
        } else if (label == 'Add Patient') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPatientPage()),
          );
        } else if (label == 'Gen. Report') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GenerateReportPage()),
          );
        } else if (label == 'Schedule Vax') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateVaccinationSchedulePage(),
            ),
          );
        } else if (label == 'View Schedules') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ViewSchedulesPage()),
          );
        }

        if (!mounted) return;
        setState(() => _selectedQuickActionIndex = null);
      },
      child: AnimatedScale(
        scale: isActive ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 128,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isActive ? color.withValues(alpha: 0.25) : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isActive ? 0.08 : 0.04),
                blurRadius: isActive ? 18 : 12,
                offset: Offset(0, isActive ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final status = appointment['status']?.toString() ?? 'pending';

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
          // Top portion: Patient info & Time
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['childName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Parent: ${appointment['parentName'] ?? 'Parent'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      appointment['time'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Time',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bottom portion: Vaccine & Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VACCINE TYPE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment['vaccine'] ?? 'None',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(status),
              ],
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
      case 'pending':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
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

  Widget _buildPatientsTab() {
    return const PatientsTab();
  }

  Widget _buildVaccinationsTab() {
    return const ManageVaccinationsPage();
  }

  Widget _buildProfileTab() {
    return const ProfileTab();
  }

  void _handleQRScanResult(String result) {
    if (result.startsWith('PATIENT:')) {
      final patientId = result.substring(8);
      _showPatientLookupDialog(patientId);
    } else if (result.startsWith('VACCINE:')) {
      final vaccineData = result.substring(8);
      _showVaccineRecordDialog(vaccineData);
    } else {
      // Try to parse as JSON (which is what parent_qr_code generates)
      try {
        final Map<String, dynamic> patientData = jsonDecode(result);
        if (patientData.containsKey('childName')) {
          _showOfficialIdDialog(patientData);
          return;
        }
      } catch (e) {
        // Not a JSON or invalid format, fallback to standard dialog
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('QR Code Scanned'),
          content: Text('Scanned data: $result'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showOfficialIdDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(
              0xFFF9F9F9,
            ), // Slight off-white for document paper feel
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Watermark
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: Icon(
                    Icons.health_and_safety,
                    size: 200,
                    color: Colors.blue[900],
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified,
                            color: Colors.blue[800],
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'OFFICIAL VACCINATION RECORD',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 28), // balance the icon
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Department of Health Guidelines',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Divider(thickness: 2, height: 24),

                      // ID Header Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo Placeholder
                          Container(
                            width: 90,
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              border: Border.all(
                                color: Colors.grey[500]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Basic Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildIdRow(
                                  'LAST NAME, FIRST NAME',
                                  data['childName'] ?? 'N/A',
                                  isBold: true,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildIdRow(
                                        'DATE OF BIRTH',
                                        data['dateOfBirth'] ?? 'N/A',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildIdRow(
                                        'SEX',
                                        data['gender'] ?? 'N/A',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildIdRow(
                                  'PARENT / GUARDIAN',
                                  data['parentName'] ?? 'N/A',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Contact Details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildIdRow(
                                    'CONTACT NUMBER',
                                    data['phone'] ?? 'N/A',
                                  ),
                                ),
                                Expanded(
                                  child: _buildIdRow(
                                    'AGE',
                                    data['age']?.toString() ?? 'N/A',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildIdRow('ADDRESS', data['address'] ?? 'N/A'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status & Next Schedule Details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VACCINATION STATUS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildIdRow(
                                        'NEXT VACCINE',
                                        data['nextVaccine'] ?? 'None',
                                      ),
                                      const SizedBox(height: 4),
                                      _buildIdRow(
                                        'NEXT DUE DATE',
                                        data['nextDue'] ?? 'None',
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      data['status'],
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getStatusColor(data['status']),
                                    ),
                                  ),
                                  child: Text(
                                    (data['status'] ?? 'UNKNOWN')
                                        .toString()
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(data['status']),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              // Can trigger further actions if needed (like viewing records)
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Verified'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'scheduled':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildIdRow(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? 'N/A' : value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _showPatientLookupDialog(String patientId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Patient Found'),
        content: Text(
          'Patient ID: $patientId\n\nWould you like to view patient details?',
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
                SnackBar(
                  content: Text('Patient $patientId details would open here'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  void _showVaccineRecordDialog(String vaccineData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Vaccine Record'),
        content: Text('Vaccine data: $vaccineData\n\nRecord vaccination?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vaccination recorded successfully'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              );
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }
}
