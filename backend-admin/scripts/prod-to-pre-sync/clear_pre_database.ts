import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, DocumentReference, WriteBatch } from "firebase-admin/firestore";
import { readFileSync } from "fs";

const CONCURRENCY_LIMIT = 20;
const BATCH_SIZE = 500;

async function clearPRE() {
    console.log("🧹 Starting OPTIMIZED TOTAL CLEAR of adventure-streak-pre...");

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
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
        const snapshot = await db.collection(colName).get();
        if (snapshot.empty) continue;

        console.log(`      Found ${snapshot.size} documents.`);
        await runInParallel(snapshot.docs, async (doc) => {
            await deleteDocRecursive(doc.ref);
        });
    }

    console.log("✨ PRE Environment cleared successfully.");
}

async function deleteDocRecursive(docRef: DocumentReference) {
    const subCols = await docRef.listCollections();
    for (const subCol of subCols) {
        const snapshot = await subCol.get();
        if (snapshot.empty) continue;

        const chunks = chunk(snapshot.docs, BATCH_SIZE);
        for (const batchDocs of chunks) {
            const batch = docRef.firestore.batch();
            batchDocs.forEach(d => batch.delete(d.ref));
            await batch.commit();
        }
    }
    await docRef.delete();
}

async function runInParallel<T>(items: T[], fn: (item: T) => Promise<void>) {
    const chunks = chunk(items, CONCURRENCY_LIMIT);
    for (const c of chunks) {
        await Promise.all(c.map(fn));
    }
}

function chunk<T>(array: T[], size: number): T[][] {
    return Array.from({ length: Math.ceil(array.length / size) }, (_, i) => array.slice(i * size, i * size + size));
}

clearPRE().catch(console.error);
