const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Set your business closing hour (24h format, e.g., 19 for 7pm)
const BUSINESS_CLOSE_HOUR = 19;

exports.autoClockOut = functions.pubsub.schedule('0 19 * * *') // 7pm daily
    .timeZone('Europe/Berlin') // Adjust to your business timezone
    .onRun(async (context) => {
  const attendanceRef = admin.firestore().collection('attendance');
  const snapshot = await attendanceRef.where('isClockedIn', '==', true).get();
  const now = admin.firestore.Timestamp.now();

  const batch = admin.firestore().batch();
  snapshot.forEach(doc => {
    batch.update(doc.ref, {
      isClockedIn: false,
      clockOutTime: now,
      isOnBreak: false,
      breakReason: null,
      breakStartTime: null,
      breakEndTime: null,
    });
    // Optionally, add to history subcollection
    doc.ref.collection('history').add({
      event: 'auto_clock_out',
      timestamp: now,
      name: doc.data().name,
      role: doc.data().role,
      userId: doc.data().userId,
    });
  });
  await batch.commit();
  console.log('Auto clock-out completed for all still clocked-in users.');
  return null;
});
