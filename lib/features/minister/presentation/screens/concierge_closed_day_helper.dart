import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Helper class to fetch closed days and business hours for all roles
class ClosedDayHelper {
  static Map<String, dynamic>? _businessHoursMap;
  static Set<String> _closedDaysSet = {};
  static bool _loaded = false;

  /// Fetch closed days and business hours from Firestore (singleton)
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final doc = await FirebaseFirestore.instance.collection('business').doc('settings').get();
    final data = doc.data();
    Map<String, dynamic> businessHoursMap = {};
    if (data != null) {
      for (final weekday in ['sun','mon','tue','wed','thu','fri','sat']) {
        if (data.containsKey(weekday) && data[weekday] is Map) {
          businessHoursMap[weekday] = data[weekday];
        }
      }
      _businessHoursMap = businessHoursMap;
    }
    // Fetch closedDays subcollection for public holidays
    final closedDaysSnap = await FirebaseFirestore.instance.collection('business').doc('settings').collection('closedDays').get();
    _closedDaysSet = closedDaysSnap.docs.map((doc) => doc.id).toSet();
    _loaded = true;
  }

  /// Helper to get abbreviated weekday key (e.g., 'mon', 'tue', ...)
  static String weekdayKey(DateTime date) {
    const keys = ['sun','mon','tue','wed','thu','fri','sat'];
    return keys[date.weekday % 7];
  }

  /// Returns true if the date is closed (by weekday or by special day)
  static bool isDateClosed(DateTime date) {
    final String dayKey = weekdayKey(date);
    if (_businessHoursMap != null && _businessHoursMap![dayKey] is Map) {
      final dayInfo = _businessHoursMap![dayKey];
      if (dayInfo['closed'] == true) return true;
    }
    // Check if the date is a public holiday or special closed day (from closedDays subcollection)
    return _closedDaysSet.contains(DateFormat('yyyy-MM-dd').format(date));
  }
}
