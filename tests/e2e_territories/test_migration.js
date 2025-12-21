const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const ACTIVITY_ID = "ABBDBAEC-601E-478D-8C04-6BAE1A185D51";
const USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82";

async function runTest() {
    console.log(`🚀 Starting E2E Test for Activity ${ACTIVITY_ID}`);

    // 1. Fetch Original Data
    console.log("📥 Fetching original activity data...");
    const activityRef = db.collection("activities").doc(ACTIVITY_ID);
    const activitySnap = await activityRef.get();

    if (!activitySnap.exists) {
        console.error("❌ Activity not found! Cannot proceed.");
        process.exit(1);
    }

    const activityData = activitySnap.data();

    // Fetch Routes
    const routesSnap = await activityRef.collection("routes").get();
    const routesData = routesSnap.docs.map(d => ({ id: d.id, data: d.data() }));

    console.log(`✅ Loaded activity + ${routesData.length} route chunks.`);

    // 2. Delete Original
    console.log("🗑️  Deleting activity and routes from Firestore...");
    const batchDelete = db.batch();
    batchDelete.delete(activityRef);
    routesSnap.docs.forEach(d => batchDelete.delete(d.ref));
    await batchDelete.commit();
    console.log("✅ Deleted.");

    // 2b. Cleanup existing territories for this activity (to prove re-generation works)
    console.log("🧹 Cleaning up old remote territories...");
    const oldTerritories = await db.collection("remote_territories")
        .where("activityId", "==", ACTIVITY_ID)
        .get();

    if (!oldTerritories.empty) {
        const batchT = db.batch();
        oldTerritories.docs.forEach(d => batchT.delete(d.ref));
        await batchT.commit();
        console.log(`✅ Deleted ${oldTerritories.size} old territories.`);
    }

    // 3. Wait
    console.log("⏳ Waiting 3 seconds...");
    await new Promise(r => setTimeout(r, 3000));

    // 4. Re-Insert (Simulate Upload)
    console.log("📤 Re-inserting activity (Simulating App Upload)...");

    // Important: We must write routes FIRST or SAME TIME? 
    // Cloud Function triggers on 'activities/{id}' create.
    // It then reads 'routes'. If we write activity first, function might run before routes exist.
    // Real app writes routes first, then activity.

    const batchWrite = db.batch();

    // Restore routes
    for (const route of routesData) {
        batchWrite.set(activityRef.collection("routes").doc(route.id), route.data);
    }

    // Restore activity
    // We explicitly set a NEW 'createdAt' or just restore? 
    // Function doesn't check createdAt, just triggers on CREATE.
    batchWrite.set(activityRef, activityData);

    await batchWrite.commit();
    console.log("✅ Re-inserted data. Cloud Function should be triggered now.");

    // 5. Wait for Cloud Function
    console.log("⏳ Waiting 15 seconds for Cloud Function to process...");
    await new Promise(r => setTimeout(r, 15000));

    // 6. Verify
    console.log("🔍 Verifying results...");
    const newTerritories = await db.collection("remote_territories")
        .where("activityId", "==", ACTIVITY_ID)
        .get();

    if (newTerritories.empty) {
        console.error("❌ FAILURE: No territories were created by the Cloud Function.");
    } else {
        console.log(`✅ SUCCESS: Cloud Function created ${newTerritories.size} territories.`);
        newTerritories.docs.slice(0, 3).forEach(d => {
            console.log(`   - Cell ${d.id}: Owner ${d.data().userId}, Exp ${d.data().expiresAt?.toDate()}`);
        });
    }

    // Check notifications
    const notifications = await db.collection("notifications")
        .where("activityId", "==", ACTIVITY_ID)
        .limit(5)
        .get();

    if (!notifications.empty) {
        console.log(`✅ Found ${notifications.size} notifications generated:`);
        notifications.docs.forEach(d => {
            console.log(`   - Type: ${d.data().type}, Recipient: ${d.data().recipientId}`);
        });
    } else {
        console.log("⚠️ No notifications found (might be normal if only conquest/defense happened and we didn't force them).");
    }

    console.log("🏁 Test Complete.");
}

runTest().catch(console.error);
