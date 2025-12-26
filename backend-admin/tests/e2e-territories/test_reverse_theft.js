const admin = require("firebase-admin");
const serviceAccount = require("../../secrets/serviceAccount.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const ACTIVITY_ID = "REVERSE_THEFT_ACTIVITY_001";
const MY_USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82"; // Me (Victim)
const ATTACKER_ID = "ATTACKER_USER_X"; // The one stealing from me

// Function to wait
const wait = (ms) => new Promise(r => setTimeout(r, ms));

// Grid Logic
const CELL_SIZE_DEGREES = 0.002;
// Use a different location to avoid conflict with other tests
const LAT = 40.5000;
const LON = -3.5000;

function getCellId(lat, lon) {
    const x = Math.floor(lon / CELL_SIZE_DEGREES);
    const y = Math.floor(lat / CELL_SIZE_DEGREES);
    return `${x}_${y}`;
}

async function runTest() {
    console.log(`🛡️ Starting Reverse Theft Simulation (I am being robbed)`);
    console.log(`   - Me (Victim): ${MY_USER_ID}`);
    console.log(`   - Attacker: ${ATTACKER_ID}`);

    const cellId = getCellId(LAT, LON);
    console.log(`🎯 Contested Cell: ${cellId}`);

    // 1. Setup MY Territory (I own it)
    console.log("🏰 Setting up MY territory (1 day ago)...");
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    await db.collection("remote_territories").doc(cellId).set({
        id: cellId,
        userId: MY_USER_ID,
        activityEndAt: admin.firestore.Timestamp.fromDate(oneDayAgo),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 6 * 24 * 60 * 60 * 1000)),
        centerLatitude: LAT,
        centerLongitude: LON,
        boundary: []
    });

    // 1.5 Create Attacker User Profile
    console.log("👤 Creating Attacker User Profile...");
    await db.collection("users").doc(ATTACKER_ID).set({
        id: ATTACKER_ID,
        name: "Evil Attacker",
        avatarURL: "http://example.com/evil.png",
        xp: 1000,
        level: 5,
        stats: { totalDistance: 500 }
    });

    // 2. Create Dummy Activity for Attacker (Overlapping my cell)
    console.log("⚔️ Creating Attacker's Activity...");
    const activityRef = db.collection("activities").doc(ACTIVITY_ID);

    // Clean up previous run
    await activityRef.delete();
    const routeRef = activityRef.collection("routes").doc("chunk_0");
    await routeRef.delete();
    await wait(1000);

    // Create Route
    await routeRef.set({
        points: [{ latitude: LAT, longitude: LON, timestamp: admin.firestore.Timestamp.now() }]
    });

    // Create Main Activity Config (Simulating Upload)
    const now = admin.firestore.Timestamp.now();
    await activityRef.set({
        id: ACTIVITY_ID,
        userId: ATTACKER_ID, // Use Attacker ID
        userName: "Evil Attacker",
        userAvatarURL: "http://example.com/evil.png",
        type: "run",
        distanceMeters: 1000,
        durationSeconds: 600,
        date: now,
        endDate: now,
        isPrivate: false,
        // Missing xpBreakdown triggers function
    });

    console.log("✅ Attacker Activity (Simulated) Created. Waiting for Cloud Function (15s)...");
    await wait(15000);

    // 2.5 Verify Processing
    const updatedAttackerActivity = await activityRef.get();
    if (!updatedAttackerActivity.exists || !updatedAttackerActivity.data().xpBreakdown) {
        console.error("❌ FAILURE: Attacker activity NOT processed. Function crashed or stalled.");
        return;
    }
    console.log("✅ Attacker activity processed.");

    // 3. Verify I received a notification
    console.log("🔍 Checking if I received a 'Stolen' notification...");
    const notifSnap = await db.collection("notifications")
        .where("recipientId", "==", MY_USER_ID) // Me
        .where("type", "==", "territory_stolen")
        .where("senderId", "==", ATTACKER_ID)
        .limit(1)
        .get();

    if (!notifSnap.empty) {
        console.log("✅ SUCCESS! I was notified about the theft:");
        const data = notifSnap.docs[0].data();
        console.log(`   - From: ${data.senderName}`);
        console.log(`   - Message: "${data.message}"`);
    } else {
        console.error("❌ FAILURE: No notification found for me.");

        // Debug: Check who owns the cell now
        const cell = await db.collection("remote_territories").doc(cellId).get();
        console.log(`   Debug - Cell Owner is now: ${cell.data().userId}`);
    }
}

runTest().catch(console.error);
