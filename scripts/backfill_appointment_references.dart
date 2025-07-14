import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Initialize Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  print('Starting appointment reference backfill...');
  await backfillAppointmentReferences();
  print('Backfill completed!');
}

Future<void> backfillAppointmentReferences() async {
  final firestore = FirebaseFirestore.instance;
  final batchSize = 100;
  int processed = 0;
  
  // Query all appointments that don't have a reference number
  var query = firestore
      .collection('appointments')
      .where('referenceNumber', isNull: true)
      .limit(batchSize);
  
  while (true) {
    final snapshot = await query.get();
    
    if (snapshot.docs.isEmpty) {
      print('No more appointments to process');
      break;
    }
    
    final batch = firestore.batch();
    
    for (final doc in snapshot.docs) {
      final referenceNumber = generateReferenceNumber();
      batch.update(doc.reference, {'referenceNumber': referenceNumber});
      print('Added reference $referenceNumber to appointment ${doc.id}');
    }
    
    await batch.commit();
    processed += snapshot.docs.length;
    print('Processed $processed appointments');
    
    // If we got less than the batch size, we're done
    if (snapshot.docs.length < batchSize) {
      break;
    }
    
    // Get the last document for pagination
    final lastDoc = snapshot.docs.last;
    query = firestore
        .collection('appointments')
        .where('referenceNumber', isNull: true)
        .startAfterDocument(lastDoc)
        .limit(batchSize);
  }
}

String generateReferenceNumber({int length = 5}) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random.secure();
  return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
}
