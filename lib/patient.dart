import 'package:flutter/material.dart';
import 'package:vaccine_care/main.dart';
import 'package:vaccine_care/add_patient.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh patients when tab becomes visible
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    if (currentUser == null) {
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('patients')
          .get();

      setState(() {
        _patients = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id, // Ensure we have the document ID
          };
        }).toList();
      });
    } catch (e) {
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

  // Use Firestore patients list filtered by current healthcare provider
  List<Map<String, dynamic>> get allPatients => _patients;

  List<Map<String, dynamic>> get filteredPatients {
    var patients = allPatients.where((patient) {
      final matchesSearch =
          patient['childName'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          patient['parentName'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          patient['id'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesFilter =
          _selectedFilter == 'All' ||
          (_selectedFilter == 'Up to date' &&
              patient['status'] == 'Up to date') ||
          (_selectedFilter == 'Overdue' && patient['status'] == 'Overdue');

      return matchesSearch && matchesFilter;
    }).toList();

    return patients;
  }

  Future<void> _refreshPatients() async {
    await _loadPatients();
  }

  Map<String, dynamic>? _getMaternalStateProfile(Map<String, dynamic> patient) {
    final profile = patient['maternalStateProfile'];
    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }
    return null;
  }

  Map<String, dynamic>? _getRiskOverride(Map<String, dynamic> patient) {
    final override = patient['riskOverride'];
    if (override is Map) {
      return Map<String, dynamic>.from(override);
    }
    return null;
  }

  String _resolveRiskTier(Map<String, dynamic> patient) {
    final override = _getRiskOverride(patient);
    final overriddenTier = override?['overriddenTier']?.toString().trim();
    if (overriddenTier != null && overriddenTier.isNotEmpty) {
      return overriddenTier;
    }

    final currentRiskTier = patient['currentRiskTier']?.toString().trim();
    if (currentRiskTier != null && currentRiskTier.isNotEmpty) {
      return currentRiskTier;
    }

    final maternalRiskLevel = patient['maternalRiskLevel']?.toString().trim();
    if (maternalRiskLevel != null && maternalRiskLevel.isNotEmpty) {
      return maternalRiskLevel;
    }

    final familyRiskTier = patient['familyRiskTier']?.toString().trim();
    if (familyRiskTier != null && familyRiskTier.isNotEmpty) {
      return familyRiskTier;
    }

    return _formatValue(patient['riskLevel']);
  }

  String _resolveSystemRiskTier(Map<String, dynamic> patient) {
    final override = _getRiskOverride(patient);
    final overrideSystemTier = override?['systemTier']?.toString().trim();
    if (overrideSystemTier != null && overrideSystemTier.isNotEmpty) {
      return overrideSystemTier;
    }

    final systemRiskTier = patient['systemRiskTier']?.toString().trim();
    if (systemRiskTier != null && systemRiskTier.isNotEmpty) {
      return systemRiskTier;
    }

    final maternalRiskLevel = patient['maternalRiskLevel']?.toString().trim();
    if (maternalRiskLevel != null && maternalRiskLevel.isNotEmpty) {
      return maternalRiskLevel;
    }

    final familyRiskTier = patient['familyRiskTier']?.toString().trim();
    if (familyRiskTier != null && familyRiskTier.isNotEmpty) {
      return familyRiskTier;
    }

    return _formatValue(patient['riskLevel']);
  }

  String _formatValue(dynamic value, {String fallback = 'Not provided'}) {
    if (value == null) {
      return fallback;
    }
    if (value is List) {
      return value.isEmpty
          ? fallback
          : value.map((item) => item.toString()).join(', ');
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) {
      return 'Not provided';
    }

    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split('.').first;
    }

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      return _formatValue(value);
    }

    return parsed.toLocal().toString().split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', allPatients.length),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Up to date',
                          allPatients
                              .where((p) => p['status'] == 'Up to date')
                              .length,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Overdue',
                          allPatients
                              .where((p) => p['status'] == 'Overdue')
                              .length,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Results Count
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredPatients.length} Patient${filteredPatients.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: () {
                      // Add sorting options
                    },
                  ),
                ],
              ),
            ),

            // Patients List
            Expanded(
              child: filteredPatients.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refreshPatients,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = filteredPatients[index];
                          return _buildPatientCard(patient);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddPatientDialog();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient'),
      ),
    );
  }

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

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final isOverdue = patient['status'] == 'Overdue';
    Color statusColor = isOverdue ? Colors.red : Colors.green;

    return GestureDetector(
      onTap: () => _showPatientDetails(patient),
      child: Container(
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
                        patient['childName']?.toString()[0].toUpperCase() ??
                            'U',
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
                          patient['childName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${patient['id']} • ${patient['age'] ?? ''}',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (patient['status'] ?? 'Unknown').toString().toUpperCase(),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEXT VACCINATION',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.vaccines_rounded,
                              size: 14,
                              color: Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                patient['nextVaccine'] ?? 'None Scheduled',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
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
                    height: 32,
                    width: 1,
                    color: const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'DUE DATE',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        patient['nextDue'] ?? 'TBD',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No patients found',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Add your first patient to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    final maternalProfile = _getMaternalStateProfile(patient);
    final riskOverride = _getRiskOverride(patient);
    final maternalRiskLevel = _formatValue(_resolveRiskTier(patient));
    final systemRiskLevel = _formatValue(_resolveSystemRiskTier(patient));
    final hasRiskOverride = riskOverride?['isOverridden'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
              // Handle bar
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
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      patient['childName'].toString()[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient['childName'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ID: ${patient['id']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailSection('Personal Information', [
                _buildDetailRow('Age', patient['age']),
                _buildDetailRow('Date of Birth', patient['dateOfBirth']),
                _buildDetailRow('Parent/Guardian', patient['parentName']),
              ]),
              if (maternalProfile != null) ...[
                const SizedBox(height: 16),
                _buildDetailSection('Maternal State Profile', [
                  _buildDetailRow(
                    'Maternal Age',
                    _formatValue(maternalProfile['maternalAge']),
                  ),
                  _buildDetailRow(
                    'Educational Attainment',
                    _formatValue(maternalProfile['educationalAttainment']),
                  ),
                  _buildDetailRow(
                    'Civil Status',
                    _formatValue(maternalProfile['civilStatus']),
                  ),
                  _buildDetailRow(
                    'Parity',
                    _formatValue(maternalProfile['parity']),
                  ),
                  _buildDetailRow(
                    'Pregnancy Status',
                    _formatValue(maternalProfile['pregnancyStatus']),
                  ),
                  _buildDetailRow(
                    'ANC Visits',
                    _formatValue(maternalProfile['antenatalCareVisits']),
                  ),
                  _buildDetailRow('Risk Level', maternalRiskLevel),
                  _buildDetailRow('System Tier', systemRiskLevel),
                  _buildDetailRow(
                    'Risk Factors',
                    _formatValue(maternalProfile['riskFactors']),
                  ),
                ]),
              ],
              if (hasRiskOverride && riskOverride != null) ...[
                const SizedBox(height: 16),
                _buildDetailSection('Supervisory Override', [
                  _buildDetailRow('Override Status', 'Active'),
                  _buildDetailRow(
                    'Override Tier',
                    _formatValue(riskOverride['overriddenTier']),
                  ),
                  _buildDetailRow(
                    'Reason',
                    _formatValue(riskOverride['reason']),
                  ),
                  _buildDetailRow(
                    'Reviewed By',
                    _formatValue(riskOverride['overriddenBy']),
                  ),
                  _buildDetailRow(
                    'Reviewed At',
                    _formatTimestamp(riskOverride['overriddenAt']),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              _buildDetailSection('Contact Information', [
                _buildDetailRow('Phone', patient['phone']),
                _buildDetailRow('Email', patient['email']),
                _buildDetailRow('Address', patient['address']),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Vaccination Status', [
                _buildDetailRow('Status', patient['status']),
                _buildDetailRow('Last Visit', patient['lastVisit']),
                _buildDetailRow('Next Vaccine', patient['nextVaccine']),
                _buildDetailRow('Due Date', patient['nextDue']),
                _buildDetailRow(
                  'Completed',
                  '${patient['vaccinesCompleted']}/${patient['vaccinesTotal']} vaccines',
                ),
              ]),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to vaccination record
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('View History'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Schedule appointment
                      },
                      icon: const Icon(Icons.event),
                      label: const Text('Schedule'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPatientDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPatientPage()),
    ).then((_) {
      // Refresh the patients list when returning from add patient page
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
