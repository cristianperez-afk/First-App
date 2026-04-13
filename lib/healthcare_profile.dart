import 'package:flutter/material.dart';
import 'package:vaccine_care/main.dart';
import 'package:vaccine_care/health_edit_profile.dart';
import 'package:vaccine_care/health_change_password.dart';
import 'package:vaccine_care/health_privacy_security.dart';
import 'package:vaccine_care/health_terms_and_con.dart';
//import 'package:vaccine_care/health_help_and_supp.dart';
import 'package:vaccine_care/health_about_us.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.email)
          .get();
      if (doc.exists) {
        setState(() {
          _profilePictureUrl = doc.data()?['profilePictureUrl'];
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _pickAndUploadImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && currentUser != null) {
      try {
        // Show loading indicator
        messenger.showSnackBar(
          const SnackBar(content: Text('Uploading image...')),
        );

        // Create a unique filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${currentUser!.email}_$timestamp.jpg';

        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child(fileName);

        // Set metadata for the file
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploadedBy': currentUser!.email},
        );

        await ref.putFile(File(pickedFile.path), metadata);

        final downloadUrl = await ref.getDownloadURL();

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.email)
            .update({'profilePictureUrl': downloadUrl});

        setState(() {
          _profilePictureUrl = downloadUrl;
        });

        messenger.showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      } catch (e) {
        debugPrint('Upload error: $e'); // For debugging
        messenger.showSnackBar(
          SnackBar(content: Text('Error uploading image: ${e.toString()}')),
        );
      }
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select an image and ensure you are logged in')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
                children: [
                  // Profile Picture
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 56,
                          backgroundImage: _profilePictureUrl != null
                              ? NetworkImage(_profilePictureUrl!)
                              : null,
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          child: _profilePictureUrl == null
                              ? Text(
                                  currentUser?.fullName.trim().isNotEmpty == true
                                      ? currentUser!.fullName.trim()[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentUser?.fullName ?? 'Healthcare Provider',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.email ?? 'provider@healthcare.com',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Healthcare Provider',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),


            const SizedBox(height: 24),

            // Account Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingCard(
  icon: Icons.person_outline,
  title: 'Edit Profile',
  subtitle: 'Update your personal information',
  onTap: () async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfilePage(),
      ),
    );

    if (updated == true) {
      setState(() {}); // refresh profile
    }
  },
),

                  _buildSettingCard(
  icon: Icons.lock_outline,
  title: 'Change Password',
  subtitle: 'Update your password',
  onTap: () async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChangePasswordPage(),
      ),
    );

    if (changed == true && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    }
  },
),

                  /*_buildSettingCard(
                    icon: Icons.notifications_outline,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () {
                      // Navigate to notifications settings
                    },
                  ),*/
                  _buildSettingCard(
  icon: Icons.privacy_tip_outlined,
  title: 'Privacy & Security',
  subtitle: 'Learn how your data is protected',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacySecurityPage(),
      ),
    );
  },
),

                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
               

                 _buildSettingCard(
  icon: Icons.info_outline,
  title: 'About Us',
  subtitle: 'Learn more about our app and team',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AboutUsPage(),
      ),
    );
  },
),

                 _buildSettingCard(
  icon: Icons.description_outlined,
  title: 'Terms & Conditions',
  subtitle: 'Read our terms and policies',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsConditionsPage(),
      ),
    );
  },
),

                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showLogoutDialog();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[400],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              currentUser = null;
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
