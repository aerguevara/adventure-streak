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

async function auditLabels() {
    console.log(`🔎 Auditing Labels for User: ${USER_ID}`);
    const snap = await db.collection('remote_territories').where('userId', '==', USER_ID).get();

    let total = 0;
    let missing = 0;
    let exploracion = 0;
    let test = 0;
    let ok = 0;

    snap.docs.forEach(doc => {
        total++;
        const data = doc.data();
        const label = data.locationLabel;

        if (!label) {
            missing++;
            console.log(`❌ Territory ${doc.id} is MISSING label (Activity: ${data.activityId})`);
        } else if (label === 'Exploración') {
            exploracion++;
            console.log(`❌ Territory ${doc.id} has 'Exploración' (Activity: ${data.activityId})`);
        } else if (label.includes('Test') || label.includes('Zona')) {
            test++;
            // OK but it's a test label
        } else {
            ok++;
        }
    });

    console.log(`\n📊 Audit Summary:`);
    console.log(`Total: ${total}`);
    console.log(`OK (Real Labels): ${ok}`);
    console.log(`Test Labels (Mock): ${test}`);
    console.log(`Missing Labels: ${missing}`);
    console.log(`'Exploración' Labels: ${exploracion}`);

    process.exit(0);
}

auditLabels();
