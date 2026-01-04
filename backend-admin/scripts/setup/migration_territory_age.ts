
import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

// Initialize Firebase Admin
const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';

if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    }
} else {
    console.error("❌ Service account not found at:", serviceAccountPath);
    process.exit(1);
}

async function migrateTerritories(databaseId: string) {
    const db = databaseId === '(default)' ? getFirestore() : getFirestore(databaseId);
    const collectionRef = db.collection('remote_territories');

    console.log(`🔍 [${databaseId}] Fetching territories for migration...`);

    const snapshot = await collectionRef.get();
    console.log(`📊 Found ${snapshot.size} territories.`);

    let updatedCount = 0;
    const batchSize = 500;
    let batch = db.batch();

    for (const doc of snapshot.docs) {
        const data = doc.data();

        // Only update if fields are missing
        if (data.firstConqueredAt === undefined || data.defenseCount === undefined) {
            // firstConqueredAt defaults to lastConqueredAt or activityEndAt
            const firstConqueredAt = data.lastConqueredAt || data.activityEndAt || admin.firestore.Timestamp.now();

            batch.update(doc.ref, {
                firstConqueredAt: firstConqueredAt,
                defenseCount: 0
            });

            updatedCount++;

            if (updatedCount % batchSize === 0) {
                await batch.commit();
                batch = db.batch();
                console.log(`✅ [${databaseId}] Committed batch of ${batchSize} updates...`);
            }
        }
    }

    if (updatedCount % batchSize !== 0) {
        await batch.commit();
    }

    console.log(`🎉 [${databaseId}] Migration complete. Updated ${updatedCount} territories.`);
}

async function run() {
    const databaseId = process.argv[2] || 'adventure-streak-pre';
    console.log(`🚀 Starting territory migration for ${databaseId}...`);
    await migrateTerritories(databaseId);
}

run().then(() => process.exit(0)).catch(err => {
    console.error(err);
    process.exit(1);
});
