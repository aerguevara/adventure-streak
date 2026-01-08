import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, DocumentReference, WriteBatch } from "firebase-admin/firestore";
import { readFileSync } from "fs";

const CONCURRENCY_LIMIT = 20;
const BATCH_SIZE = 500;

async function clearPRE() {
    console.log("🧹 Starting OPTIMIZED TOTAL CLEAR of adventure-streak-pre...");

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/backend-admin/secrets/serviceAccount.json";
    const databaseId = "adventure-streak-pre";

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(databaseId);

    const collections = [
        "activities", "activities_archive", "feed", "feed_archive",
        "notifications", "notifications_archive", "remote_territories",
        "activity_reactions", "activity_reaction_stats", "users",
        "reserved_icons", "debug_mock_workouts", "config"
    ];

    for (const colName of collections) {
        console.log(`   Cleaning collection: ${colName}...`);
        const snapshot = await db.collection(colName).count().get();
        if (snapshot.data().count === 0) continue;

        console.log(`      Found ~${snapshot.data().count} documents (count approx).`);

        // Use recursiveDelete for massive speedup
        // Note: recursiveDelete requires a Query or CollectionReference.
        const batchSize = 4000; // Large batch for recursive delete
        await db.recursiveDelete(db.collection(colName));
    }

    console.log("✨ PRE Environment cleared successfully.");
}

// Helper removed as recursiveDelete handles it internally
// async function deleteDocRecursive(docRef: DocumentReference) { ... }
// async function runInParallel<T>(items: T[], fn: (item: T) => Promise<void>) { ... }

function chunk<T>(array: T[], size: number): T[][] {
    return Array.from({ length: Math.ceil(array.length / size) }, (_, i) => array.slice(i * size, i * size + size));
}

clearPRE().catch(console.error);
