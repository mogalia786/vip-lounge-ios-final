import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/service_options.dart';
import '../../../../core/constants/colors.dart';
import '../screens/time_slot_selection_screen.dart';

class TimeSlotCalendar extends StatefulWidget {
  final Service selectedService;
  final VenueType selectedVenue;
  final String serviceCategory;
  final String? subServiceName;
  final Function(DateTime) onTimeSelected;

  const TimeSlotCalendar({
    Key? key,
    required this.selectedService,
    required this.selectedVenue,
    required this.serviceCategory,
    this.subServiceName,
    required this.onTimeSelected,
  }) : super(key: key);

  @override
  State<TimeSlotCalendar> createState() => _TimeSlotCalendarState();
}

class _TimeSlotCalendarState extends State<TimeSlotCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<List<String>> _fetchClosedDays() async {
    final doc = await FirebaseFirestore.instance.collection('business').doc('settings').get();
    final data = doc.data();
    if (data != null && data['closedDays'] != null) {
      return List<String>.from(data['closedDays']);
    }
    return [];
  }

  bool _isDateSelectable(DateTime day, List<String> closedDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(day.year, day.month, day.day);
    if (date.isBefore(today)) return false;
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (closedDays.contains(dateStr)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _fetchClosedDays(),
      builder: (context, snapshot) {
        final closedDays = snapshot.data ?? [];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => _selectedDay != null && isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              enabledDayPredicate: (day) => _isDateSelectable(day, closedDays),
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                titleTextStyle: TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.gold),
                rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.gold),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: TextStyle(color: AppColors.gold),
                weekendTextStyle: TextStyle(color: AppColors.gold),
                outsideTextStyle: TextStyle(color: AppColors.gold.withOpacity(0.5)),
                disabledTextStyle: TextStyle(color: AppColors.gold.withOpacity(0.2)),
                holidayTextStyle: TextStyle(color: AppColors.gold),
                selectedTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                todayTextStyle: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                if (_isDateSelectable(selectedDay, closedDays)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });

                  // Navigate to a full screen instead of showing a bottom sheet
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (context) => TimeSlotSelectionScreen(
                        selectedDate: selectedDay,
                        venueId: widget.selectedVenue.id,
                        venueName: widget.selectedVenue.name,
                        serviceDuration: widget.selectedService.maxDuration,
                        selectedService: widget.selectedService,
                        selectedVenue: widget.selectedVenue,
                        serviceCategory: widget.serviceCategory,
                        subServiceName: widget.subServiceName,
                        onTimeSelected: (selectedTime) {
                          widget.onTimeSelected(selectedTime);
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        ministerFirstName: '',
                        ministerLastName: '',
                        ministerPhoneNumber: '',
                        ministerId: '',
                      ),
                    ),
                  );
                }
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: CircularProgressIndicator(),
              ),
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Error loading closed days', style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      },
    );
  }
}
