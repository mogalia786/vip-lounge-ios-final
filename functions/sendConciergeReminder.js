// Cloud Function: sendConciergeReminder
// Schedules a bell alarm FCM to the concierge 5 minutes before appointment if not started

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const moment = require('moment-timezone');

if (!admin.apps.length) {
  admin.initializeApp();
}

// Helper to send FCM with bell sound
async function sendBellAlarmToConcierge(conciergeId, appointmentId, conciergeName, fcmToken, appt) {
  // Get VIP name by concatenating ministerFirstname and ministerLastname
  const vipName = `${appt.ministerFirstName || ''} ${appt.ministerLastName || ''}`.trim() || 'VIP Client';
  const venue = appt.venueName || 'the venue';
  
  // Format appointment time
  const appointmentTime = appt.appointmentTime ? 
    moment(appt.appointmentTime.toDate()).tz('Africa/Johannesburg').format('h:mm A') : 'scheduled time';
  
  // Create notification payload with improved message
  const payload = {
    notification: {
      title: 'Escort VIP Client',
      body: `Please meet ${vipName} at pickup spot and escort to ${venue} for ${appointmentTime} appointment`,
      //sound: 'bell_ring',
      //icon: 'cc_logo',
    },
    data: {
      appointmentId: appointmentId,
      notificationType: 'escort_reminder',
      sound: 'bell_ring',
      vipName: vipName,
      venue: venue,
      appointmentTime: appointmentTime,
    },
    android: {
      priority: 'high',
      notification: {
        sound: 'bell_ring',
        channelId: 'alarm',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'bell_ring',
          category: 'alarm',
        },
      },
    },
    token: fcmToken,
  };

  try {
    await admin.messaging().send(payload);
    console.log(`[FCM] Bell alarm sent to concierge ${conciergeId} for appointment ${appointmentId}`);
  } catch (e) {
    console.error(`[FCM] Error sending bell alarm:`, e);
  }
}

exports.sendConciergeReminder = functions.pubsub.schedule('every 2 minutes').onRun(async (context) => {
  // Use Africa/Johannesburg timezone (UTC+2, South Africa local time)
  const now = moment().tz('Africa/Johannesburg');
  
  // Calculate window for appointments in the next 0-10 minutes (local time)
  const windowStart = now.clone();
  const windowEnd = now.clone().add(10, 'minutes');
  
  console.log(`Checking for appointments between ${windowStart.format()} and ${windowEnd.format()} (Africa/Johannesburg time)`);
  
  const appointmentsRef = admin.firestore().collection('appointments');
  const snapshot = await appointmentsRef
    .where('appointmentTime', '>=', windowStart.toDate())
    .where('appointmentTime', '<=', windowEnd.toDate())
    //.where('conciergeSessionStarted', '==', false)
    .get();

  if (snapshot.empty) {
    console.log('No concierge reminders to send.');
    return null;
  }

  for (const doc of snapshot.docs) {
    const appt = doc.data();
    const appointmentId = doc.id;
    const conciergeId = appt.conciergeId;
    if (!conciergeId) continue;

    // Fetch concierge FCM token
    const userDoc = await admin.firestore().collection('users').doc(conciergeId).get();
    const fcmToken = userDoc.get('fcmToken');
    const conciergeName = userDoc.get('name') || '';
    if (!fcmToken) {
      console.log(`[REMINDER] No FCM token for concierge ${conciergeId}`);
      continue;
    }

    await sendBellAlarmToConcierge(conciergeId, appointmentId, conciergeName, fcmToken, appt);
    // Mark as reminder sent
    await appointmentsRef.doc(appointmentId).update({ conciergeReminderSent: true });
  }

  return null;
});
