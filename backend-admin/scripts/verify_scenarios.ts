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

const ids = ['-1883_20406', '-1853_20239', '-1838_20193'];

async function verify() {
    console.log("🔍 Verifying Scenario Cards...");
    for (const id of ids) {
        const doc = await db.collection('remote_territories').doc(id).get();
        if (doc.exists) {
            const data = doc.data();
            console.log(`✅ ${id} EXISTS. userId=${data?.userId}, activityId=${data?.activityId}, isHotSpot=${data?.isHotSpot}, expiresAt=${data?.expiresAt?.toDate()}`);
        } else {
            console.log(`❌ ${id} DOES NOT EXIST`);
        }
    }
    process.exit(0);
}

verify();
