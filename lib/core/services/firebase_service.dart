import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/scan_record.dart';
import '../../models/patient.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload scan and simulate AI processing
  Future<void> uploadScan(File imageFile, String patientId, String patientName) async {
    try {
      String scanId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 1. Upload to Storage
      Reference ref = _storage.ref().child('scans/$scanId.jpg');
      await ref.putFile(imageFile);
      String imageUrl = await ref.getDownloadURL();

      // 2. Create initial record in Firestore
      ScanRecord record = ScanRecord(
        id: scanId,
        userId: 'dummy_user_123', // In real app, get from FirebaseAuth
        patientId: patientId,
        patientName: patientName,
        imageUrl: imageUrl,
        status: ScanStatus.pending,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('scans').doc(scanId).set(record.toMap());

      // 3. Update patient's last scan date
      await _firestore.collection('patients').doc(patientId).update({
        'lastScanDate': Timestamp.fromDate(DateTime.now()),
      });

      // 4. Simulate AI delay and result (Dummy Data Logic)
      _simulateAIProcessing(scanId);
      
    } catch (e) {
      print('Error uploading scan: $e');
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

  // Get scans for a specific patient
  Stream<List<ScanRecord>> getPatientScans(String patientId) {
    return _firestore
        .collection('scans')
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ScanRecord.fromFirestore(doc)).toList());
  }

  void _simulateAIProcessing(String scanId) async {
    // Wait for 5 seconds to simulate processing
    await Future.delayed(const Duration(seconds: 5));

    // Generate random dummy result
    int stage = Random().nextInt(5); // 0 to 4
    List<String> labels = ['No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative'];
    
    await _firestore.collection('scans').doc(scanId).update({
      'status': 'completed',
      'stage': stage,
      'resultLabel': labels[stage],
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
}
