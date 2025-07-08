import '../../../../core/enums/user_role.dart';

class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final UserRole role;
  final String? employeeNumber;
  final String? fcmToken;
  final String? clientType; // For minister users, stores their type (e.g., 'influencer_celebrity', 'corporate_executive')

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.employeeNumber,
    this.fcmToken,
    this.clientType,
  });
  
  // Helper to check if user is a minister
  bool get isMinister => role == UserRole.minister;

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.name, // Keep original role name
      'employeeNumber': employeeNumber,
      'fcmToken': fcmToken,
      if (clientType != null) 'clientType': clientType,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Keep the original role name
    final roleName = map['role']?.toString().toLowerCase() ?? '';
    
    return UserModel(
      uid: map['uid'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (role) => role.name.toLowerCase() == roleName,
        orElse: () => UserRole.minister, // Default to minister if role not found
      ),
      employeeNumber: map['employeeNumber'] as String?,
      fcmToken: map['fcmToken'] as String?,
      clientType: map['clientType'] as String?,
    );
  }
  
  // Create a copyWith method for easy updates
  UserModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? employeeNumber,
    String? fcmToken,
    String? clientType,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      fcmToken: fcmToken ?? this.fcmToken,
      clientType: clientType ?? this.clientType,
    );
  }
}
