
console.log("🚀 GLOBAL RESET Script started...");

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

// Collections to WIPE completely
const COLLECTIONS_TO_WIPE = [
    "users",
    "activities",
    "feed",
    "remote_territories",
    "notifications",
    "activity_reactions",
    "activity_reaction_stats"
];

// Collections to KEEP
const KEEP_COLLECTIONS = ["config"];

async function main() {
    console.log(`🚨 STARTING GLOBAL DATABASE WIPE 🚨`);
    console.log(`Preserving: ${KEEP_COLLECTIONS.join(", ")}`);

    for (const colName of COLLECTIONS_TO_WIPE) {
        console.log(`\nDeleting Collection: ${colName}...`);
        await deleteCollectionRecursive(db.collection(colName));
    }

    console.log("\n✅ GLOBAL WIPE COMPLETE.");
}

async function deleteCollectionRecursive(colRef) {
    const batchSize = 400;
    let totalDeleted = 0;

    while (true) {
        const snapshot = await colRef.limit(batchSize).get();
        if (snapshot.empty) break;

        const docs = snapshot.docs;

        // Check for subcollections first (naive specific checks for known structures to speed up)
        // For a true generic recursive delete, we'd need listCollections() but that's heavier.
        // We know the schema:
        // - users -> followers, following
        // - activities -> routes
        // - remote_territories -> history

        for (const doc of docs) {
            if (colRef.id === "users") {
                await deleteCollectionRecursive(doc.ref.collection("followers"));
                await deleteCollectionRecursive(doc.ref.collection("following"));
            } else if (colRef.id === "activities") {
                await deleteCollectionRecursive(doc.ref.collection("routes"));
            } else if (colRef.id === "remote_territories") {
                await deleteCollectionRecursive(doc.ref.collection("history"));
            }
        }

        const batch = db.batch();
        docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();

        totalDeleted += docs.length;
        console.log(`      Deleted batch of ${docs.length} (Total: ${totalDeleted})`);
    }
}

main().catch(console.error);
