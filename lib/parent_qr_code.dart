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

class MyQRCodePage extends StatefulWidget {
  const MyQRCodePage({super.key, this.initialChild});

  final Map<String, dynamic>? initialChild;

  @override
  State<MyQRCodePage> createState() => _MyQRCodePageState();
}

class _MyQRCodePageState extends State<MyQRCodePage> {
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    if (widget.initialChild != null) {
      final selectedChild = Map<String, dynamic>.from(widget.initialChild!);
      final selectedId =
          (selectedChild['id'] ?? selectedChild['childName'] ?? 'patient')
              .toString();
      _qrKeys.putIfAbsent(selectedId, () => GlobalKey());
      setState(() {
        _children = [selectedChild];
        _isLoading = false;
      });
      return;
    }

    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('email', isEqualTo: currentUser!.email)
          .get();

      setState(() {
        _children = querySnapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] ??= doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading children: $e')));
      }
    }
  }

  bool _isSaving = false;

  // Store a unique GlobalKey for each child
  final Map<String, GlobalKey> _qrKeys = {};

  Future<File?> _generateQrImageFile(GlobalKey qrKey) async {
    try {
      final context = qrKey.currentContext;
      if (context == null) return null;

      final boundary = context.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/patient_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      debugPrint('QR generation error: $e');
      return null;
    }
  }

  Future<void> _saveQRCode(GlobalKey qrKey, String qrData) async {
    setState(() => _isSaving = true);
    try {
      final qrFile = await _generateQrImageFile(qrKey);
      if (qrFile == null) return;

      await Share.shareXFiles([XFile(qrFile.path)], text: 'Patient QR Code');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving QR code: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildInfoItem(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isStatus ? (statusColor ?? Colors.black87) : const Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showFullscreenQr(String qrData) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 280,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Your QR details", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _children.isEmpty
          ? Center(
              child: Text(
                "No children found for your account",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _children.length,
              itemBuilder: (context, index) {
                final child = _children[index];
                final safeData = {
                  'id': child['id'],
                  'childName': child['childName'],
                  'parentName': child['parentName'],
                  'age': child['age'],
                  'dateOfBirth': child['dateOfBirth'],
                  'lastVisit': child['lastVisit'],
                  'nextVaccine': child['nextVaccine'],
                  'nextDue': child['nextDue'],
                  'status': child['status'],
                  'phone': child['phone'],
                  'email': child['email'],
                  'address': child['address'],
                  'vaccinesCompleted': child['vaccinesCompleted'],
                  'vaccinesTotal': child['vaccinesTotal'],
                  'gender': child['gender'],
                  'notes': child['notes'],
                };
                final qrData = child['qrData'] ?? jsonEncode(safeData);
                final childKey =
                    (child['id'] ?? child['childName'] ?? 'patient')
                        .toString();
                final qrKey = _qrKeys[childKey] ?? GlobalKey();
                _qrKeys[childKey] = qrKey;

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Health Pass Identification
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.verified_user_outlined,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'VACCICARE VERIFIED',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Digital Health ID',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                child['id']?.toString().substring(0, 8).toUpperCase() ?? 'ID',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Patient Profile Section
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PATIENT PROFILE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                                  child: Icon(
                                    child['gender'] == 'Male' ? Icons.boy_rounded : Icons.girl_rounded,
                                    color: const Color(0xFF3B82F6),
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        child['childName'] ?? 'Unknown Patient',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'DOB: ${child['dateOfBirth'] ?? '-'} • Age: ${child['age'] ?? '-'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 24),

                            // Vaccination Status Grid
                            const Text(
                              'IMMUNIZATION STATUS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'CURRENT STATUS',
                                    child['status'] ?? 'N/A',
                                    isStatus: true,
                                    statusColor: child['status'] == 'Up to date' ? Colors.green : Colors.orange,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'NEXT VACCINATION',
                                    child['nextVaccine'] ?? 'TBD',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'NEXT DUE DATE',
                                    child['nextDue'] ?? 'TBD',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'LAST VISIT',
                                    child['lastVisit'] ?? '-',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // QR Code Section
                      Center(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => _showFullscreenQr(qrData),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: RepaintBoundary(
                                    key: qrKey,
                                    child: QrImageView(
                                      data: qrData,
                                      version: QrVersions.auto,
                                      size: 160,
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF1E293B),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.grey[500]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Scan for patient validation',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer Actions
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: _isSaving
                            ? const Center(child: CircularProgressIndicator())
                            : SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: () => _saveQRCode(qrKey, qrData),
                                  icon: const Icon(Icons.share_rounded, size: 20),
                                  label: const Text(
                                    'Download and Share',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
