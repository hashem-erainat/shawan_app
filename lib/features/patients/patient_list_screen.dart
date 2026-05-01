import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/services/firebase_service.dart';
import '../../models/patient.dart';
import 'patient_detail_screen.dart';
import 'add_patient_screen.dart';

class PatientListScreen extends StatefulWidget {
  final Function(Patient)? onSelected;
  const PatientListScreen({super.key, this.onSelected});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            onPressed: () => _showAddPatientDialog(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Patient>>(
              stream: FirebaseService().getPatients(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final filteredPatients = snapshot.data!
                    .where((p) => p.name.toLowerCase().contains(_searchQuery))
                    .toList();

                if (filteredPatients.isEmpty) {
                  return const Center(child: Text('No patients found matching your search'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredPatients.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final patient = filteredPatients[index];
                    return _buildDismissiblePatientCard(context, patient);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissiblePatientCard(BuildContext context, Patient patient) {
    return Dismissible(
      key: Key(patient.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return false; // Just for show - never delete
      },
      onDismissed: (direction) async {
        try {
          await FirebaseService().deletePatient(patient.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting patient: $e')),
            );
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: _buildPatientCard(context, patient),
    );
  }

  Widget _buildPatientCard(BuildContext context, Patient patient) {
    return GestureDetector(
      onTap: () {
        if (widget.onSelected != null) {
          widget.onSelected!(patient);
          Navigator.pop(context);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PatientDetailScreen(patient: patient)),
          );
        }
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
            CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Text(
                patient.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    patient.lastScanDate != null
                        ? 'Last scan: ${patient.lastScanDate!.day}/${patient.lastScanDate!.month}/${patient.lastScanDate!.year}'
                        : 'No scans yet',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // Disabled - Just visual
              },
              icon: Icon(Icons.edit_outlined, color: AppTheme.primaryBlue.withOpacity(0.7), size: 20),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No patients registered yet', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPatientDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Patient'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPatientDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPatientScreen()),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, Patient patient) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Patient?'),
        content: Text('Are you sure you want to delete ${patient.name}? This will also delete all associated scans.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
