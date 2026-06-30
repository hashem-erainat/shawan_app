import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/scan_record.dart';
import '../../models/patient.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload scan initially in "pending" status
  Future<ScanRecord> uploadScan(
    File imageFile,
    String patientId,
    String patientName,
  ) async {
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

      final String currentUid = _auth.currentUser?.uid ?? 'dummy_user_123';

      // 2. Create record in Firestore in pending status
      ScanRecord record = ScanRecord(
        id: scanId,
        userId: currentUid,
        patientId: patientId,
        patientName: patientName,
        status: ScanStatus.pending,
        timestamp: DateTime.now(),
        leftImageUrl: '',
        leftStage: null,
        leftResultLabel: null,
        leftConfidence: null,
        rightImageUrl: imageUrl,
        rightStage: null,
        rightResultLabel: null,
        rightConfidence: null,
      );

      print(
        'DEBUG: Saving record to Firestore collection "scans" with ID: $scanId',
      );
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

  // Listen to a specific scan document in real-time
  Stream<ScanRecord> listenToScan(String scanId) {
    return _firestore
        .collection('scans')
        .doc(scanId)
        .snapshots()
        .map((snapshot) => ScanRecord.fromFirestore(snapshot));
  }

  // Get dynamic doctor profile details
  Future<Map<String, dynamic>?> getDoctorProfile(String uid) async {
    try {
      final doc = await _firestore.collection('doctors').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Error getting doctor profile: $e');
      return null;
    }
  }

  // Update doctor profile details
  Future<void> updateDoctorProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    try {
      await _firestore.collection('doctors').doc(uid).update({
        'name': name,
        'phone': phone,
      });
    } catch (e) {
      print('Error updating doctor profile: $e');
      rethrow;
    }
  }

  // Helper method to just upload image (used in custom flows if needed)
  Future<String> uploadImageOnly(File imageFile, String scanId) async {
    final Reference storageRef = _storage.ref().child('scans/$scanId.jpg');
    final UploadTask uploadTask = storageRef.putFile(imageFile);
    final TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
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
      final scansSnapshot = await _firestore
          .collection('scans')
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
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList(),
        );
  }

  // Get scans for a specific patient, sorted chronologically in Dart to avoid index issues
  Stream<List<ScanRecord>> getPatientScans(String patientId) {
    return _firestore
        .collection('scans')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          final scans = snapshot.docs
              .map((doc) => ScanRecord.fromFirestore(doc))
              .toList();
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScanRecord.fromFirestore(doc))
              .toList(),
        );
  }

  // Stream of all scans for dashboard counts
  Stream<List<ScanRecord>> getAllScans() {
    return _firestore
        .collection('scans')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScanRecord.fromFirestore(doc))
              .toList(),
        );
  }
}
