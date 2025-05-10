class Venue {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final bool isAvailable;
  final int cleaningBuffer;  // in minutes
  final String address;  // Added address field

  const Venue({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.address,  // Added to constructor
    this.isAvailable = true,
    this.cleaningBuffer = 30,  // default 30 minutes cleaning time
  });

  factory Venue.fromMap(Map<String, dynamic> map) {
    return Venue(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      imageUrl: map['imageUrl'] as String,
      address: map['address'] as String,  // Added to fromMap
      isAvailable: map['isAvailable'] as bool? ?? true,
      cleaningBuffer: map['cleaningBuffer'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'address': address,  // Added to toMap
      'isAvailable': isAvailable,
      'cleaningBuffer': cleaningBuffer,
    };
  }
}
