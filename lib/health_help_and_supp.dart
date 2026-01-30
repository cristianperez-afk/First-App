import 'package:flutter/material.dart';

class HealthSupportPage extends StatelessWidget {
  const HealthSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health & Support'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Health Resources Section
            const Text(
              'Health Resources',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCard(
              context,
              title: 'Vaccination Guidelines',
              description: 'Read the latest national and WHO vaccination guidelines.',
              icon: Icons.health_and_safety_outlined,
              onTap: () {
                // Navigate to guidelines or open link
              },
            ),
            _buildCard(
              context,
              title: 'Medical Articles',
              description: 'Access educational resources for healthcare providers.',
              icon: Icons.article_outlined,
              onTap: () {
                // Navigate to articles page
              },
            ),
            const SizedBox(height: 24),

            // Support Section
            const Text(
              'Support',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCard(
              context,
              title: 'Contact Support',
              description: 'Reach out to our support team via email or phone.',
              icon: Icons.support_agent_outlined,
              onTap: () {
                // Navigate to contact form or show contact info
              },
            ),
            _buildCard(
              context,
              title: 'FAQs',
              description: 'Frequently asked questions about using the app.',
              icon: Icons.question_answer_outlined,
              onTap: () {
                // Navigate to FAQs page
              },
            ),
            const SizedBox(height: 24),

            // Emergency Info Section
            const Text(
              'Emergency Info',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCard(
              context,
              title: 'Emergency Contacts',
              description: 'Access important medical and local emergency contacts.',
              icon: Icons.emergency_outlined,
              onTap: () {
                // Navigate to emergency contacts page
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context,
      {required String title,
      required String description,
      required IconData icon,
      required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
