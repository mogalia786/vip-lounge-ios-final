import 'dart:io' show Platform;
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class IOSCalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<bool> addBookingToCalendar({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
    Duration reminder = const Duration(minutes: 30),
  }) async {
    try {
      if (kIsWeb || !Platform.isIOS) {
        debugPrint('[Calendar][iOS] Skipping calendar insert on non-iOS platform');
        return false;
      }

      // Request permissions
      final perms = await _deviceCalendarPlugin.hasPermissions();
      if (!(perms.data ?? false)) {
        final req = await _deviceCalendarPlugin.requestPermissions();
        if (!(req.data ?? false)) {
          debugPrint('[Calendar][iOS] Permission denied');
          return false;
        }
      }

      // Retrieve calendars and choose a writable one
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      final calendars = calendarsResult?.data ?? [];
      final Calendar? targetCal = calendars.firstWhere(
        (c) => (c.isReadOnly ?? true) == false,
        orElse: () => calendars.isNotEmpty ? calendars.first : Calendar('0'),
      );

      if (targetCal == null || (targetCal.isReadOnly ?? true)) {
        debugPrint('[Calendar][iOS] No writable calendar found');
        return false;
      }

      final event = Event(
        targetCal.id,
        title: title,
        start: start,
        end: end.isAfter(start) ? end : start.add(const Duration(minutes: 30)),
        description: description,
        location: location,
      );

      // Add a reminder/alarm
      if (reminder.inMinutes > 0) {
        event.reminders = [Reminder(minutes: reminder.inMinutes)];
      }

      final createResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      final success = createResult?.isSuccess ?? false;
      if (!success) {
        debugPrint('[Calendar][iOS] Failed to insert event: ${createResult?.errors}');
      }
      return success;
    } catch (e) {
      debugPrint('[Calendar][iOS] Exception adding event: $e');
      return false;
    }
  }
}
