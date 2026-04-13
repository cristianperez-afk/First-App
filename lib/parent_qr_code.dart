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
  const MyQRCodePage({super.key});

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
        _children = querySnapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading children: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving QR code: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("My QR Codes")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My QR Codes"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _children.isEmpty
            ? Center(
                child: Text(
                  "No children found for your account",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              )
            : ListView.builder(
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

                  // Assign a unique key for this child
                  final qrKey = _qrKeys[child['id']] ?? GlobalKey();
                  _qrKeys[child['id']] = qrKey;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            child['childName'],
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Next Vaccine: ${child['nextVaccine']}",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 16),
                          RepaintBoundary(
                            key: qrKey,
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _isSaving
                              ? const CircularProgressIndicator()
                              : ElevatedButton.icon(
                                  onPressed: () => _saveQRCode(qrKey, qrData),
                                  icon: const Icon(Icons.share),
                                  label: const Text("Share QR Code"),
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
