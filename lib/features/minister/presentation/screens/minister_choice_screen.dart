import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'appointment_booking_screen.dart';
import 'query_screen.dart';

class MinisterChoiceScreen extends StatelessWidget {
  const MinisterChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'VIP Lounge',
          style: TextStyle(color: AppColors.gold),
        ),
        iconTheme: IconThemeData(color: AppColors.gold),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How can we assist you?',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildChoiceButton(
              context,
              'Book Appointment',
              Icons.calendar_today,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppointmentBookingScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChoiceButton(
              context,
              'Submit Query',
              Icons.help_outline,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QueryScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 20),
        side: BorderSide(color: AppColors.gold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
