import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/services/firebase_service.dart';
import '../../models/patient.dart';
import '../../models/scan_record.dart';
import '../scan/result_screen.dart';

class PatientDetailScreen extends StatelessWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Profile'),
        actions: [
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(context),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Text('Diagnostic History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            StreamBuilder<List<ScanRecord>>(
              stream: FirebaseService().getPatientScans(patient.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyHistory();
                }
                return _buildScanHistoryList(snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
            child: Text(
              patient.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(height: 16),
          Text(patient.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            'Patient since ${patient.createdAt.day}/${patient.createdAt.month}/${patient.createdAt.year}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoStat('Age', patient.age?.toString() ?? 'N/A'),
              _buildInfoStat('Gender', patient.gender ?? 'N/A'),
              _buildInfoStat('Phone', patient.phone ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No scan records found for this patient.', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanHistoryList(List<ScanRecord> scans) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: scans.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final scan = scans[index];
        final Color statusColor = _getStatusColor(scan.resultLabel);
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ResultScreen(scan: scan)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(scan.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        scan.resultLabel ?? 'Processing...',
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? label) {
    switch (label) {
      case 'No DR': return AppTheme.successGreen;
      case 'Mild': return Colors.lightGreen;
      case 'Moderate': return AppTheme.warningOrange;
      case 'Severe': return Colors.orange;
      case 'Proliferative': return AppTheme.errorRed;
      default: return AppTheme.primaryBlue;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Patient?'),
        content: Text('Are you sure you want to delete ${patient.name}? This will also delete all associated scans.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () async {
              try {
                // 1. Delete the patient and their data
                await FirebaseService().deletePatient(patient.id);
                
                if (context.mounted) {
                  // 2. Close the confirmation dialog
                  Navigator.pop(dialogContext);
                  
                  // 3. Navigate back to the list screen
                  // We use a small delay or post frame callback to ensure the navigator is not locked
                  // by any rebuilds triggered by the deletion.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  });
                }
              } catch (e) {
                print('Error during patient deletion: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting patient: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
