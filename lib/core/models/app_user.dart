import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String uid;
  final String role;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? clientType; // For minister users, stores their type (e.g., 'influencer_celebrity', 'corporate_executive')

  AppUser({
    required this.uid,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.clientType,
  });

  String get name => '$firstName $lastName';
  String get fullName => '$firstName $lastName';
  String get id => uid;
  
  // Helper to check if user is a minister
  bool get isMinister => role == 'minister';

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      role: map['role'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      clientType: map['clientType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      if (clientType != null) 'clientType': clientType,
    };
  }
  
  // Create a copyWith method for easy updates
  AppUser copyWith({
    String? uid,
    String? role,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? clientType,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      clientType: clientType ?? this.clientType,
    );
  }
}
