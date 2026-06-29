import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastScanDate;
  final String? phone;
  final int? age;
  final String? gender;

  Patient({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastScanDate,
    this.phone,
    this.age,
    this.gender,
  });

  factory Patient.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Patient(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastScanDate: data['lastScanDate'] != null 
          ? (data['lastScanDate'] as Timestamp).toDate() 
          : null,
      phone: data['phone'],
      age: data['age'],
      gender: data['gender'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastScanDate': lastScanDate != null ? Timestamp.fromDate(lastScanDate!) : null,
      'phone': phone,
      'age': age,
      'gender': gender,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastScanDate': lastScanDate?.millisecondsSinceEpoch,
      'phone': phone,
      'age': age,
      'gender': gender,
    };
  }

  factory Patient.fromLocalMap(Map<dynamic, dynamic> map) {
    return Patient(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      lastScanDate: map['lastScanDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastScanDate'] as int)
          : null,
      phone: map['phone'] as String?,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
    );
  }
}
