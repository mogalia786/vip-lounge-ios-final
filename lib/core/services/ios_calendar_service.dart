import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'ios_calendar_channel.dart';

class IOSCalendarService {
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
      final ok = await IOSCalendarChannel.addEvent(
        title: title,
        start: start,
        end: end.isAfter(start) ? end : start.add(const Duration(minutes: 30)),
        description: description,
        location: location,
        reminderMinutes: reminder.inMinutes,
      );
      if (!ok) {
        debugPrint('[Calendar][iOS] Failed to insert event via EventKit bridge');
      }
      return ok;
    } catch (e) {
      debugPrint('[Calendar][iOS] Exception adding event: $e');
      return false;
    }
  }
}
