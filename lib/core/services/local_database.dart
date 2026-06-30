import 'package:hive_flutter/hive_flutter.dart';
import '../../models/patient.dart';
import '../../models/scan_record.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static const String patientsBoxName = 'patients';
  static const String scansBoxName = 'scans';
  static const String pendingSyncBoxName = 'pending_sync';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(patientsBoxName);
    await Hive.openBox(scansBoxName);
    await Hive.openBox(pendingSyncBoxName);
  }

  Box get _patientsBox => Hive.box(patientsBoxName);
  Box get _scansBox => Hive.box(scansBoxName);
  Box get _pendingSyncBox => Hive.box(pendingSyncBoxName);

  // ---------------------------------------------------------------------------
  // Patients Operations
  // ---------------------------------------------------------------------------

  Future<void> savePatient(Patient patient) async {
    await _patientsBox.put(patient.id, patient.toLocalMap());
  }

  List<Patient> getAllPatients() {
    final list = _patientsBox.values
        .map((map) => Patient.fromLocalMap(Map<dynamic, dynamic>.from(map as Map)))
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Patient? getPatient(String id) {
    final map = _patientsBox.get(id);
    if (map == null) return null;
    return Patient.fromLocalMap(Map<dynamic, dynamic>.from(map as Map));
  }

  Future<void> deletePatient(String id) async {
    await _patientsBox.delete(id);
    
    // Clean up related scans locally
    final scans = getAllScans().where((s) => s.patientId == id);
    for (var scan in scans) {
      await deleteScan(scan.id);
    }
    
    // Clean up pending sync for the patient
    await removeFromPendingSync(id);
  }

  // ---------------------------------------------------------------------------
  // Scans Operations
  // ---------------------------------------------------------------------------

  Future<void> saveScan(ScanRecord scan) async {
    await _scansBox.put(scan.id, scan.toLocalMap());
  }

  List<ScanRecord> getAllScans() {
    final list = _scansBox.values
        .map((map) => ScanRecord.fromLocalMap(Map<dynamic, dynamic>.from(map as Map)))
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  List<ScanRecord> getPatientScans(String patientId) {
    return getAllScans().where((s) => s.patientId == patientId).toList();
  }

  List<ScanRecord> getRecentScans({int limit = 10}) {
    final scans = getAllScans();
    if (scans.length <= limit) return scans;
    return scans.sublist(0, limit);
  }

  ScanRecord? getScan(String id) {
    final map = _scansBox.get(id);
    if (map == null) return null;
    return ScanRecord.fromLocalMap(Map<dynamic, dynamic>.from(map as Map));
  }

  Future<void> deleteScan(String id) async {
    await _scansBox.delete(id);
    await removeFromPendingSync(id);
  }

  // ---------------------------------------------------------------------------
  // Pending Sync Operations
  // ---------------------------------------------------------------------------

  Future<void> addToPendingSync(String id, String type) async {
    await _pendingSyncBox.put(id, type);
  }

  Future<void> removeFromPendingSync(String id) async {
    await _pendingSyncBox.delete(id);
  }

  Map<String, String> getPendingSyncItems() {
    final Map<String, String> items = {};
    for (var key in _pendingSyncBox.keys) {
      items[key.toString()] = _pendingSyncBox.get(key).toString();
    }
    return items;
  }

  // ---------------------------------------------------------------------------
  // Listeners for UI state updates (ValueListenable)
  // ---------------------------------------------------------------------------

  dynamic getPatientsListenable() => _patientsBox.listenable();
  dynamic getScansListenable() => _scansBox.listenable();
  dynamic getPendingSyncListenable() => _pendingSyncBox.listenable();
}
