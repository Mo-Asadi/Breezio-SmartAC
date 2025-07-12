const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendIdleNotification = functions.database
  .ref("/devices/{deviceId}/status/idleFlag")
  .onUpdate(async (change, context) => {
    const before = change.before.val();
    const after = change.after.val();

    if (before === after || after !== "user_prompt") return null;

    const deviceId = context.params.deviceId;

    // Get all users under the device
    const usersSnapshot = await admin.database().ref(`/devices/${deviceId}/users`).once("value");
    const users = usersSnapshot.val();
    if (!users) return null;

    const messages = [];

    for (const uid in users) {
      const fcmTokenSnap = await admin.database().ref(`/users/${uid}/fcmToken`).once("value");
      const token = fcmTokenSnap.val();

      if (!token) continue;

      messages.push({
        token: token,
        notification: {
          title: "No motion detected",
          body: "AC hasn't detected motion for 30 minutes. Do you want to keep it on?",
        },
        data: {
          deviceId,
          role: users[uid].role || "user",
        },
      });
    }

    const response = await admin.messaging().sendAll(messages);
    console.log(`✅ Sent ${response.successCount} notifications`);
    return null;
  });