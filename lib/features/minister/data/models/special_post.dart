import 'package:cloud_firestore/cloud_firestore.dart';

class SpecialPost {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String validUntil;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  SpecialPost({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.validUntil,
    required this.createdAt,
    required this.createdBy,
    required this.isActive,
  });

  factory SpecialPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SpecialPost(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      validUntil: data['validUntil'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'validUntil': validUntil,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }
}
