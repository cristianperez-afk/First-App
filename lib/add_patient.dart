import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vaccine_care/main.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ui_utils.dart';

class AddPatientPage extends StatefulWidget {
  const AddPatientPage({super.key});

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final _formKey = GlobalKey<FormState>();
  final _childNameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _maternalAgeController = TextEditingController();
  final _parityController = TextEditingController();
  final _ancVisitsController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();

  DateTime? _selectedDateOfBirth;
  String _selectedGender = 'Not specified';
  String _selectedEducation = 'Unknown';
  String _selectedCivilStatus = 'Unknown';
  String _selectedPregnancyStatus = 'Not pregnant';
  String _missedVaccinationHistory = 'No';
  bool _isLoading = false;
  bool _isSaving = false;

  final List<String> _genderOptions = [
    'Not specified',
    'Male',
    'Female',
    'Other',
  ];
  final List<String> _educationOptions = [
    'Unknown',
    'No formal education',
    'Primary',
    'Secondary',
    'College',
    'Postgraduate',
  ];
  final List<String> _civilStatusOptions = [
    'Unknown',
    'Single',
    'Married',
    'Separated',
    'Widowed',
    'Cohabiting',
  ];
  final List<String> _pregnancyStatusOptions = [
    'Not pregnant',
    'Pregnant',
    'Postpartum',
    'Unknown',
  ];
  final List<String> _yesNoOptions = ['No', 'Yes'];

  @override
  void dispose() {
    _childNameController.dispose();
    _parentNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _maternalAgeController.dispose();
    _parityController.dispose();
    _ancVisitsController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildMaternalStateProfile(DateTime capturedAt) {
    final maternalAge = int.tryParse(_maternalAgeController.text.trim()) ?? 0;
    final parity = int.tryParse(_parityController.text.trim()) ?? 0;
    final antenatalVisits = int.tryParse(_ancVisitsController.text.trim()) ?? 0;
    final hasMissedVaccinationAppointments = _missedVaccinationHistory == 'Yes';

    final highRiskTriggers = <String>[];
    final moderateRiskTriggers = <String>[];

    if (antenatalVisits == 0) {
      highRiskTriggers.add('No antenatal care visits');
    }

    if (parity >= 4) {
      highRiskTriggers.add('Parity of four or more');
    }

    if (hasMissedVaccinationAppointments) {
      highRiskTriggers.add('History of missed vaccination appointments');
    }

    if (_selectedEducation == 'No formal education' ||
        _selectedEducation == 'Primary') {
      moderateRiskTriggers.add('Lower educational attainment');
    }

    if (_selectedCivilStatus == 'Single' ||
        _selectedCivilStatus == 'Separated' ||
        _selectedCivilStatus == 'Widowed') {
      moderateRiskTriggers.add('Single-parent or limited household support');
    }

    final familyRiskTier = highRiskTriggers.isNotEmpty
        ? 'High'
        : moderateRiskTriggers.isNotEmpty
        ? 'Moderate'
        : 'Low';

    return {
      'maternalAge': maternalAge,
      'educationalAttainment': _selectedEducation,
      'civilStatus': _selectedCivilStatus,
      'parity': parity,
      'pregnancyStatus': _selectedPregnancyStatus,
      'antenatalCareVisits': antenatalVisits,
      'missedVaccinationAppointments': _missedVaccinationHistory,
      'riskLevel': familyRiskTier,
      'riskTier': familyRiskTier,
      'familyRiskTier': familyRiskTier,
      'riskDrivers': [...highRiskTriggers, ...moderateRiskTriggers],
      'riskRuleSummary':
          'High if no antenatal care visits, parity of four or more, or missed vaccination appointments; Moderate if lower educational attainment or single-parent status; Low otherwise.',
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  /// SAVE PATIENT TO FIRESTORE
  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final ageInDays = now.difference(_selectedDateOfBirth!).inDays;
      final ageInYears = (ageInDays / 365).floor();
      final ageInMonths = ((ageInDays % 365) / 30).floor();
      final ageString = ageInYears > 0
          ? '$ageInYears years'
          : '$ageInMonths months';

      final docRef = FirebaseFirestore.instance.collection('patients').doc();
      final patientId = docRef.id;
      final maternalStateProfile = _buildMaternalStateProfile(now);

      // Create QR-safe version without Firestore-specific fields
      final qrPatientData = {
        'id': patientId,
        'childName': _childNameController.text.trim(),
        'parentName': _parentNameController.text.trim(),
        'age': ageString,
        'dateOfBirth': _selectedDateOfBirth!.toIso8601String().split('T')[0],
        'lastVisit': now.toIso8601String().split('T')[0],
        'nextVaccine': 'Initial Assessment',
        'nextDue': now
            .add(const Duration(days: 7))
            .toIso8601String()
            .split('T')[0],
        'status': 'New Patient',
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'vaccinesCompleted': 0,
        'vaccinesTotal': 12,
        'gender': _selectedGender,
        'notes': _notesController.text.trim(),
        'maternalStateProfile': maternalStateProfile,
        'maternalRiskLevel': maternalStateProfile['riskLevel'],
      };

      final newPatient = {
        ...qrPatientData,
        'healthcareProviderEmail': currentUser?.email ?? '',
        'systemRiskTier': maternalStateProfile['riskTier'],
        'currentRiskTier': maternalStateProfile['riskTier'],
        'riskOverride': {
          'isOverridden': false,
          'systemTier': maternalStateProfile['riskTier'],
        },
        'riskOverrideHistory': <Map<String, dynamic>>[],
        'familyRiskTier': maternalStateProfile['familyRiskTier'],
        'familyRiskDrivers': maternalStateProfile['riskDrivers'],
        'riskRuleSummary': maternalStateProfile['riskRuleSummary'],
        'missedVaccinationAppointments':
            maternalStateProfile['missedVaccinationAppointments'],
        'maternalRiskLevel': maternalStateProfile['riskTier'],
        'qrData': jsonEncode(qrPatientData),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(newPatient);

      // Also add to global patients list for immediate UI updates
      globalPatients.add(newPatient);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patient ${newPatient['childName']} added successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        _showQRCodeDialog(qrPatientData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// GENERATE QR IMAGE FILE
  RenderRepaintBoundary? _getQrBoundary() {
    final qrContext = _qrKey.currentContext;
    if (qrContext == null) {
      debugPrint('QR key context is null');
      return null;
    }

    final boundary = qrContext.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      debugPrint('Render boundary is null');
      return null;
    }

    return boundary;
  }

  Future<File?> _generateQrImageFile() async {
    try {
      // Wait a bit for the dialog to render
      await Future.delayed(const Duration(milliseconds: 500));

      final boundary = _getQrBoundary();
      if (boundary == null) {
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('Byte data is null');
        return null;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/patient_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      debugPrint('QR code file generated: $filePath');
      return file;
    } catch (e) {
      debugPrint('QR generation error: $e');
      return null;
    }
  }

  /// SELECT DATE OF BIRTH
  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  /// SAVE QR TO FILE AND SHARE
  Future<void> _saveQRCode() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _isSaving = true);

      // Wait for the QR code to render
      await Future.delayed(const Duration(milliseconds: 500));

      final boundary = _getQrBoundary();
      if (boundary == null) {
        throw Exception('QR code boundary not found');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to get image data');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/patient_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(filePath)], text: 'Patient QR Code');

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('QR Code saved and ready to share!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Save QR error: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error saving QR code: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// SHARE VIA EMAIL
  Future<void> _sendViaEmail(Map<String, dynamic> patientData) async {
    final messenger = ScaffoldMessenger.of(context);
    // Show loading indicator
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Generating QR code...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final qrFile = await _generateQrImageFile();

    if (qrFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to generate QR code. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final emailBody =
        '''
Hello ${patientData['parentName']},

Here are the details for ${patientData['childName']}:

Patient ID: ${patientData['id']}
Child Name: ${patientData['childName']}
Date of Birth: ${patientData['dateOfBirth']}
Phone: ${patientData['phone']}
Next Appointment: ${patientData['nextDue']}

The attached QR code will be used for quick check-ins.
Please save it on your phone.

Best regards,
Vaccination Clinic
''';

    try {
      await Share.shareXFiles(
        [XFile(qrFile.path)],
        subject: 'Patient QR Code - ${patientData['childName']}',
        text: emailBody,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error sharing via email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// SHARE VIA SMS
  Future<void> _sendViaSMS(Map<String, dynamic> patientData) async {
    final messenger = ScaffoldMessenger.of(context);
    final message =
        '''
Patient ID: ${patientData['id']}
Child: ${patientData['childName']}
Next Visit: ${patientData['nextDue']}

Scan QR code for quick check-in.
''';

    try {
      await Share.share(message);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error sharing via SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// SHOW QR CODE DIALOG
  void _showQRCodeDialog(Map<String, dynamic> patientData) {
    final qrData = jsonEncode(patientData);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 40),
                            SizedBox(height: 8),
                            Text(
                              'PATIENT REGISTERED',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            patientData['childName'],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'OFFICIAL DIGITAL HEALTH ID',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // QR Container
                          RepaintBoundary(
                            key: _qrKey,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 200.0,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF1E293B),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    patientData['id'].toString().toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          const Text(
                            'DISTRIBUTION ACTIONS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildShareOption(
                                icon: Icons.download_rounded,
                                label: 'Save',
                                onTap: _isSaving ? null : _saveQRCode,
                                isLoading: _isSaving,
                              ),
                              _buildShareOption(
                                icon: Icons.alternate_email_rounded,
                                label: 'Email',
                                onTap: () => _sendViaEmail(patientData),
                              ),
                              _buildShareOption(
                                icon: Icons.sms_rounded,
                                label: 'SMS',
                                onTap: () => _sendViaSMS(patientData),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'FINISH REGISTRATION',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
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
        );
      },
    );
  }

  /// SHARE OPTION WIDGET
  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 24, color: const Color(0xFF3B82F6)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Patient Registration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Patient Information',
                  'Enter the child\'s details to create a new digital health record.',
                ),
                TextFormField(
                  controller: _childNameController,
                  decoration: clinicalInputDecoration('Child\'s Full Name *', Icons.child_care_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter child\'s name'
                      : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDateOfBirth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Color(0xFF3B82F6), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date of Birth *',
                                style: TextStyle(
                                  color: const Color(0xFF64748B),
                                  fontSize: _selectedDateOfBirth != null ? 10 : 14,
                                  fontWeight: _selectedDateOfBirth != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (_selectedDateOfBirth != null)
                                Text(
                                  '${_selectedDateOfBirth!.toLocal()}'.split(' ')[0],
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: clinicalInputDecoration('Gender', Icons.person_outline_rounded),
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                  items: _genderOptions
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGender = v!),
                  onSaved: (v) => _selectedGender = v!,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  'Parent/Guardian Information',
                  'Contact details for clinical communication and vaccination alerts.',
                ),
                TextFormField(
                  controller: _parentNameController,
                  decoration: clinicalInputDecoration('Parent/Guardian Name *', Icons.person_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter parent\'s name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: clinicalInputDecoration('Phone Number *', Icons.phone_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter phone number'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: clinicalInputDecoration('Email Address', Icons.alternate_email_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: clinicalInputDecoration('Residential Address', Icons.location_on_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: clinicalInputDecoration('Clinical Notes', Icons.notes_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  'Risk Profile Data',
                  'Maternal and guardian indicators for clinical risk classification.',
                ),
                TextFormField(
                  controller: _maternalAgeController,
                  decoration: clinicalInputDecoration('Maternal Age *', Icons.cake_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null) {
                      return 'Please enter a valid maternal age';
                    }
                    if (parsed < 10 || parsed > 65) {
                      return 'Please enter a realistic age';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEducation,
                  decoration: clinicalInputDecoration('Educational Attainment *', Icons.school_rounded),
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                  items: _educationOptions
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedEducation = value ?? 'Unknown'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select educational attainment'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCivilStatus,
                  decoration: clinicalInputDecoration('Civil Status *', Icons.assignment_ind_rounded),
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                  items: _civilStatusOptions
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCivilStatus = value ?? 'Unknown'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select civil status'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _parityController,
                  decoration: clinicalInputDecoration('Parity (Number of Births) *', Icons.family_restroom_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null) {
                      return 'Please enter parity as a number';
                    }
                    if (parsed < 0) {
                      return 'Parity cannot be negative';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPregnancyStatus,
                  decoration: clinicalInputDecoration('Pregnancy Status *', Icons.pregnant_woman_rounded),
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                  items: _pregnancyStatusOptions
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _selectedPregnancyStatus = value ?? 'Not pregnant',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select pregnancy status'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ancVisitsController,
                  decoration: clinicalInputDecoration('Antenatal Care Visits *', Icons.health_and_safety_rounded),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null) {
                      return 'Please enter number of visits';
                    }
                    if (parsed < 0) {
                      return 'Visits cannot be negative';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _missedVaccinationHistory,
                  decoration: clinicalInputDecoration('History of Missed Appointments? *', Icons.event_busy_rounded),
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                  items: _yesNoOptions
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _missedVaccinationHistory = value ?? 'No',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select history'
                      : null,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePatient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                            'Add Patient',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
