import 'package:cloud_firestore/cloud_firestore.dart';

class WorkflowEvent {
  final String id;
  final String appointmentId;
  final String eventType; // booking_created, concierge_started, consultant_started, consultant_ended, concierge_ended
  final String initiatorId;
  final String initiatorRole;
  final String? initiatorName;
  final Map<String, dynamic> eventData; // Additional data specific to the event type
  final Timestamp timestamp;
  final String? notes;
  
  // Staff involved
  final String? ministerId;
  final String? ministerName;
  final String? consultantId;
  final String? consultantName;
  final String? conciergeId;
  final String? conciergeName;
  final String? cleanerId;
  final String? cleanerName;
  final String? floorManagerId;
  final String? floorManagerName;
  
  // Service details
  final String? serviceName;
  final String? venueName;
  final Timestamp? appointmentTime;
  final String? status;
  
  WorkflowEvent({
    required this.id,
    required this.appointmentId,
    required this.eventType,
    required this.initiatorId,
    required this.initiatorRole,
    this.initiatorName,
    required this.eventData,
    required this.timestamp,
    this.notes,
    this.ministerId,
    this.ministerName,
    this.consultantId,
    this.consultantName,
    this.conciergeId,
    this.conciergeName,
    this.cleanerId,
    this.cleanerName,
    this.floorManagerId,
    this.floorManagerName,
    this.serviceName,
    this.venueName,
    this.appointmentTime,
    this.status,
  });
  
  factory WorkflowEvent.fromMap(Map<String, dynamic> data, String id) {
    return WorkflowEvent(
      id: id,
      appointmentId: data['appointmentId'] ?? '',
      eventType: data['eventType'] ?? 'unknown',
      initiatorId: data['initiatorId'] ?? '',
      initiatorRole: data['initiatorRole'] ?? '',
      initiatorName: data['initiatorName'],
      eventData: data['eventData'] ?? {},
      timestamp: data['timestamp'] ?? Timestamp.now(),
      notes: data['notes'],
      ministerId: data['ministerId'],
      ministerName: data['ministerName'],
      consultantId: data['consultantId'],
      consultantName: data['consultantName'],
      conciergeId: data['conciergeId'],
      conciergeName: data['conciergeName'],
      cleanerId: data['cleanerId'],
      cleanerName: data['cleanerName'],
      floorManagerId: data['floorManagerId'],
      floorManagerName: data['floorManagerName'],
      serviceName: data['serviceName'],
      venueName: data['venueName'],
      appointmentTime: data['appointmentTime'],
      status: data['status'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'eventType': eventType,
      'initiatorId': initiatorId,
      'initiatorRole': initiatorRole,
      'initiatorName': initiatorName,
      'eventData': eventData,
      'timestamp': timestamp,
      'notes': notes,
      'ministerId': ministerId,
      'ministerName': ministerName,
      'consultantId': consultantId,
      'consultantName': consultantName,
      'conciergeId': conciergeId,
      'conciergeName': conciergeName,
      'cleanerId': cleanerId,
      'cleanerName': cleanerName,
      'floorManagerId': floorManagerId,
      'floorManagerName': floorManagerName,
      'serviceName': serviceName,
      'venueName': venueName,
      'appointmentTime': appointmentTime,
      'status': status,
    };
  }
}
