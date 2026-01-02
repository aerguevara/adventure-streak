import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, DocumentSnapshot, QueryDocumentSnapshot, Firestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

/**
 * OPTIMIZED Sync PROD -> PRE
 */

const CONCURRENCY_LIMIT = 20;
const BATCH_SIZE = 500;

async function syncProdToPre() {
    console.log("🚀 Starting OPTIMIZED Sync PROD -> PRE...");

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const dbProd = getFirestore();
    const dbPre = getFirestore("adventure-streak-pre");

    try {
        await setSilentMode(dbPre, true);

        const collections = [
            "activities", "activity_reaction_stats", "activity_reactions",
            "config", "debug_mock_workouts", "feed", "notifications",
            "remote_territories", "reserved_icons", "users"
        ];

        for (const colName of collections) {
            console.log(`📦 Syncing collection: ${colName}...`);
            const snapshot = await dbProd.collection(colName).get();
            if (snapshot.empty) continue;

            console.log(`      Found ${snapshot.size} documents to sync.`);
            await runInParallel(snapshot.docs, async (doc) => {
                await copyDocRecursive(doc, dbPre);
            });
            console.log(`   ✅ Finished syncing ${colName}.`);
        }

        console.log("🏁 Sync Complete.");
    } catch (err) {
        console.error("❌ Sync failed:", err);
        process.exit(1);
    }
}

async function copyDocRecursive(doc: QueryDocumentSnapshot | DocumentSnapshot, targetDb: any) {
    const data = doc.data();
    if (!data) return;

    await targetDb.doc(doc.ref.path).set(data);

    const subCollections = await doc.ref.listCollections();
    for (const subCol of subCollections) {
        const subSnapshot = await subCol.get();
        if (subSnapshot.empty) continue;

        const chunks = chunk(subSnapshot.docs, BATCH_SIZE);
        for (const batchDocs of chunks) {
            const batch = targetDb.batch();
            batchDocs.forEach(sd => {
                batch.set(targetDb.doc(sd.ref.path), sd.data());
            });
            await batch.commit();
        }
    }
}

async function setSilentMode(db: any, active: boolean) {
    console.log(`🔧 Setting Silent Mode to ${active} in ${db.databaseId}...`);
    await db.collection("config").doc("maintenance").set({ silentMode: active }, { merge: true });
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

syncProdToPre().catch(err => {
    console.error("❌ Sync failed:", err);
    process.exit(1);
});
