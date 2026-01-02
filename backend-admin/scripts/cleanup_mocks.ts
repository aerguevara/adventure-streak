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

async function cleanupMocks() {
    const mockIds = ['-1883_20406', '-1853_20239', '-1838_20193'];
    console.log(`🧹 Cleaning up mock territories: ${mockIds.join(', ')}`);

    for (const id of mockIds) {
        await db.collection('remote_territories').doc(id).delete();
        console.log(`✅ Deleted ${id}`);
    }

    process.exit(0);
}

cleanupMocks();
