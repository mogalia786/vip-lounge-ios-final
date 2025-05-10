import 'package:flutter/material.dart';

class ConsultantScheduleSection extends StatelessWidget {
  final Widget scheduleWidget;
  const ConsultantScheduleSection({
    Key? key,
    required this.scheduleWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: scheduleWidget,
    );
  }
}
