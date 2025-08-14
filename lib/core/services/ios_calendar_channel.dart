import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class IOSCalendarChannel {
  static const MethodChannel _channel = MethodChannel('com.vip/calendar');

  static Future<bool> addEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
    int reminderMinutes = 15,
  }) async {
    if (!Platform.isIOS) return false;
    try {
      final bool ok = await _channel.invokeMethod('addEvent', {
        'title': title,
        'description': description,
        'location': location,
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
        'reminderMinutes': reminderMinutes,
      });
      return ok;
    } on PlatformException catch (e) {
      // Log and return false; UI can decide to inform user.
      // ignore: avoid_print
      print('[IOSCalendarChannel] PlatformException: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[IOSCalendarChannel] Error: $e');
      return false;
    }
  }
}
