import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

async function clearPRE() {
    console.log("🧹 Starting TOTAL CLEAR of adventure-streak-pre...");

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
        "activities",
        "activities_archive",
        "feed",
        "feed_archive",
        "notifications",
        "notifications_archive",
        "remote_territories",
        "activity_reactions",
        "activity_reaction_stats",
        "users",
        "reserved_icons",
        "debug_mock_workouts",
        "config"
    ];

    for (const colName of collections) {
        console.log(`   Cleaning collection: ${colName}...`);
        const snapshot = await db.collection(colName).get();
        console.log(`      Found ${snapshot.size} documents.`);

        const docs = snapshot.docs;
        for (let i = 0; i < docs.length; i += 500) {
            const batch = db.batch();
            const chunk = docs.slice(i, i + 500);
            for (const doc of chunk) {
                await deleteDocRecursive(doc.ref, db);
            }
            await batch.commit();
        }
    }

    console.log("✨ PRE Environment cleared successfully.");
}

async function deleteDocRecursive(docRef: any, db: any) {
    const subCols = await docRef.listCollections();
    for (const subCol of subCols) {
        const subSnapshot = await subCol.get();
        for (const subDoc of subSnapshot.docs) {
            await deleteDocRecursive(subDoc.ref, db);
        }
    }
    await docRef.delete();
}

clearPRE().catch(console.error);
