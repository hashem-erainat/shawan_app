import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_database.dart';
import '../../models/patient.dart';
import '../../models/scan_record.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Starts listening to network changes to automatically sync when online.
  void startAutoSync() {
    Connectivity().onConnectivityChanged.listen((results) {
      bool isConnected = false;
      if (results is List<ConnectivityResult>) {
        isConnected = !results.contains(ConnectivityResult.none);
      } else if (results is ConnectivityResult) {
        isConnected = results != ConnectivityResult.none;
      }
      
      if (isConnected) {
        print('DEBUG: Internet connection detected. Triggering auto-sync...');
        syncNow();
      }
    });
  }

  /// Helper to check if internet is currently available.
  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results is List<ConnectivityResult>) {
      return !results.contains(ConnectivityResult.none);
    } else if (results is ConnectivityResult) {
      return results != ConnectivityResult.none;
    }
    return false;
  }

  /// Performs synchronization of all pending local items to Firebase.
  Future<void> syncNow() async {
    if (_isSyncing) {
      print('DEBUG: Sync already in progress, skipping...');
      return;
    }

    final online = await isOnline();
    if (!online) {
      print('DEBUG: Device is offline. Cannot sync.');
      return;
    }

    final pendingItems = LocalDatabase().getPendingSyncItems();
    if (pendingItems.isEmpty) {
      print('DEBUG: No pending items to sync.');
      return;
    }

    _isSyncing = true;
    print('DEBUG: Starting synchronization of ${pendingItems.length} items...');

    try {
      // Step 1: Sync patients first
      final patientKeys = pendingItems.entries
          .where((e) => e.value == 'patient')
          .map((e) => e.key)
          .toList();
      
      for (var patientId in patientKeys) {
        try {
          final patient = LocalDatabase().getPatient(patientId);
          if (patient != null) {
            print('DEBUG: Syncing patient: ${patient.name}');
            await FirebaseFirestore.instance
                .collection('patients')
                .doc(patient.id)
                .set(patient.toMap());
            
            await LocalDatabase().removeFromPendingSync(patientId);
            print('DEBUG: Patient synced successfully: ${patient.name}');
          } else {
            await LocalDatabase().removeFromPendingSync(patientId);
          }
        } catch (e) {
          print('ERROR: Failed to sync patient $patientId: $e');
        }
      }

      // Step 2: Sync scans
      final scanKeys = pendingItems.entries
          .where((e) => e.value == 'scan')
          .map((e) => e.key)
          .toList();

      for (var scanId in scanKeys) {
        try {
          final scan = LocalDatabase().getScan(scanId);
          if (scan != null) {
            print('DEBUG: Syncing scan: $scanId');
            
            String finalLeftUrl = scan.leftImageUrl;
            String finalRightUrl = scan.rightImageUrl;
            
            // Upload left eye image if local and exists
            if (!scan.leftImageUrl.startsWith('http') && scan.leftImageUrl.isNotEmpty) {
              final file = File(scan.leftImageUrl);
              if (await file.exists()) {
                print('DEBUG: Uploading local left image ${file.path} to Storage...');
                final storageRef = FirebaseStorage.instance
                    .ref()
                    .child('scans/${scanId}_left.jpg');
                final uploadTask = storageRef.putFile(file);
                final snapshot = await uploadTask;
                finalLeftUrl = await snapshot.ref.getDownloadURL();
                print('DEBUG: Left image uploaded. Remote URL: $finalLeftUrl');
              } else {
                print('WARNING: Local left file not found for scan $scanId at ${scan.leftImageUrl}');
              }
            }

            // Upload right eye image if local and exists
            if (!scan.rightImageUrl.startsWith('http') && scan.rightImageUrl.isNotEmpty) {
              final file = File(scan.rightImageUrl);
              if (await file.exists()) {
                print('DEBUG: Uploading local right image ${file.path} to Storage...');
                final storageRef = FirebaseStorage.instance
                    .ref()
                    .child('scans/${scanId}_right.jpg');
                final uploadTask = storageRef.putFile(file);
                final snapshot = await uploadTask;
                finalRightUrl = await snapshot.ref.getDownloadURL();
                print('DEBUG: Right image uploaded. Remote URL: $finalRightUrl');
              } else {
                print('WARNING: Local right file not found for scan $scanId at ${scan.rightImageUrl}');
              }
            }
            
            // Create updated scan record with remote URLs
            final updatedScan = ScanRecord(
              id: scan.id,
              userId: scan.userId,
              patientId: scan.patientId,
              patientName: scan.patientName,
              status: scan.status,
              timestamp: scan.timestamp,
              leftImageUrl: finalLeftUrl,
              leftStage: scan.leftStage,
              leftResultLabel: scan.leftResultLabel,
              leftConfidence: scan.leftConfidence,
              rightImageUrl: finalRightUrl,
              rightStage: scan.rightStage,
              rightResultLabel: scan.rightResultLabel,
              rightConfidence: scan.rightConfidence,
            );

            // Update local DB
            await LocalDatabase().saveScan(updatedScan);
            
            // Upload record to Firestore
            await FirebaseFirestore.instance
                .collection('scans')
                .doc(scanId)
                .set(updatedScan.toMap());

            // Update patient's last scan date on Firestore
            try {
              await FirebaseFirestore.instance
                  .collection('patients')
                  .doc(scan.patientId)
                  .update({
                'lastScanDate': Timestamp.fromDate(scan.timestamp),
              });
            } catch (e) {
              print('WARNING: Could not update patient lastScanDate on Firestore: $e');
            }

            await LocalDatabase().removeFromPendingSync(scanId);
            print('DEBUG: Scan synced successfully: $scanId');
          } else {
            await LocalDatabase().removeFromPendingSync(scanId);
          }
        } catch (e) {
          print('ERROR: Failed to sync scan $scanId: $e');
        }
      }
    } finally {
      _isSyncing = false;
      print('DEBUG: Synchronization process completed.');
    }
  }
}
