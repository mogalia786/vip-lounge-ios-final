class ServiceModel {
  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final double price;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.price,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      durationMinutes: map['durationMinutes'] as int,
      price: (map['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'durationMinutes': durationMinutes,
      'price': price,
    };
  }
}
