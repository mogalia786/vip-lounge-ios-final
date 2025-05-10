const functions = require('firebase-functions');
const admin = require('firebase-admin');
// admin.initializeApp(); // REMOVED to prevent duplicate-app error

// Scheduled function to auto-clock out all users at midnight
exports.autoClockOutAtMidnight = functions.pubsub
  .schedule('0 0 * * *') // Runs every day at midnight
  .timeZone('Africa/Johannesburg')
  .onRun(async (context) => {
    const now = new Date();
    // Set clock-out time to 23:59:59 of the previous day
    const clockOutTime = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 23, 59, 59);

    const attendanceRef = admin.firestore().collection('attendance');
    // Find all users still clocked in for yesterday (no clockOutTime)
    const snapshot = await attendanceRef
      .where('isClockedIn', '==', true)
      .where('clockInTime', '>=', new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1))
      .get();

    if (snapshot.empty) {
      console.log('No users to auto-clock out.');
      return null;
    }

    const batch = admin.firestore().batch();
    const notifyPromises = [];
    snapshot.forEach(doc => {
      batch.update(doc.ref, {
        isClockedIn: false,
        clockOutTime: clockOutTime,
        autoClockedOut: true
      });
      const data = doc.data();
      const userId = data.userId;
      if (userId) {
        // Write notification to Firestore
        const notifRef = admin.firestore().collection('notifications').doc();
        notifyPromises.push(
          notifRef.set({
            userId: userId,
            title: 'Auto Clock-Out',
            body: 'You were automatically clocked out at midnight because you forgot to clock out.',
            type: 'auto_clock_out',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            sendAsPushNotification: true
          })
        );
      }
    });

    await batch.commit();
    await Promise.all(notifyPromises);
    console.log(`Auto-clocked out ${snapshot.size} users at midnight and notified them.`);
    return null;
  });
