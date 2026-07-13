import 'package:flutter/material.dart';
import 'main.dart';
import 'package:vaccine_care/parent_profile.dart';
import 'package:vaccine_care/parent_schedule.dart';
import 'parent_qr_code.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'ui_utils.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _children = [];
  int _upcomingVaccinations = 0;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _loadUpcomingVaccinations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadChildren();
    _loadUpcomingVaccinations();
  }

  Future<void> _loadChildren() async {
    if (currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('email', isEqualTo: currentUser!.email)
          .get();

      setState(() {
        _children = querySnapshot.docs.map((doc) {
          final data = doc.data();
          final savedSchedules =
              data['vaccinationSchedules'] as List<dynamic>? ?? [];

          final upcomingVaccinations = savedSchedules
              .where((schedule) => schedule['status'] != 'Completed')
              .map((schedule) {
                final scheduledDate = schedule['scheduledDate'] != null
                    ? DateTime.parse(schedule['scheduledDate']).toLocal()
                    : null;
                return {
                  'vaccine': schedule['vaccineName'] ?? 'Unknown Vaccine',
                  'date': scheduledDate != null
                      ? scheduledDate.toString().split(' ')[0]
                      : 'TBD',
                  'location': schedule['location'] ?? 'Clinic',
                };
              })
              .toList();

          return {
            'id': doc.id,
            'name': data['childName'],
            'age': data['age'],
            'nextVaccine': data['nextVaccine'] ?? 'Not scheduled',
            'dueDate': data['nextDue'] ?? 'TBD',
            'image': data['gender'] == 'Male'
                ? Icons.child_care
                : Icons.child_friendly,
            'upToDate': data['status'] == 'Up to date',
            'qrData': data['qrData'],
            'upcomingVaccinations': upcomingVaccinations,
            'rawData':
                data, // Adding original data to pull gender, notes, dob, etc.
          };
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading children: $e')),
              ],
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _loadUpcomingVaccinations() async {
    if (currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('email', isEqualTo: currentUser!.email)
          .get();

      int upcomingCount = 0;

      for (final doc in querySnapshot.docs) {
        final patient = doc.data();
        final savedSchedules =
            patient['vaccinationSchedules'] as List<dynamic>? ?? [];

        for (final schedule in savedSchedules) {
          if (schedule['status'] != 'Completed') {
            upcomingCount++;
          }
        }

        if (savedSchedules.isEmpty && patient['status'] == 'New Patient') {
          upcomingCount++;
        }
      }

      setState(() {
        _upcomingVaccinations = upcomingCount;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading vaccinations: $e')),
              ],
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get myChildren => _children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _selectedIndex == 0
            ? _buildHomeTab()
            : _selectedIndex == 1
            ? _buildScheduleTab()
            : _selectedIndex == 2
            ? _buildNotificationsTab()
            : _buildProfileTab(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFF3B82F6),
          unselectedItemColor: Colors.grey[400],
          elevation: 0,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                label: Text(_upcomingVaccinations.toString()),
                isLabelVisible: _upcomingVaccinations > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
              activeIcon: Badge(
                label: Text(_upcomingVaccinations.toString()),
                isLabelVisible: _upcomingVaccinations > 0,
                child: const Icon(Icons.notifications),
              ),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Background Gradient Header
          ClinicalHeader(
            title: 'Welcome back',
            subtitle: currentUser?.fullName ?? 'Parent',
            trailing: Badge(
              label: Text(_upcomingVaccinations.toString()),
              isLabelVisible: _upcomingVaccinations > 0,
              backgroundColor: Colors.red,
              child: IconButton(
                onPressed: () => setState(() => _selectedIndex = 2),
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ),

          // Main Content overlapping
          Padding(
            padding: const EdgeInsets.only(top: 150, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The "Search Card" replacement
                ClinicalCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Top Row (From / To equivalent)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MY CHILDREN',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_children.length} Patients',
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
                              Icons.health_and_safety_outlined,
                              color: Color(0xFF3B82F6),
                              size: 22,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'ACTIVE ALERTS',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_upcomingVaccinations Vaccines',
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
                      // Middle Row (Date / Passenger equivalent)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STATUS',
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
                                      'Monitoring',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: const Color(0xFFF1F5F9),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RECORDS',
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
                                      'Verified',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(
                                      Icons.verified_outlined,
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
                          onPressed: () => setState(() => _selectedIndex = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'VIEW SCHEDULES',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Saved Trips (My Children)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SAVED PROFILES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'See more',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Horizontal List
                SizedBox(
                  height: 300,
                  child: _children.isEmpty
                      ? const Center(child: Text("No profiles saved."))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _children.length,
                          itemBuilder: (context, index) {
                            return _buildHorizontalChildCard(
                              _children[index],
                              isLast: index == _children.length - 1,
                            );
                          },
                        ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalChildCard(
    Map<String, dynamic> child, {
    bool isLast = false,
  }) {
    final bool isUpToDate = child['upToDate'] == true;
    final Color statusColor = isUpToDate ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: () {
        final rawData = Map<String, dynamic>.from(
          child['rawData'] as Map<String, dynamic>? ?? <String, dynamic>{},
        );
        rawData['id'] ??= child['id'];
        rawData['childName'] ??= child['name'];
        rawData['age'] ??= child['age'];
        rawData['nextVaccine'] ??= child['nextVaccine'];
        rawData['nextDue'] ??= child['dueDate'];
        rawData['email'] ??= currentUser?.email;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MyQRCodePage(initialChild: rawData),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: EdgeInsets.only(right: isLast ? 0 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            // Top Half
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.child_care_rounded,
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
                              child['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'PATIENT PROFILE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey[400],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniInfo('Age', child['age']?.toString() ?? '-'),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                      _buildMiniInfo('Next Date', child['dueDate']?.toString() ?? '-', alignRight: true),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VACCINE',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              child['nextVaccine'] ?? 'None',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isUpToDate ? 'UP TO DATE' : 'OVERDUE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _generateChildRecordPdf(child),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('DOWNLOAD RECORD'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF1E293B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, {bool alignRight = false}) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[400],
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Future<void> _generateChildRecordPdf(Map<String, dynamic> child) async {
    final rawData = child['rawData'] as Map<String, dynamic>? ?? {};
    final schedules = rawData['vaccinationSchedules'] as List<dynamic>? ?? [];

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Vaccination Record',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${child['name']}',
                    style: pw.TextStyle(fontSize: 18, color: PdfColors.blue800),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              'Child Information',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Full Name: ${rawData['childName'] ?? 'N/A'}'),
                      pw.Text('Age: ${rawData['age'] ?? 'N/A'}'),
                      pw.Text('Gender: ${rawData['gender'] ?? 'N/A'}'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Date of Birth: ${rawData['dateOfBirth'] ?? 'N/A'}',
                      ),
                      pw.Text(
                        'Additional Notes: ${rawData['notes'] ?? 'None'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            pw.Text(
              'Parent/Guardian Information',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Name: ${currentUser?.fullName ?? 'N/A'}'),
                      pw.Text('Email: ${currentUser?.email ?? 'N/A'}'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Phone: ${currentUser?.phone ?? 'N/A'}'),
                      pw.Text('Address: N/A'),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            pw.Text(
              'Vaccination History & Schedule',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),

            schedules.isEmpty
                ? pw.Text('No vaccination schedules found.')
                : pw.TableHelper.fromTextArray(
                    headers: [
                      'Vaccine',
                      'Date',
                      'Status',
                      'Location',
                      'Personnel',
                    ],
                    data: schedules.map((schedule) {
                      final date = schedule['scheduledDate'] != null
                          ? DateTime.parse(
                              schedule['scheduledDate'],
                            ).toLocal().toString().split(' ')[0]
                          : 'TBD';
                      return [
                        schedule['vaccineName'] ?? 'N/A',
                        date,
                        schedule['status'] ?? 'Pending',
                        schedule['location'] ?? 'Clinic',
                        schedule['personnel'] ?? 'Healthcare Provider',
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey600,
                    ),
                    cellHeight: 30,
                    cellAlignments: {
                      0: pw.Alignment.centerLeft,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                      4: pw.Alignment.centerLeft,
                    },
                  ),
          ];
        },
      ),
    );

    final fileName =
        '${child['name'].toString().replaceAll(" ", "_")}_Record.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName,
    );
  }

  Widget _buildScheduleTab() {
    return const ParentScheduleTab();
  }

  Widget _buildNotificationsTab() {
    // Collect all upcoming/overdue vaccinations into a flat list
    final alerts = <Map<String, dynamic>>[];
    for (final child in _children) {
      final upcoming = child['upcomingVaccinations'] as List<dynamic>? ?? [];
      for (final v in upcoming) {
        alerts.add({
          'childName': child['name'],
          'vaccine': v['vaccine'],
          'date': v['date'],
          'location': v['location'],
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have $_upcomingVaccinations active reminders',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: alerts.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_outlined,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No new notifications',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.vaccines_outlined,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vaccination Due: ${alert['vaccine']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'For ${alert['childName']} on ${alert['date']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
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
    );
  }

  Widget _buildProfileTab() {
    return const ParentProfileTab();
  }
}
