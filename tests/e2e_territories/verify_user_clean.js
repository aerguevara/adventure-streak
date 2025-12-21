const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}
const db = admin.firestore();
const TARGET_USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82";

async function verify() {
    console.log(`🔍 Verifying emptiness for user: ${TARGET_USER_ID}`);
    let totalIssues = 0;

    // 1. User Profile
    const userDoc = await db.collection("users").doc(TARGET_USER_ID).get();
    if (userDoc.exists) {
        console.log("❌ User Profile STILL EXISTS.");
        totalIssues++;
    } else {
        console.log("✅ User Profile: CLEAN");
    }

    // 2. Activities
    const activitiesData = await db.collection("activities").where("userId", "==", TARGET_USER_ID).count().get();
    const activCount = activitiesData.data().count;
    if (activCount > 0) {
        console.log(`❌ Activities: FOUND ${activCount} docs.`);
        totalIssues++;
    } else {
        console.log("✅ Activities: CLEAN");
    }

    // 3. Remote Territories (Owned)
    const territoriesData = await db.collection("remote_territories").where("ownerId", "==", TARGET_USER_ID).count().get();
    const terrCount = territoriesData.data().count;
    if (terrCount > 0) {
        console.log(`❌ Territories: FOUND ${terrCount} docs.`);
        totalIssues++;
    } else {
        console.log("✅ Territories: CLEAN");
    }

    // 4. Notifications (Recipient)
    const notifData = await db.collection("notifications").where("recipientId", "==", TARGET_USER_ID).count().get();
    const notifCount = notifData.data().count;
    if (notifCount > 0) {
        console.log(`❌ Notifications (Recipient): FOUND ${notifCount} docs.`);
        totalIssues++;
    } else {
        console.log("✅ Notifications (Recipient): CLEAN");
    }

    // 5. Notifications (Sender)
    const notifSenderData = await db.collection("notifications").where("senderId", "==", TARGET_USER_ID).count().get();
    const notifSenderCount = notifSenderData.data().count;
    if (notifSenderCount > 0) {
        console.log(`❌ Notifications (Sender): FOUND ${notifSenderCount} docs.`);
        totalIssues++;
    } else {
        console.log("✅ Notifications (Sender): CLEAN");
    }

    // 6. Reactions
    const reactionsData = await db.collection("activity_reactions").where("reactedUserId", "==", TARGET_USER_ID).count().get();
    const reactCount = reactionsData.data().count;
    if (reactCount > 0) {
        console.log(`❌ Reactions: FOUND ${reactCount} docs.`);
        totalIssues++;
    } else {
        console.log("✅ Reactions: CLEAN");
    }

    // 7. Feed
    const feedData = await db.collection("feed").where("userId", "==", TARGET_USER_ID).count().get();
    const feedCount = feedData.data().count;
    if (feedCount > 0) {
        console.log(`❌ Feed: FOUND ${feedCount} docs.`);
        totalIssues++;
    } else {
        console.log("✅ Feed: CLEAN");
    }

    console.log("------------------------------------------------");
    if (totalIssues === 0) {
        console.log("✨ ALL CLEAN. Safe to login.");
    } else {
        console.log(`⚠️ FOUND ${totalIssues} ISSUES. Run reset_my_user.js again.`);
    }
}

verify().catch(console.error);
