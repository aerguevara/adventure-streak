import * as admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import { checkRankingChange } from '../../../functions/firebase-function-notifications/functions/src/ranking';

// Initialization for PRE environment
const serviceAccountPath = require('path').resolve(__dirname, '../../secrets/serviceAccount.json');

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(require(serviceAccountPath)),
        projectId: "adventure-streak"
    });
}

const db = getFirestore("adventure-streak-pre");

async function testRankingNotification() {
    console.log("🚀 Starting Ranking Notification Test...");

    const TEST_OLD_LEADER_ID = "test_old_leader";
    const TEST_NEW_LEADER_ID = "test_new_leader";

    // 1. Setup initial state: Old Leader
    console.log("📝 Setting up old leader in config/ranking...");
    await db.collection("config").doc("ranking").set({
        userId: TEST_OLD_LEADER_ID,
        displayName: "Rey Antiguo",
        level: 10,
        xp: 9500,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 2. Prepare new leader data
    const newLeaderData = {
        displayName: "Nuevo Conquistador",
        level: 11,
        xp: 10500
    };

    console.log(`🏃 Calling checkRankingChange for user ${TEST_NEW_LEADER_ID}...`);
    await checkRankingChange(db as any, TEST_NEW_LEADER_ID, newLeaderData);

    // 3. Verify config/ranking update
    console.log("🔍 Verifying config/ranking...");
    const rankingDoc = await db.collection("config").doc("ranking").get();
    const rankingData = rankingDoc.data();

    if (rankingData && rankingData.userId === TEST_NEW_LEADER_ID) {
        console.log("✅ Success: config/ranking updated to new leader.");
    } else {
        console.error("❌ Error: config/ranking NOT updated correctly.", rankingData);
    }

    // 4. Verify notifications
    console.log("🔍 Verifying notifications...");
    const notifsSnap = await db.collection("notifications")
        .where("timestamp", ">", new Date(Date.now() - 10000)) // Last 10 seconds
        .get();

    console.log(`Found ${notifsSnap.size} new notifications.`);

    const oldLeaderNotif = notifsSnap.docs.find((d: any) => d.data().recipientId === TEST_OLD_LEADER_ID);
    const globalNotif = notifsSnap.docs.find((d: any) => d.data().recipientId === "all");

    if (oldLeaderNotif) {
        console.log("✅ Success: Notification for old leader created.");
    } else {
        console.error("❌ Error: Notification for old leader NOT found.");
    }

    if (globalNotif) {
        console.log("✅ Success: Global notification created.");
    } else {
        console.error("❌ Error: Global notification NOT found.");
    }

    console.log("🏁 Test Complete.");
}

testRankingNotification().catch(console.error);
