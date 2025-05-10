import 'package:flutter/material.dart';
import 'package:vip_lounge/features/floor_manager/widgets/attendance_actions_widget.dart';

class ConsultantAttendanceSection extends StatelessWidget {
  final String userId;
  final String name;
  final String role;
  const ConsultantAttendanceSection({
    Key? key,
    required this.userId,
    required this.name,
    required this.role,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: AttendanceActionsWidget(
        userId: userId,
        name: name,
        role: role,
      ),
    );
  }
}
