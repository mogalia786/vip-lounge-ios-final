import 'package:cloud_firestore/cloud_firestore.dart';

/// Fetches the average rating for a given appointment or query and senderId.
Future<double?> fetchAverageRatingForStaff({
  String? appointmentId,
  String? queryId,
  required String senderId,
}) async {
  Query ratingsQuery = FirebaseFirestore.instance.collection('ratings');
  if (appointmentId != null && appointmentId.isNotEmpty) {
    ratingsQuery = ratingsQuery.where('appointmentId', isEqualTo: appointmentId);
  }
  if (queryId != null && queryId.isNotEmpty) {
    ratingsQuery = ratingsQuery.where('queryId', isEqualTo: queryId);
  }
  ratingsQuery = ratingsQuery.where('senderId', isEqualTo: senderId);
  final snapshot = await ratingsQuery.get();
  if (snapshot.docs.isEmpty) return null;
  double total = 0;
  for (final doc in snapshot.docs) {
    final rating = doc['rating'];
    if (rating is int) {
      total += rating.toDouble();
    } else if (rating is double) {
      total += rating;
    }
  }
  return total / snapshot.docs.length;
}

/// Fetches the latest rating for a given appointment or query and senderId.
Future<int?> fetchLatestRatingForStaff({
  String? appointmentId,
  String? queryId,
  required String senderId,
}) async {
  Query ratingsQuery = FirebaseFirestore.instance.collection('ratings');
  if (appointmentId != null && appointmentId.isNotEmpty) {
    ratingsQuery = ratingsQuery.where('appointmentId', isEqualTo: appointmentId);
  }
  if (queryId != null && queryId.isNotEmpty) {
    ratingsQuery = ratingsQuery.where('queryId', isEqualTo: queryId);
  }
  ratingsQuery = ratingsQuery.where('senderId', isEqualTo: senderId).orderBy('timestamp', descending: true).limit(1);
  final snapshot = await ratingsQuery.get();
  if (snapshot.docs.isEmpty) return null;
  final latest = snapshot.docs.first['rating'];
  if (latest is int) return latest;
  if (latest is double) return latest.round();
  return null;
}
