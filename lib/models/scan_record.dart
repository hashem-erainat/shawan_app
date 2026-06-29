import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ScanStatus { pending, completed }

class ScanRecord {
  final String id;
  final String userId;
  final String patientId;
  final String patientName;
  final ScanStatus status;
  final DateTime timestamp;
  
  // Left eye details
  final String leftImageUrl;
  final int? leftStage;
  final String? leftResultLabel;
  final double? leftConfidence;

  // Right eye details
  final String rightImageUrl;
  final int? rightStage;
  final String? rightResultLabel;
  final double? rightConfidence;

  ScanRecord({
    required this.id,
    required this.userId,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.timestamp,
    required this.leftImageUrl,
    this.leftStage,
    this.leftResultLabel,
    this.leftConfidence,
    required this.rightImageUrl,
    this.rightStage,
    this.rightResultLabel,
    this.rightConfidence,
  });

  // --- Helper Compatibility Getters ---
  String get imageUrl => rightImageUrl.isNotEmpty ? rightImageUrl : leftImageUrl;
  
  int? get stage {
    if (leftStage == null) return rightStage;
    if (rightStage == null) return leftStage;
    return max(leftStage!, rightStage!);
  }

  String? get resultLabel {
    if (leftStage == null) return rightResultLabel;
    if (rightStage == null) return leftResultLabel;
    return leftStage! >= rightStage! ? leftResultLabel : rightResultLabel;
  }

  double? get confidence {
    if (leftStage == null) return rightConfidence;
    if (rightStage == null) return leftConfidence;
    return leftStage! >= rightStage! ? leftConfidence : rightConfidence;
  }

  factory ScanRecord.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    
    // Check if it is a dual scan, otherwise fallback to single scan fields
    final String leftImg = data['leftImageUrl'] ?? '';
    final String rightImg = data['rightImageUrl'] ?? data['imageUrl'] ?? '';
    
    return ScanRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? 'Unknown',
      status: data['status'] == 'completed' ? ScanStatus.completed : ScanStatus.pending,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      leftImageUrl: leftImg,
      leftStage: data['leftStage'],
      leftResultLabel: data['leftResultLabel'],
      leftConfidence: (data['leftConfidence'] as num?)?.toDouble(),
      rightImageUrl: rightImg,
      rightStage: data['rightStage'] ?? data['stage'],
      rightResultLabel: data['rightResultLabel'] ?? data['resultLabel'],
      rightConfidence: (data['rightConfidence'] as num? ?? data['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'patientId': patientId,
      'patientName': patientName,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'leftImageUrl': leftImageUrl,
      'leftStage': leftStage,
      'leftResultLabel': leftResultLabel,
      'leftConfidence': leftConfidence,
      'rightImageUrl': rightImageUrl,
      'rightStage': rightStage,
      'rightResultLabel': rightResultLabel,
      'rightConfidence': rightConfidence,
      // Include old fields for backend compat
      'imageUrl': imageUrl,
      'stage': stage,
      'resultLabel': resultLabel,
      'confidence': confidence,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'userId': userId,
      'patientId': patientId,
      'patientName': patientName,
      'status': status.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'leftImageUrl': leftImageUrl,
      'leftStage': leftStage,
      'leftResultLabel': leftResultLabel,
      'leftConfidence': leftConfidence,
      'rightImageUrl': rightImageUrl,
      'rightStage': rightStage,
      'rightResultLabel': rightResultLabel,
      'rightConfidence': rightConfidence,
      // Include old fields for local compat
      'imageUrl': imageUrl,
      'stage': stage,
      'resultLabel': resultLabel,
      'confidence': confidence,
    };
  }

  factory ScanRecord.fromLocalMap(Map<dynamic, dynamic> map) {
    final String leftImg = map['leftImageUrl'] as String? ?? '';
    final String rightImg = map['rightImageUrl'] as String? ?? map['imageUrl'] as String? ?? '';

    return ScanRecord(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      patientName: map['patientName'] as String? ?? 'Unknown',
      status: map['status'] == 'completed' || map['status'] == 'ScanStatus.completed'
          ? ScanStatus.completed
          : ScanStatus.pending,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      leftImageUrl: leftImg,
      leftStage: map['leftStage'] as int?,
      leftResultLabel: map['leftResultLabel'] as String?,
      leftConfidence: (map['leftConfidence'] as num?)?.toDouble(),
      rightImageUrl: rightImg,
      rightStage: map['rightStage'] as int? ?? map['stage'] as int?,
      rightResultLabel: map['rightResultLabel'] as String? ?? map['resultLabel'] as String?,
      rightConfidence: (map['rightConfidence'] as num? ?? map['confidence'] as num?)?.toDouble(),
    );
  }

  List<String> getRecommendations() {
    return getRecommendationsForStage(stage ?? 0);
  }

  static List<String> getRecommendationsForStage(int currentStage) {
    switch (currentStage) {
      case 0:
        return [
          'Schedule your regular eye check-up once every year to keep tracking your eye health.',
          'Keep your blood sugar numbers stable and within your healthy target range.',
          'Check and control your blood pressure regularly to protect your eyes.',
          'Keep your cholesterol levels at a healthy level by following your doctor\'s plan.',
          'Stay physically active and maintain a healthy diet to support your overall health.',
        ];
      case 1:
        return [
          'Come back for an eye exam every 6 to 12 months so we can monitor your eyes closely.',
          'Work with your doctor to control your cumulative blood sugar (HbA1c) to stop any further changes.',
          'Take your diabetes medications exactly as prescribed and do not skip doses.',
          'Keep a close eye on your blood pressure and cholesterol numbers.',
          'Tell your doctor immediately if you notice any sudden blurriness or changes in your vision.',
        ];
      case 2:
        return [
          'Increase your eye visits to every 3 to 6 months to make sure your eyes stay safe.',
          'Visit an eye specialist (ophthalmologist) for a more detailed look at your eyes.',
          'Talk to your diabetes doctor about adjusting your treatment plan to get better control.',
          'Understand that following your treatment plan now is highly important to protect your sight.',
          'Do not miss your follow-up appointments, even if you feel your vision is completely normal.',
        ];
      case 3:
        return [
          'Go to a retina specialist very soon (within a few weeks) as requested.',
          'Follow your doctors\' instructions carefully because your eyes are at a higher risk now.',
          'Attend all your scheduled check-ups and never delay or skip an appointment.',
          'Avoid making sudden, extreme changes to your blood sugar without your doctor\'s supervision.',
          'Keep emergency contact numbers for your eye clinic handy just in case you need them.',
        ];
      case 4:
      default:
        return [
          'Go to a retina specialist immediately for emergency care to protect your vision.',
          'Start your medical treatments (like eye injections or laser therapy) right away as advised.',
          'Avoid heavy lifting, intense exercise, or bending over until your doctor says it is safe.',
          'Rest as much as possible and follow all daily eye care instructions perfectly.',
          'Ask your family or friends to support you with transportation to your medical appointments.',
        ];
    }
  }
}

