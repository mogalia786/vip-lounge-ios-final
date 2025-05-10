import '../../../core/enums/user_role.dart';

class PreRegisteredEmployee {
  final String employeeNumber;
  final UserRole assignedRole;
  final bool isActive;

  PreRegisteredEmployee({
    required this.employeeNumber,
    required this.assignedRole,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeNumber': employeeNumber,
      'assignedRole': assignedRole.name,
      'isActive': isActive,
    };
  }

  factory PreRegisteredEmployee.fromMap(Map<String, dynamic> map) {
    return PreRegisteredEmployee(
      employeeNumber: map['employeeNumber'],
      assignedRole: UserRole.values.firstWhere(
        (role) => role.name == map['assignedRole'],
      ),
      isActive: map['isActive'] ?? true,
    );
  }
}
