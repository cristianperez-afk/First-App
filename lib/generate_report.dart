import 'package:flutter/material.dart';

class GenerateReportPage extends StatefulWidget {
  const GenerateReportPage({super.key});

  @override
  State<GenerateReportPage> createState() => _GenerateReportPageState();
}

class _GenerateReportPageState extends State<GenerateReportPage> {
  String _selectedReportType = 'Vaccination Summary';
  DateTimeRange? _selectedDateRange;
  bool _isGenerating = false;

  final List<String> _reportTypes = [
    'Vaccination Summary',
    'Patient Records',
    'Appointment Statistics',
    'Compliance Report',
  ];

  // Recent reports list
  final List<Map<String, String>> _recentReports = [
    {
      'title': 'Vaccination Summary - Dec 2024',
      'subtitle': 'Generated on Dec 10, 2024',
    },
    {
      'title': 'Patient Records - Nov 2024',
      'subtitle': 'Generated on Nov 28, 2024',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Report'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Generate Healthcare Reports',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select report type and parameters to generate your report',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),

              // Report Type Selection
              const Text(
                'Report Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _selectedReportType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _reportTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedReportType = value!;
                    });
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Date Range Selection
              const Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _selectedDateRange ??
                        DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 30)),
                          end: DateTime.now(),
                        ),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDateRange = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDateRange != null
                              ? '${_selectedDateRange!.start.toString().split(' ')[0]} - ${_selectedDateRange!.end.toString().split(' ')[0]}'
                              : 'Select date range',
                          style: TextStyle(
                            color: _selectedDateRange != null ? Colors.black : Colors.grey[500],
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Generate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateReport,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Generate Report',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Recent Reports Section
              const Text(
                'Recent Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ..._recentReports.map((report) => _buildRecentReportCard(report['title']!, report['subtitle']!)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentReportCard(String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.description, color: Theme.of(context).primaryColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.download),
          onPressed: () {
            // TODO: Implement download functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Downloading report...')),
            );
          },
        ),
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
    });

    // Simulate report generation
    await Future.delayed(const Duration(seconds: 2));

    // Add the generated report to recent reports
    final now = DateTime.now();
    final dateStr = '${now.month}/${now.day}/${now.year}';
    final newReport = {
      'title': '$_selectedReportType - ${now.year}',
      'subtitle': 'Generated on $dateStr',
    };

    setState(() {
      _recentReports.insert(0, newReport); // Add to the beginning of the list
      _isGenerating = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_selectedReportType report generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}