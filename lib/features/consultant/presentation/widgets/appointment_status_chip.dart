import 'package:flutter/material.dart';
import 'package:vip_lounge/core/constants/colors.dart';

class AppointmentStatusChip extends StatelessWidget {
  final String status;
  
  const AppointmentStatusChip({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor = Colors.white;
    String label;
    
    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange;
        label = 'Pending';
        break;
      case 'in-progress':
        backgroundColor = Colors.green;
        label = 'In Progress';
        break;
      case 'completed':
        backgroundColor = Colors.blue;
        label = 'Completed';
        break;
      case 'cancelled':
        backgroundColor = AppColors.primary;
        label = 'Cancelled';
        break;
      default:
        backgroundColor = Colors.grey;
        label = status.isNotEmpty ? status.substring(0, 1).toUpperCase() + status.substring(1) : 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
