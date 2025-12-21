const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

// Initialize only if not already initialized
if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

// Test Data
const AUTHOR_ID = "REACTION_TEST_AUTHOR";
const REACTOR_ID = "REACTION_TEST_REACTOR";
const ACTIVITY_ID = "REACTION_TEST_ACTIVITY";
const REACTION_TYPE = "fire";

async function runTest() {
    console.log("🧪 Starting Reaction Notification Test...");

    // 1. Setup Data
    console.log("👤 Creating Test Users & Activity...");

    // Create Author
    await db.collection("users").doc(AUTHOR_ID).set({
        name: "Author User",
        avatarURL: "http://example.com/author.png"
    });

    // Create Reactor
    await db.collection("users").doc(REACTOR_ID).set({
        name: "Reactor User",
        avatarURL: "http://example.com/reactor.png"
    });

    // Create Activity
    await db.collection("activities").doc(ACTIVITY_ID).set({
        userId: AUTHOR_ID,
        type: "run",
        date: admin.firestore.FieldValue.serverTimestamp()
    });

    // 2. Simulate Reaction (The Event Trigger)
    console.log("🔥 creating reaction document...");
    const reactionId = `${ACTIVITY_ID}_${REACTOR_ID}`;
    const reactionRef = db.collection("activity_reactions").doc(reactionId);

    // Clean up previous test
    await reactionRef.delete();

    // Clean up previous notifications
    const prevNotifs = await db.collection("notifications")
        .where("type", "==", "reaction")
        .where("activityId", "==", ACTIVITY_ID)
        .get();

    const batch = db.batch();
    prevNotifs.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();

    // Small delay
    await new Promise(r => setTimeout(r, 1000));

    // Write new reaction
    await reactionRef.set({
        activityId: ACTIVITY_ID,
        reactedUserId: REACTOR_ID,
        reactionType: REACTION_TYPE,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log("⏳ Waiting for Cloud Function (15s)...");
    await new Promise(r => setTimeout(r, 15000));

    // 3. Verify Notification
    console.log("🔍 Checking ALL notifications for Author...");
    const allNotifs = await db.collection("notifications")
        .where("recipientId", "==", AUTHOR_ID)
        .get();

    if (allNotifs.empty) {
        console.error("❌ FAILURE: Absolutely NO notifications found for Author.");
    } else {
        console.log(`ℹ️ Found ${allNotifs.size} notifications. Listing...`);
        allNotifs.docs.forEach(d => {
            console.log(`   [${d.id}] Type: ${d.data().type}, Sender: ${d.data().senderId}`);
        });

        // Check for specific match manually
        const match = allNotifs.docs.find(d =>
            d.data().type === "reaction" && d.data().activityId === ACTIVITY_ID
        );

        if (match) {
            console.log("✅ SUCCESS! Specific notification found.");
        } else {
            console.error("❌ FAILURE: Specific notification missing.");
        }
    }
}

runTest().catch(console.error);
