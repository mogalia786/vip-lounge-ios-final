import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String ministerUid;
  final String ministerName;
  final String category;
  final String service;
  final String? subService;
  final String venue;
  final String venueId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? notes;
  final String? assignedConsultantId;
  final String? assignedCleanerId;
  final String? assignedConciergeId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Appointment({
    required this.id,
    required this.ministerUid,
    required this.ministerName,
    required this.category,
    required this.service,
    this.subService,
    required this.venue,
    required this.venueId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
    this.assignedConsultantId,
    this.assignedCleanerId,
    this.assignedConciergeId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      ministerUid: data['ministerUid'],
      ministerName: data['ministerName'],
      category: data['category'],
      service: data['service'],
      subService: data['subService'],
      venue: data['venue'],
      venueId: data['venueId'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: data['status'],
      notes: data['notes'],
      assignedConsultantId: data['assignedConsultantId'],
      assignedCleanerId: data['assignedCleanerId'],
      assignedConciergeId: data['assignedConciergeId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ministerUid': ministerUid,
      'ministerName': ministerName,
      'category': category,
      'service': service,
      'subService': subService,
      'venue': venue,
      'venueId': venueId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status,
      'notes': notes,
      'assignedConsultantId': assignedConsultantId,
      'assignedCleanerId': assignedCleanerId,
      'assignedConciergeId': assignedConciergeId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Appointment copyWith({
    String? id,
    String? ministerUid,
    String? ministerName,
    String? category,
    String? service,
    String? subService,
    String? venue,
    String? venueId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? notes,
    String? assignedConsultantId,
    String? assignedCleanerId,
    String? assignedConciergeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      ministerUid: ministerUid ?? this.ministerUid,
      ministerName: ministerName ?? this.ministerName,
      category: category ?? this.category,
      service: service ?? this.service,
      subService: subService ?? this.subService,
      venue: venue ?? this.venue,
      venueId: venueId ?? this.venueId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      assignedConsultantId: assignedConsultantId ?? this.assignedConsultantId,
      assignedCleanerId: assignedCleanerId ?? this.assignedCleanerId,
      assignedConciergeId: assignedConciergeId ?? this.assignedConciergeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
