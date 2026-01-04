import * as admin from "firebase-admin";
import { getFirestore } from "firebase-admin/firestore";
import * as fs from "fs";

// Initialize Firebase Admin
const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/backend-admin/secrets/serviceAccount.json";
if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
} else {
    console.log("⚠️ No serviceAccountKey.json found. Attempting default credentials...");
    admin.initializeApp();
}

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const databases = ["(default)", "adventure-streak-pre"];

async function cleanupMalformedActivities() {
    console.log("🚀 Starting Malformed Activities Cleanup...");

    for (const dbId of databases) {
        console.log(`\n📂 Database: ${dbId}`);
        // Handle (default) vs named databases using the correct API
        const db = getFirestore(dbId);

        try {
            const snapshot = await db.collection("activities").get();
            console.log(`   Analyzing ${snapshot.size} activities...`);

            let malformedCount = 0;
            let deletedCount = 0;

            for (const doc of snapshot.docs) {
                const id = doc.id;

                if (!UUID_REGEX.test(id)) {
                    malformedCount++;
                    console.log(`   ⚠️ MALFORMED: ${id}`);

                    try {
                        // Use recursiveDelete
                        await db.recursiveDelete(doc.ref);
                        console.log(`   ✅ Deleted: ${id}`);
                        deletedCount++;
                    } catch (error) {
                        console.error(`   ❌ Error deleting ${id}:`, error);
                    }
                }
            }
            console.log(`   Summary for ${dbId}: Found ${malformedCount}, Deleted ${deletedCount}`);
        } catch (error) {
            console.error(`   ❌ Failed to access database ${dbId}:`, error);
        }
    }
}

cleanupMalformedActivities()
    .then(() => process.exit(0))
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
