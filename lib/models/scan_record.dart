import 'package:cloud_firestore/cloud_firestore.dart';

enum ScanStatus { pending, completed }

class ScanRecord {
  final String id;
  final String userId;
  final String patientId;
  final String patientName;
  final String imageUrl;
  final ScanStatus status;
  final int? stage;
  final String? resultLabel;
  final DateTime timestamp;
  final double? confidence;

  ScanRecord({
    required this.id,
    required this.userId,
    required this.patientId,
    required this.patientName,
    required this.imageUrl,
    required this.status,
    this.stage,
    this.resultLabel,
    required this.timestamp,
    this.confidence,
  });

  factory ScanRecord.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return ScanRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? 'Unknown',
      imageUrl: data['imageUrl'] ?? '',
      status: data['status'] == 'completed' ? ScanStatus.completed : ScanStatus.pending,
      stage: data['stage'],
      resultLabel: data['resultLabel'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      confidence: (data['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'patientId': patientId,
      'patientName': patientName,
      'imageUrl': imageUrl,
      'status': status.name,
      'stage': stage,
      'resultLabel': resultLabel,
      'timestamp': Timestamp.fromDate(timestamp),
      'confidence': confidence,
    };
  }
}
