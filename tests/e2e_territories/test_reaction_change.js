const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

const MY_USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82"; // Me
const FAN_USER_ID = "FAN_USER_001";
const ACTIVITY_ID = "REACTION_CHANGE_TEST_ACTIVITY";

async function runTest() {
    console.log("🧪 Starting Reaction Change Test...");

    // 1. Setup Data
    console.log("👤 Creating 'Fan' User...");
    await db.collection("users").doc(FAN_USER_ID).set({
        name: "Fan User",
        avatarURL: "http://example.com/fan.png"
    });

    console.log("🏃 Creating 'My' Activity...");
    await db.collection("activities").doc(ACTIVITY_ID).set({
        userId: MY_USER_ID,
        type: "run",
        date: admin.firestore.FieldValue.serverTimestamp()
    });

    // Clean up previous reactions/notifications
    const reactionId = `${ACTIVITY_ID}_${FAN_USER_ID}`;
    const reactionRef = db.collection("activity_reactions").doc(reactionId);
    await reactionRef.delete();

    const prevNotifs = await db.collection("notifications")
        .where("activityId", "==", ACTIVITY_ID)
        .where("senderId", "==", FAN_USER_ID)
        .get();

    const batch = db.batch();
    prevNotifs.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();

    // 2. React with DEVIL (Create)
    console.log("😈 Fan reacts with DEVIL...");
    await reactionRef.set({
        activityId: ACTIVITY_ID,
        reactedUserId: FAN_USER_ID,
        reactionType: "devil",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log("⏳ Waiting for Notification (10s)...");
    await new Promise(r => setTimeout(r, 10000));

    // Verify Notification 1
    const notif1 = await db.collection("notifications")
        .where("recipientId", "==", MY_USER_ID)
        .where("type", "==", "reaction")
        .where("reactionType", "==", "devil")
        .limit(1)
        .get();

    if (!notif1.empty) {
        console.log("✅ SUCCESS: Received 'Devil' notification.");
    } else {
        console.error("❌ FAILURE: Missed 'Devil' notification.");
    }

    // 3. Change to FIRE (Update)
    console.log("🔥 Fan changes reaction to FIRE...");
    await reactionRef.update({
        reactionType: "fire",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log("⏳ Waiting (5s)...");
    await new Promise(r => setTimeout(r, 5000));

    // Verify Data Update
    const updatedReaction = await reactionRef.get();
    if (updatedReaction.data().reactionType === "fire") {
        console.log("✅ SUCCESS: Reaction record updated to 'fire'.");
    } else {
        console.error("❌ FAILURE: Reaction record NOT updated.");
    }

    // Check for Duplicate/New Notification
    const notif2 = await db.collection("notifications")
        .where("recipientId", "==", MY_USER_ID)
        .where("type", "==", "reaction")
        .where("reactionType", "==", "fire") // Looking for the NEW type
        .limit(1)
        .get();

    if (notif2.empty) {
        console.log("ℹ️ Standard Behavior: No new notification for reaction UPDATE (Correct).");
    } else {
        console.log("⚠️ Notification sent for UPDATE (Check if intended).");
    }
}

runTest().catch(console.error);
