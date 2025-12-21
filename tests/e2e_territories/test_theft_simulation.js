const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const ACTIVITY_ID = "ABBDBAEC-601E-478D-8C04-6BAE1A185D51"; // Use the same activity
const THIEF_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82"; // The user running the activity
const VICTIM_ID = "VICTIM_USER_001"; // A dummy victim

// Grid Logic (Copied from territories.ts)
const CELL_SIZE_DEGREES = 0.002;

function getCellIndex(latitude, longitude) {
    const x = Math.floor(longitude / CELL_SIZE_DEGREES);
    const y = Math.floor(latitude / CELL_SIZE_DEGREES);
    return { x, y };
}

function getCellId(x, y) {
    return `${x}_${y}`;
}

async function runTest() {
    console.log(`🦹 Starting Theft Simulation Test`);
    console.log(`   - Thief: ${THIEF_ID}`);
    console.log(`   - Victim: ${VICTIM_ID}`);

    // 1. Fetch Activity & Routes (Need route to know where to place victim's land)
    const activityRef = db.collection("activities").doc(ACTIVITY_ID);
    const activitySnap = await activityRef.get();

    if (!activitySnap.exists) {
        console.error("❌ Activity not found!");
        process.exit(1);
    }

    const routesSnap = await activityRef.collection("routes").get();
    const routesData = routesSnap.docs.map(d => ({ id: d.id, data: d.data() }));

    if (routesData.length === 0 || !routesData[0].data.points) {
        console.error("❌ No route points found to simulate theft.");
        process.exit(1);
    }

    // 2. Determine a Target Cell
    const firstPoint = routesData[0].data.points[0];
    const { x, y } = getCellIndex(firstPoint.latitude, firstPoint.longitude);
    const targetCellId = getCellId(x, y);

    console.log(`🎯 Target Cell for Theft: ${targetCellId} (Lat: ${firstPoint.latitude}, Lon: ${firstPoint.longitude})`);

    // 3. Setup Victim's Ownership
    console.log("🏰 Setting up Victim's Territory (1 hour ago)...");
    const oneHourAgo = new Date(Date.now() - 3600000);

    await db.collection("remote_territories").doc(targetCellId).set({
        id: targetCellId,
        userId: VICTIM_ID,
        activityEndAt: admin.firestore.Timestamp.fromDate(oneHourAgo), // Older than current
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)),
        centerLatitude: firstPoint.latitude,
        centerLongitude: firstPoint.longitude,
        boundary: []
    });

    // 4. Delete & Re-insert Activity to Trigger Function
    console.log("🔄 Re-uploading Activity...");

    // 4. Delete Activity First
    console.log("🗑️  Deleting activity...");
    await activityRef.delete(); // Delete single doc immediately (or use batch if routes needed)

    console.log("⏳ Waiting for deletion propagation (2s)...");
    await new Promise(r => setTimeout(r, 2000));

    // 5. Re-insert Activity to Trigger Function
    console.log("📤 Uploading Activity...");

    const batch = db.batch();
    // Re-insert routes
    routesSnap.docs.forEach(d => batch.set(activityRef.collection("routes").doc(d.id), d.data()));

    // Re-insert activity with CURRENT DATE
    const newActivityData = { ...activitySnap.data() };
    delete newActivityData.xpBreakdown;
    delete newActivityData.missions;
    delete newActivityData.territoryStats;
    newActivityData.endDate = admin.firestore.Timestamp.now();
    newActivityData.date = admin.firestore.Timestamp.now();

    batch.set(activityRef, newActivityData);
    await batch.commit();

    console.log("⏳ Waiting for Cloud Function (15s)...");
    await new Promise(r => setTimeout(r, 15000));

    // 5. Verify Processing First
    console.log("🔍 verifying function completion...");
    const updatedActivity = await activityRef.get();
    if (!updatedActivity.data().xpBreakdown) {
        console.error("❌ FAILURE: Activity was NOT processed (no xpBreakdown). Function likely crashed or didn't trigger.");
    } else {
        console.log("✅ Activity processed successfully.");
    }

    // 6. Verify Notification
    console.log("🔍 Checking for Stolen Notification...");
    const notifSnap = await db.collection("notifications")
        .where("recipientId", "==", VICTIM_ID)
        .where("type", "==", "territory_stolen")
        .where("activityId", "==", ACTIVITY_ID)
        .get();

    if (!notifSnap.empty) {
        console.log("✅ SUCCESS! Notification found:");
        notifSnap.docs.forEach(d => {
            const data = d.data();
            console.log(`   - To: ${data.recipientId}`);
            console.log(`   - Message: "${data.message}"`);
            console.log(`   - Sender: ${data.senderName}`);
        });
    } else {
        console.error("❌ FAILURE: No theft notification found for victim.");

        // Debug: Check territory ownership
        const cellSnap = await db.collection("remote_territories").doc(targetCellId).get();
        console.log("   Debug - Cell Owner:", cellSnap.data().userId);
    }

    // 7. Verify Thief Notification (New Requirement)
    console.log("🔍 Checking for Thief Notification...");
    const thiefNotifSnap = await db.collection("notifications")
        .where("recipientId", "==", THIEF_ID) // Current User
        .where("type", "==", "territory_stolen_success")
        .where("activityId", "==", ACTIVITY_ID)
        .get();

    if (!thiefNotifSnap.empty) {
        console.log("✅ SUCCESS! Thief Notification found:");
        thiefNotifSnap.docs.forEach(d => {
            console.log(`   - Message: "${d.data().message}"`);
        });
    } else {
        console.error("❌ FAILURE: No 'You Stole' notification found for thief.");
    }
}

runTest().catch(console.error);
