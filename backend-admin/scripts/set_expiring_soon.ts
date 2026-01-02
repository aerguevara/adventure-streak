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

async function setExpiringSoon() {
    const activityId = '09EFC275-B611-42FE-B763-287B06269370';
    console.log(`⏳ Setting 'expiring soon' for all territories in activity: ${activityId}`);

    const snap = await db.collection('remote_territories')
        .where('activityId', '==', activityId)
        .get();

    console.log(`📦 Found ${snap.size} territories to update.`);

    const batch = db.batch();
    const twoHoursFromNow = new Date(Date.now() + 2 * 3600000);

    snap.docs.forEach(doc => {
        batch.update(doc.ref, {
            expiresAt: admin.firestore.Timestamp.fromDate(twoHoursFromNow)
        });
    });

    await batch.commit();
    console.log(`✅ Success! Group updated to expire in 2 hours.`);
    process.exit(0);
}

setExpiringSoon();
