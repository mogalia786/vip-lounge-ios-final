import 'package:cloud_firestore/cloud_firestore.dart';

class SocialFeedPostModel {
  final String id;
  final String agentId;
  final String agentName;
  final String type; // Specials, Data Bundle Special, etc.
  final DateTime beginDate;
  final DateTime expirationDate;
  final String details;
  final String telephoneNumber;
  final String termsAndConditions;
  final List<String> imageUrls;
  final Timestamp createdAt;
  final int likeCount;

  SocialFeedPostModel({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.type,
    required this.beginDate,
    required this.expirationDate,
    required this.details,
    required this.telephoneNumber,
    required this.termsAndConditions,
    required this.imageUrls,
    required this.createdAt,
    required this.likeCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agentId': agentId,
      'agentName': agentName,
      'type': type,
      'beginDate': beginDate,
      'expirationDate': expirationDate,
      'details': details,
      'telephoneNumber': telephoneNumber,
      'termsAndConditions': termsAndConditions,
      'imageUrls': imageUrls,
      'createdAt': createdAt,
      'likeCount': likeCount,
    };
  }

  factory SocialFeedPostModel.fromMap(Map<String, dynamic> map) {
    return SocialFeedPostModel(
      id: map['id'],
      agentId: map['agentId'],
      agentName: map['agentName'],
      type: map['type'],
      beginDate: (map['beginDate'] as Timestamp).toDate(),
      expirationDate: (map['expirationDate'] as Timestamp).toDate(),
      details: map['details'],
      telephoneNumber: map['telephoneNumber'],
      termsAndConditions: map['termsAndConditions'],
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      createdAt: map['createdAt'],
      likeCount: map['likeCount'] ?? 0,
    );
  }
}
