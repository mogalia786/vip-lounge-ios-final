class MarketingPost {
  final String id;
  final String imageUrl;
  final String caption;
  final DateTime createdAt;
  final String createdBy;
  final String type; // 'ad' or 'brochure'
  final bool isActive;

  MarketingPost({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.createdAt,
    required this.createdBy,
    required this.type,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'type': type,
      'isActive': isActive,
    };
  }

  factory MarketingPost.fromMap(Map<String, dynamic> map) {
    return MarketingPost(
      id: map['id'],
      imageUrl: map['imageUrl'],
      caption: map['caption'],
      createdAt: DateTime.parse(map['createdAt']),
      createdBy: map['createdBy'],
      type: map['type'],
      isActive: map['isActive'] ?? true,
    );
  }
}
