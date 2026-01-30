import 'package:flutter/material.dart';
import 'main.dart';

  class ViewRecordsPage extends StatelessWidget {
  const ViewRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> patientRecords = globalPatients
        .where((patient) => patient['healthcareProviderEmail'] == currentUser?.email)
        .map((patient) => {
              'childName': patient['childName'],
              'parentName': patient['parentName'],
              'vaccine': patient['nextVaccine'] ?? 'Not scheduled',
              'date': patient['nextDue'] ?? 'TBD',
              'status': patient['status'] ?? 'Pending',
            })
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('View Records')),
      body: patientRecords.isEmpty
          ? const Center(
              child: Text('No patient records found'),
            )
          : ListView.builder(
        itemCount: patientRecords.length,
        itemBuilder: (context, index) {
          final record = patientRecords[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                record['status'] == 'Completed'
                    ? Icons.check_circle
                    : Icons.schedule,
                color: record['status'] == 'Completed'
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(record['childName']),
              subtitle: Text(
                'Parent: ${record['parentName']}\n'
                'Vaccine: ${record['vaccine']} | Date: ${record['date']}',
              ),
              trailing: Text(record['status']),
              onTap: () {
                // Navigate to detailed patient record page
              },
            ),
          );
        },
      ),
    );
  }
}
