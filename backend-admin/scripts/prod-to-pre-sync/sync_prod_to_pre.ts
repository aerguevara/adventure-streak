import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

/**
 * Script to sync PROD environment to PRE environment.
 * Copies all documents and subcollections from the '(default)' database
 * to the 'adventure-streak-pre' database instance.
 */

async function syncProdToPre() {
    console.log("🚀 Starting Sync PROD -> PRE...");

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
        // ACTIVATE SILENT MODE BEFORE STARTING
        await setSilentMode(dbPre, true);

        const collections = [
            "activities",
            "activity_reaction_stats",
            "activity_reactions",
            "config",
            "debug_mock_workouts",
            "feed",
            "notifications",
            "remote_territories",
            "reserved_icons",
            "users"
        ];

        for (const colName of collections) {
            console.log(`📦 Syncing collection: ${colName}...`);

            let lastDoc = null;
            let totalSynced = 0;
            const pageSize = 100;

            while (true) {
                let query = dbProd.collection(colName).limit(pageSize);
                if (lastDoc) {
                    query = query.startAfter(lastDoc);
                }

                const snapshot = await query.get();
                if (snapshot.empty) break;

                for (const doc of snapshot.docs) {
                    await copyDocRecursive(doc, dbPre);
                    totalSynced++;
                    lastDoc = doc;
                }
                console.log(`   Progress ${colName}: ${totalSynced} synced...`);
            }
        }

        console.log("🏁 Sync Complete.");
    } finally {
        // Silent mode remains active by default for safety after a fresh sync.
    }
}

async function setSilentMode(db: any, active: boolean) {
    console.log(`🔧 Setting Silent Mode to ${active} in ${db.databaseId}...`);
    await db.collection("config").doc("maintenance").set({ silentMode: active }, { merge: true });
}

async function copyDocRecursive(doc: any, targetDb: any) {
    const data = doc.data();
    if (!data) return;

    await targetDb.doc(doc.ref.path).set(data);

    const subCollections = await doc.ref.listCollections();
    for (const subCol of subCollections) {
        const subSnapshot = await subCol.get();
        if (!subSnapshot.empty) {
            for (const subDoc of subSnapshot.docs) {
                await copyDocRecursive(subDoc, targetDb);
            }
        }
    }
}

syncProdToPre().catch(err => {
    console.error("❌ Sync failed:", err);
    process.exit(1);
});
