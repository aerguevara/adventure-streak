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

async function setHotSpot() {
    const territoryId = '-1882_20406';
    console.log(`🔥 Setting isHotSpot=true for territory: ${territoryId}`);

    await db.collection('remote_territories').doc(territoryId).update({
        isHotSpot: true
    });

    console.log(`✅ Success! Territory ${territoryId} is now a Hot Spot.`);
    process.exit(0);
}

setHotSpot();
