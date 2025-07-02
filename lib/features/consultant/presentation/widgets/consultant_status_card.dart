import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';

class ConsultantStatusCard extends StatelessWidget {
  final String name;
  final bool isClockedIn;
  final DateTime? clockInTime;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;
  final VoidCallback onManageBreak;

  const ConsultantStatusCard({
    Key? key,
    required this.name,
    required this.isClockedIn,
    this.clockInTime,
    required this.onClockIn,
    required this.onClockOut,
    required this.onManageBreak,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen width to make layout responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 360;
    
    return Card(
      color: Colors.black,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isClockedIn)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            
            // Use a vertical layout on narrow screens, otherwise horizontal
            isNarrowScreen 
                ? _buildVerticalLayout()
                : _buildHorizontalLayout(),
          ],
        ),
      ),
    );
  }
  
  // Vertical layout for narrow screens
  Widget _buildVerticalLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status info
        Text(
          'Status: ${isClockedIn ? "Active" : "Inactive"}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        if (clockInTime != null)
          Text(
            'Since: ${DateFormat('h:mm a').format(clockInTime!)}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          
        SizedBox(height: 16),
        
        // Action buttons in a row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Clock in/out button
            ElevatedButton(
              onPressed: isClockedIn ? onClockOut : onClockIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: isClockedIn ? Colors.red : Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                isClockedIn ? 'Clock Out' : 'Clock In',
                style: TextStyle(color: Colors.white),
              ),
            ),
            
            // Break management button (only shown when clocked in)
            if (isClockedIn)
              ElevatedButton(
                onPressed: onManageBreak,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  'Manage Break',
                  style: TextStyle(color: Colors.black),
                ),
              ),
          ],
        ),
      ],
    );
  }
  
  // Horizontal layout for wider screens
  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        // Left column - Status info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${isClockedIn ? "Active" : "Inactive"}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              if (clockInTime != null)
                Text(
                  'Since: ${DateFormat('h:mm a').format(clockInTime!)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
        
        // Right column - Action buttons
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Clock in/out button
            ElevatedButton(
              onPressed: isClockedIn ? onClockOut : onClockIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: isClockedIn ? Colors.red : Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                isClockedIn ? 'Clock Out' : 'Clock In',
                style: TextStyle(color: Colors.white),
              ),
            ),
            
            // Break management button (only shown when clocked in)
            if (isClockedIn)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: onManageBreak,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    'Manage Break',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
