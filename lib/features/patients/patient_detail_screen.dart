import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../core/services/local_database.dart';
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
            ValueListenableBuilder(
              valueListenable: LocalDatabase().getScansListenable(),
              builder: (context, box, child) {
                final scans = LocalDatabase().getPatientScans(patient.id);
                if (scans.isEmpty) {
                  return _buildEmptyHistory();
                }
                return _buildScanHistoryList(scans);
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
        
        return Dismissible(
          key: Key(scan.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.errorRed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Delete Scan Record?'),
                content: const Text('Are you sure you want to delete this scan record? This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            try {
              // Delete locally
              await LocalDatabase().deleteScan(scan.id);
              
              // Delete from Firestore if possible
              try {
                await FirebaseFirestore.instance.collection('scans').doc(scan.id).delete();
              } catch (_) {}
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scan record deleted successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete scan record: $e'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: GestureDetector(
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
                  GestureDetector(
                    onTap: () {
                      if (scan.imageUrl.isNotEmpty) {
                        showFullScreenImage(context, scan.imageUrl);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: scan.imageUrl.isNotEmpty
                            ? (scan.imageUrl.startsWith('http') || scan.imageUrl.startsWith('https')
                                ? Image.network(
                                    scan.imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade100,
                                        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 18),
                                      );
                                    },
                                  )
                                : Image.file(
                                    File(scan.imageUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade100,
                                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 18),
                                      );
                                    },
                                  ))
                            : Container(
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.remove_red_eye_outlined, color: Colors.grey, size: 18),
                              ),
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
                await LocalDatabase().deletePatient(patient.id);
                
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
