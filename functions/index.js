const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Cloud Function to send FCM notification
exports.sendNotification = functions.https.onRequest(async (req, res) => {
  // Allow CORS for local testing (optional, remove in prod if not needed)
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  const { token, title, body, data, messageType } = req.body;

  if (!token || !title || !body) {
    return res.status(400).send('Missing required fields');
  }

  const message = {
    token: token,
    notification: {
      title: title,
      body: body,
    },
    data: {
      ...((data && typeof data === 'object') ? data : {}),
      messageType: messageType || 'general',
    },
    android: {
      priority: 'high',
      notification: { sound: 'default' },
    },
    apns: {
      payload: {
        aps: { sound: 'default' },
      },
    },
  };

  try {
    await admin.messaging().send(message);
    return res.status(200).send('Notification sent');
  } catch (error) {
    console.error('Error sending notification:', error);
    // Auto-remove invalid FCM token if error is 'registration-token-not-registered'
    if (error.code === 'messaging/registration-token-not-registered') {
      const userId = data && data.userId;
      if (userId) {
        try {
          await admin.firestore().collection('users').doc(userId).update({
            fcmToken: admin.firestore.FieldValue.delete()
          });
          console.log(`Removed invalid FCM token for user ${userId}`);
        } catch (firestoreError) {
          console.error('Error removing invalid FCM token from Firestore:', firestoreError);
        }
      }
    }
    return res.status(500).send('Error sending notification');
  }
});

// Ensure the midnight clock-out function is deployed
exports.autoClockOutAtMidnight = require('./autoClockOutAtMidnight').autoClockOutAtMidnight;
exports.sendConciergeReminder = require('./sendConciergeReminder').sendConciergeReminder;
