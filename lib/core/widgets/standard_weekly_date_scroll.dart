import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';

class StandardWeeklyDateScroll extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChange;
  final int daysToShow;
  final DateTime? startDate;

  const StandardWeeklyDateScroll({
    Key? key,
    required this.selectedDate,
    required this.onDateChange,
    this.daysToShow = 30,
    this.startDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DateTime baseStart = startDate ?? DateTime.now().subtract(const Duration(days: 1));
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(daysToShow, (i) {
            final date = baseStart.add(Duration(days: i));
            final isSelected = selectedDate.year == date.year && selectedDate.month == date.month && selectedDate.day == date.day;
            return GestureDetector(
              onTap: () => onDateChange(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(colors: [Colors.amber.shade400, Colors.orange.shade700])
                      : LinearGradient(colors: [Colors.black87, Colors.grey.shade800]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.amber.withOpacity(0.25), blurRadius: 12, offset: Offset(0, 2))]
                      : [],
                  border: isSelected ? Border.all(color: Colors.deepOrange, width: 3) : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('EEE').format(date),
                      style: TextStyle(
                        color: isSelected ? Colors.deepOrange : Colors.amber.shade200,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        color: isSelected ? Colors.amber[900] : Colors.amber[100],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
