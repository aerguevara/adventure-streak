import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
});

const DB_IDS = ['(default)', 'adventure-streak-pre'];

async function globalRepair() {
    for (const dbId of DB_IDS) {
        console.log(`\n🚀 Starting Global Repair for Database: ${dbId}`);
        const db = getFirestore(app, dbId);

        try {
            // 1. Fetch all activities into a cache for quick lookups
            const activitiesSnap = await db.collection('activities').get();
            const activityLabels = new Map<string, string>();
            activitiesSnap.docs.forEach(doc => {
                const data = doc.data();
                if (data.locationLabel) {
                    activityLabels.set(doc.id, data.locationLabel);
                }
            });
            console.log(`✅ Cached ${activityLabels.size} activity labels.`);

            // 2. Repair remote_territories
            console.log('📦 Repairing remote_territories...');
            const territoriesSnap = await db.collection('remote_territories').get();
            let territoryRepairCount = 0;
            let batch = db.batch();
            let opCount = 0;

            for (const doc of territoriesSnap.docs) {
                const data = doc.data();
                const activityId = data.activityId;
                if (activityId && activityLabels.has(activityId)) {
                    const label = activityLabels.get(activityId);
                    if (data.locationLabel !== label) {
                        batch.update(doc.ref, { locationLabel: label });
                        territoryRepairCount++;
                        opCount++;
                    }
                }
                if (opCount >= 400) {
                    await batch.commit();
                    batch = db.batch();
                    opCount = 0;
                }
            }
            if (opCount > 0) await batch.commit();
            console.log(`✅ Repaired ${territoryRepairCount} territories.`);

            // 3. Repair vengeance_targets for all users
            console.log('🎯 Repairing vengeance_targets...');
            const usersSnap = await db.collection('users').get();
            let vengeanceRepairCount = 0;
            batch = db.batch();
            opCount = 0;

            for (const userDoc of usersSnap.docs) {
                const vengeanceSnap = await userDoc.ref.collection('vengeance_targets').get();
                for (const vDoc of vengeanceSnap.docs) {
                    const data = vDoc.data();
                    const activityId = data.activityId;
                    if (activityId && activityLabels.has(activityId)) {
                        const label = activityLabels.get(activityId);
                        if (data.locationLabel !== label) {
                            batch.update(vDoc.ref, { locationLabel: label });
                            vengeanceRepairCount++;
                            opCount++;
                        }
                    }
                    if (opCount >= 400) {
                        await batch.commit();
                        batch = db.batch();
                        opCount = 0;
                    }
                }
            }
            if (opCount > 0) await batch.commit();
            console.log(`✅ Repaired ${vengeanceRepairCount} vengeance targets.`);

        } catch (error) {
            console.error(`❌ Error in ${dbId}:`, error);
        }
    }
    process.exit(0);
}

globalRepair();
