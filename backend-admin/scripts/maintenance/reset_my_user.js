console.log("🚀 Script started..."); // First line debug

const admin = require("firebase-admin");
const serviceAccount = require("../../secrets/serviceAccount.json");

try {
    if (admin.apps.length === 0) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    }
    console.log("✅ Firebase Initialized");
} catch (e) {
    console.error("❌ Firebase Init Failed:", e);
    process.exit(1);
}

const db = admin.firestore();
const TARGET_USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82";

async function main() {
    console.log(`🚨 STARTING WIPE FOR USER: ${TARGET_USER_ID} 🚨`);

    // 1. Reactions
    console.log("1. Deleting Reactions...");
    await deleteQuery(db.collection("activity_reactions").where("reactedUserId", "==", TARGET_USER_ID));

    // 2. Notifications
    console.log("2. Deleting Notifications...");
    await deleteQuery(db.collection("notifications").where("recipientId", "==", TARGET_USER_ID));
    await deleteQuery(db.collection("notifications").where("senderId", "==", TARGET_USER_ID));

    // 3. User & Subcollections
    console.log("3. Deleting User & Subcollections...");
    const userRef = db.collection("users").doc(TARGET_USER_ID);
    await deleteCollectionRecursive(userRef.collection("following"));
    await deleteCollectionRecursive(userRef.collection("followers"));
    await userRef.delete();

    // 4. Remote Territories (Query -> specific docs)
    console.log("4. Deleting Remote Territories (Owned by User)...");
    const territoriesQ = db.collection("remote_territories").where("userId", "==", TARGET_USER_ID);
    await deleteQuery(territoriesQ);

    // 5. Activities & Routes
    console.log("5. Deleting Activities & Routes...");
    const activitiesQ = db.collection("activities").where("userId", "==", TARGET_USER_ID);
    const activitySnaps = await activitiesQ.get();

    for (const doc of activitySnaps.docs) {
        console.log(`   - Activity ${doc.id}`);
        // Delete Routes subcollection
        await deleteCollectionRecursive(doc.ref.collection("routes"));
        // Delete Activity doc
        await doc.ref.delete();
    }

    // 6. Feed
    console.log("6. Deleting Feed...");
    await deleteQuery(db.collection("feed").where("userId", "==", TARGET_USER_ID));

    console.log("✅ DATA WIPE COMPLETE.");
}

// Helper to delete all docs in a query
async function deleteQuery(query) {
    const batchSize = 400;
    while (true) {
        const snapshot = await query.limit(batchSize).get();
        if (snapshot.empty) break;

        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`      Deleted batch of ${snapshot.size}`);
        if (snapshot.size < batchSize) break;
    }
}

// Helper to delete a collection (and simple docs inside, not recursive-recursive, just 1 level for now or simple loop)
// For routes/following/followers, they are flat, so this is fine.
async function deleteCollectionRecursive(colRef) {
    const batchSize = 400;
    while (true) {
        const snapshot = await colRef.limit(batchSize).get();
        if (snapshot.empty) break;

        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`      Deleted ${snapshot.size} docs from ${colRef.id}`);
        if (snapshot.size < batchSize) break;
    }
}

main().catch(console.error);
