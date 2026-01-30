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
  final GlobalKey _qrKey = GlobalKey();

  DateTime? _selectedDateOfBirth;
  String _selectedGender = 'Not specified';
  bool _isLoading = false;
  bool _isSaving = false;

  final List<String> _genderOptions = ['Not specified', 'Male', 'Female', 'Other'];

  @override
  void dispose() {
    _childNameController.dispose();
    _parentNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// SAVE PATIENT TO FIRESTORE
  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

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
      final ageString = ageInYears > 0 ? '$ageInYears years' : '$ageInMonths months';

      final docRef = FirebaseFirestore.instance.collection('patients').doc();
      final patientId = docRef.id;

      // Create QR-safe version without Firestore-specific fields
      final qrPatientData = {
        'id': patientId,
        'childName': _childNameController.text.trim(),
        'parentName': _parentNameController.text.trim(),
        'age': ageString,
        'dateOfBirth': _selectedDateOfBirth!.toIso8601String().split('T')[0],
        'lastVisit': now.toIso8601String().split('T')[0],
        'nextVaccine': 'Initial Assessment',
        'nextDue': now.add(const Duration(days: 7)).toIso8601String().split('T')[0],
        'status': 'New Patient',
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'vaccinesCompleted': 0,
        'vaccinesTotal': 12,
        'gender': _selectedGender,
        'notes': _notesController.text.trim(),
      };

      final newPatient = {
        ...qrPatientData,
        'healthcareProviderEmail': currentUser?.email ?? '',
        'qrData': jsonEncode(qrPatientData),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(newPatient);

      // Also add to global patients list for immediate UI updates
      globalPatients.add(qrPatientData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient ${newPatient['childName']} added successfully!'),
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
  Future<File?> _generateQrImageFile() async {
    try {
      // Wait a bit for the dialog to render
      await Future.delayed(const Duration(milliseconds: 500));

      final context = _qrKey.currentContext;
      if (context == null) {
        debugPrint('QR key context is null');
        return null;
      }

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('Render boundary is null');
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
      final filePath = '${directory.path}/patient_qr_${DateTime.now().millisecondsSinceEpoch}.png';
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
    try {
      setState(() => _isSaving = true);

      // Wait for the QR code to render
      await Future.delayed(const Duration(milliseconds: 500));

      final context = _qrKey.currentContext;
      if (context == null) {
        throw Exception('QR code context not found');
      }

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
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
      final filePath = '${directory.path}/patient_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(filePath)], text: 'Patient QR Code');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code saved and ready to share!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Save QR error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
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

    final emailBody = '''
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
        ScaffoldMessenger.of(context).showSnackBar(
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
    final message = '''
Patient ID: ${patientData['id']}
Child: ${patientData['childName']}
Next Visit: ${patientData['nextDue']}

Scan QR code for quick check-in.
''';

    try {
      await Share.share(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.qr_code_2, size: 28, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Patient QR Code',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(patientData['childName'], style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!, width: 2),
                          ),
                          child: Column(
                            children: [
                              QrImageView(data: qrData, version: QrVersions.auto, size: 220.0, backgroundColor: Colors.white),
                              const SizedBox(height: 12),
                              Text('ID: ${patientData['id']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('Share QR Code:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildShareOption(icon: Icons.save_alt, label: 'Save', onTap: _isSaving ? null : _saveQRCode, isLoading: _isSaving),
                          _buildShareOption(icon: Icons.email, label: 'Email', onTap: () => _sendViaEmail(patientData)),
                          _buildShareOption(icon: Icons.message, label: 'SMS', onTap: () => _sendViaSMS(patientData)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Done'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Patients can scan this QR code for quick check-in', style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// SHARE OPTION WIDGET
  Widget _buildShareOption({required IconData icon, required String label, required VoidCallback? onTap, bool isLoading = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon, size: 28, color: Colors.blue),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Patient'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Patient Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Enter the child\'s details to add them to the system', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 24),
                TextFormField(controller: _childNameController, decoration: const InputDecoration(labelText: 'Child\'s Full Name *', prefixIcon: Icon(Icons.child_care), border: OutlineInputBorder()), validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter child\'s name' : null),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDateOfBirth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_selectedDateOfBirth != null ? '${_selectedDateOfBirth!.toLocal()}'.split(' ')[0] : 'Date of Birth *', style: TextStyle(color: _selectedDateOfBirth != null ? Colors.black : Colors.grey[500], fontSize: 16)),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                  items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _selectedGender = v!),
                  onSaved: (v) => _selectedGender = v!,
                ),
                const SizedBox(height: 24),
                const Text('Parent/Guardian Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(controller: _parentNameController, decoration: const InputDecoration(labelText: 'Parent/Guardian Name *', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()), validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter parent\'s name' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()), keyboardType: TextInputType.phone, validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter phone number' : null),
                const SizedBox(height: 16),
                TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress, validator: (value) {
                  if (value != null && value.isNotEmpty && !value.contains('@')) return 'Please enter a valid email';
                  return null;
                }),
                const SizedBox(height: 16),
                TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on), border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 16),
                TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'Additional Notes', prefixIcon: Icon(Icons.note), border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePatient,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Patient', style: TextStyle(fontSize: 16)),
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
