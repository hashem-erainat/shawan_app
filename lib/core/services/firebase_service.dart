import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/scan_record.dart';
import '../../models/patient.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload scan results with actual image saved in Firebase Storage
  Future<ScanRecord> uploadScan(File imageFile, String patientId, String patientName) async {
    print('DEBUG: Starting uploadScan for $patientName');
    try {
      String scanId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Upload image to Firebase Storage
      print('DEBUG: Uploading image to Storage under path: scans/$scanId.jpg');
      final Reference storageRef = _storage.ref().child('scans/$scanId.jpg');
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String imageUrl = await snapshot.ref.getDownloadURL();
      print('DEBUG: Image uploaded successfully. URL: $imageUrl');
 
      // Generate random AI result
      int stage = Random().nextInt(5); // 0 to 4
      List<String> labels = ['No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative'];
      double confidence = 75 + Random().nextDouble() * 20;

      // 2. Create record in Firestore
      ScanRecord record = ScanRecord(
        id: scanId,
        userId: 'dummy_user_123',
        patientId: patientId,
        patientName: patientName,
        imageUrl: imageUrl,
        status: ScanStatus.completed,
        stage: stage,
        resultLabel: labels[stage],
        timestamp: DateTime.now(),
        confidence: confidence,
      );

      print('DEBUG: Saving record to Firestore collection "scans" with ID: $scanId');
      await _firestore.collection('scans').doc(scanId).set(record.toMap());
      print('DEBUG: Record saved successfully');

      // 3. Update patient's last scan date
      print('DEBUG: Updating patient lastScanDate');
      await _firestore.collection('patients').doc(patientId).update({
        'lastScanDate': Timestamp.fromDate(DateTime.now()),
      });
      print('DEBUG: Patient updated successfully');

      return record;
      
    } catch (e) {
      print('ERROR: Failed to save scan result: $e');
      rethrow;
    }
  }

  // Create new patient
  Future<String> createPatient({
    required String name,
    int? age,
    String? phone,
    String? gender,
  }) async {
    try {
      DocumentReference docRef = _firestore.collection('patients').doc();
      await docRef.set({
        'name': name,
        'age': age,
        'phone': phone,
        'gender': gender,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'lastScanDate': null,
      });
      return docRef.id;
    } catch (e) {
      print('Error creating patient: $e');
      rethrow;
    }
  }

  // Update patient details
  Future<void> updatePatient({
    required String id,
    required String name,
    int? age,
    String? phone,
    String? gender,
  }) async {
    try {
      await _firestore.collection('patients').doc(id).update({
        'name': name,
        'age': age,
        'phone': phone,
        'gender': gender,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating patient: $e');
      rethrow;
    }
  }

  // Delete patient and their scans
  Future<void> deletePatient(String patientId) async {
    try {
      // 1. Delete all scans for this patient from Storage and Firestore
      final scansSnapshot = await _firestore.collection('scans')
          .where('patientId', isEqualTo: patientId)
          .get();
      
      for (var doc in scansSnapshot.docs) {
        String scanId = doc.id;
        // Delete from Storage
        try {
          await _storage.ref().child('scans/$scanId.jpg').delete();
        } catch (e) {
          print('Storage delete error: $e');
        }
        // Delete from Firestore
        await _firestore.collection('scans').doc(scanId).delete();
      }

      // 2. Delete patient document
      await _firestore.collection('patients').doc(patientId).delete();
    } catch (e) {
      print('Error deleting patient: $e');
      rethrow;
    }
  }

  // Get all patients
  Stream<List<Patient>> getPatients() {
    return _firestore
        .collection('patients')
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList());
  }

  // Get scans for a specific patient, sorted chronologically in Dart to avoid index issues
  Stream<List<ScanRecord>> getPatientScans(String patientId) {
    return _firestore
        .collection('scans')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          final scans = snapshot.docs.map((doc) => ScanRecord.fromFirestore(doc)).toList();
          scans.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return scans;
        });
  }


  // Stream of recent scans
  Stream<List<ScanRecord>> getRecentScans() {
    return _firestore
        .collection('scans')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ScanRecord.fromFirestore(doc)).toList());
  }

  // Stream of all scans for dashboard counts
  Stream<List<ScanRecord>> getAllScans() {
    return _firestore
        .collection('scans')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ScanRecord.fromFirestore(doc)).toList());
  }
}
