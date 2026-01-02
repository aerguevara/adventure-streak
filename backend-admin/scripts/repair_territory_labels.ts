import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
});

const db = getFirestore(app, "adventure-streak-pre");

const USER_ID = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function repairTerritoryLabels() {
    console.log(`🔧 Starting Data Repair for User: ${USER_ID}`);

    try {
        // 1. Fetch all activities for the user to get their labels
        console.log('📥 Fetching activities...');
        const activitiesSnap = await db.collection('activities')
            .where('userId', '==', USER_ID)
            .get();

        const activityLabels = new Map<string, string>();
        activitiesSnap.docs.forEach(doc => {
            const data = doc.data();
            if (data.locationLabel) {
                activityLabels.set(doc.id, data.locationLabel);
            }
        });

        console.log(`✅ Loaded ${activityLabels.size} unique activity labels.`);

        // 2. Fetch all territories for the user
        console.log('📥 Fetching territories...');
        const territoriesSnap = await db.collection('remote_territories')
            .where('userId', '==', USER_ID)
            .get();

        console.log(`✅ Found ${territoriesSnap.size} territories.`);

        let repairCount = 0;
        let skipCount = 0;
        let batch = db.batch();
        let opCount = 0;

        for (const doc of territoriesSnap.docs) {
            const data = doc.data();
            const activityId = data.activityId;

            if (activityId && activityLabels.has(activityId)) {
                const label = activityLabels.get(activityId);
                console.log(`🔎 Match! Territory: ${doc.id}, Activity: ${activityId}, Label: ${label}`);

                if (data.locationLabel !== label) {
                    batch.update(doc.ref, { locationLabel: label });
                    repairCount++;
                    opCount++;
                    console.log(`✅ Queued Update for ${doc.id}: ${label}`);
                } else {
                    skipCount++;
                    console.log(`⏭️ Already has correct label: ${doc.id}`);
                }
            } else {
                console.log(`⚠️ Missing Activity or Label: Territory: ${doc.id}, ActivityId: ${activityId ?? 'N/A'}`);
                skipCount++;
            }

            if (opCount >= 400) {
                await batch.commit();
                console.log(`📦 Committed batch. Repaired so far: ${repairCount}`);
                batch = db.batch();
                opCount = 0;
            }
        }

        if (opCount > 0) {
            await batch.commit();
        }

        console.log('\n✨ Repair Complete!');
        console.log(`📊 Repaired: ${repairCount}`);
        console.log(`📊 Unchanged/No Activity: ${skipCount}`);

    } catch (error) {
        console.error('❌ Error during repair:', error);
    } finally {
        process.exit(0);
    }
}

repairTerritoryLabels();
