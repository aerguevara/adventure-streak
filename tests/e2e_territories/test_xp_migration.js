const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const ACTIVITY_ID = "ABBDBAEC-601E-478D-8C04-6BAE1A185D51";
const USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82";

async function runTest() {
    console.log(`🚀 Starting XP/Mission Migration Test for Activity ${ACTIVITY_ID}`);

    // 1. Fetch Original Activity Data (to restore later)
    console.log("📥 Fetching activity data...");
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

    // 2. Fetch Initial User State
    const userRef = db.collection("users").doc(USER_ID);
    const userSnap = await userRef.get();
    const initialXP = userSnap.data()?.xp || 0;
    const initialLevel = userSnap.data()?.level || 1;
    console.log(`👤 Initial User State: XP=${initialXP}, Level=${initialLevel}`);

    // 3. Clean Slate (Delete Activity & Routes)
    console.log("🗑️  Deleting activity from Firestore...");
    const batchDelete = db.batch();
    batchDelete.delete(activityRef);
    routesSnap.docs.forEach(d => batchDelete.delete(d.ref));
    await batchDelete.commit();

    // 4. Wait a bit
    await new Promise(r => setTimeout(r, 2000));

    // 5. Re-Insert (Trigger Cloud Function)
    console.log("📤 Re-inserting activity (Simulating Upload)...");
    const batchWrite = db.batch();

    // Restore routes first (best practice for triggers reading them)
    for (const route of routesData) {
        batchWrite.set(activityRef.collection("routes").doc(route.id), route.data);
    }

    // Restore activity (triggers function)
    const newActivityData = { ...activityData };

    // Remove computed fields if they exist to verify they are re-added
    delete newActivityData.xpBreakdown;
    delete newActivityData.missions;
    delete newActivityData.territoryStats;

    batchWrite.set(activityRef, newActivityData);
    await batchWrite.commit();

    console.log("✅ Data uploaded. Waiting for Cloud Function...");

    // 6. Wait for Processing
    await new Promise(r => setTimeout(r, 15000));

    // 7. Verify Results
    console.log("🔍 Verifying results...");

    // A. Check Activity Update
    const updatedActivitySnap = await activityRef.get();
    const updatedData = updatedActivitySnap.data();

    if (updatedData.xpBreakdown) {
        console.log("✅ Activity has XP Breakdown:", updatedData.xpBreakdown);
    } else {
        console.error("❌ FAILURE: Activity missing 'xpBreakdown'.");
    }

    if (updatedData.missions && updatedData.missions.length > 0) {
        console.log(`✅ Activity has ${updatedData.missions.length} missions.`);
        updatedData.missions.forEach(m => console.log(`   - [${m.rarity}] ${m.name}: ${m.description}`));
    } else {
        console.log("⚠️ No missions assigned (check criteria).");
    }

    // B. Check User Update
    const updatedUserSnap = await userRef.get();
    const finalXP = updatedUserSnap.data()?.xp || 0;
    const diffXP = finalXP - initialXP;

    if (diffXP > 0) {
        console.log(`✅ User XP increased by ${diffXP} (Initial: ${initialXP} -> Final: ${finalXP})`);
    } else {
        console.error(`❌ FAILURE: User XP did not increase. (Initial: ${initialXP} -> Final: ${finalXP})`);
    }

    // C. Check Feed Event
    const feedSnap = await db.collection("feed")
        .where("activityId", "==", ACTIVITY_ID)
        .orderBy("timestamp", "desc")
        .limit(1)
        .get();

    if (!feedSnap.empty) {
        const event = feedSnap.docs[0].data();
        console.log("✅ Feed event created:", event.title, "|", event.subtitle);
        console.log("   - XP Earned listed in feed:", event.xpEarned);
    } else {
        console.error("❌ FAILURE: No feed event found.");
    }
}

runTest().catch(console.error);
