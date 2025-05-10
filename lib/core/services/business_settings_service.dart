import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessSettingsService {
  static const String settingsPath = 'business/settings';

  /// Fetches the startOfDay time (as a string, e.g., '08:00') from Firestore business/settings.
  static Future<TimeOfDay?> fetchStartOfDay() async {
    final doc = await FirebaseFirestore.instance.doc(settingsPath).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || !data.containsKey('startOfDay')) return null;
    final startOfDayStr = data['startOfDay'];
    if (startOfDayStr is String && startOfDayStr.contains(':')) {
      final parts = startOfDayStr.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }
}
