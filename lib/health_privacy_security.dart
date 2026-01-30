import 'package:flutter/material.dart';

class PrivacySecurityPage extends StatelessWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionHeader('Your Privacy Matters'),
            _infoCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Data Privacy',
              description:
                  'We value your privacy. All personal and medical information '
                  'entered in this application is used solely for immunization '
                  'tracking and healthcare purposes.',
            ),

            _infoCard(
              icon: Icons.lock_outline,
              title: 'Data Protection',
              description:
                  'User data is protected within the application. Passwords are '
                  'never displayed and access is restricted based on user roles '
                  '(Parent or Healthcare Provider).',
            ),

            const SizedBox(height: 24),
            _sectionHeader('Security Practices'),

            _securityItem(
              Icons.password_outlined,
              'Password Security',
              'Passwords must be at least 6 characters and are required to '
              'change securely through the Change Password feature.',
            ),

            _securityItem(
              Icons.admin_panel_settings_outlined,
              'Role-Based Access',
              'Parents can only view their own children’s records, while '
              'healthcare providers have controlled access to patient data.',
            ),

            _securityItem(
              Icons.qr_code_2_outlined,
              'QR Code Safety',
              'QR codes contain only essential patient identifiers and are '
              'shared intentionally by authorized users.',
            ),

            const SizedBox(height: 24),
            _sectionHeader('Your Control'),

            _infoCard(
              icon: Icons.settings_outlined,
              title: 'Manage Your Account',
              description:
                  'You can update your password anytime through the Change '
                  'Password feature. Always log out after using shared devices.',
            ),

            _infoCard(
              icon: Icons.info_outline,
              title: 'Transparency',
              description:
                  'This application does not sell, trade, or share your personal '
                  'information with third parties.',
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'Last updated: December 2024',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
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

  Widget _securityItem(
    IconData icon,
    String title,
    String description,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description),
    );
  }
}
