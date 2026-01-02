
import admin from 'firebase-admin';
import * as fs from 'fs';

const serviceAccount = JSON.parse(fs.readFileSync('/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json', 'utf8'));

if (!admin.apps || admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
    });
}

const db = admin.firestore();
db.settings({ databaseId: 'adventure-streak-pre' });

async function verifyActivity() {
    const activityId = '90757805-6653-44D2-9C22-4F2426B5FFDB';

    console.log(`1. Checking HISTORY for cell -1809_20235...`);
    const historySnap = await db.collection('remote_territories').doc('-1809_20235').collection('history')
        .where('activityId', '==', activityId)
        .get();

    if (historySnap.empty) {
        console.log(`❌ No history found for this activity!`);
    } else {
        console.log(`✅ History found! Count: ${historySnap.size}`);
        historySnap.docs.forEach(d => {
            console.log(`   - History Doc: ${d.data().interaction} by ${d.data().userId} (activity: ${d.data().activityId})`);
        });
    }

    console.log(`\n2. Checking Vengeance targets...`);
    const usersSnap = await db.collection('users').get();

    let found = false;
    for (const userDoc of usersSnap.docs) {
        const targetsSnap = await userDoc.ref.collection('vengeance_targets').get();

        if (!targetsSnap.empty) {
            targetsSnap.docs.forEach(d => {
                const data = d.data();
                if (data.activityId === activityId) {
                    console.log(`   - ✅ MATCH: User ${userDoc.id} Target ${d.id}: activityId=${data.activityId}`);
                    found = true;
                }
            });
        }
    }

    if (!found) {
        console.log(`❌ No vengeance targets found with activityId ${activityId}`);
    }
}

verifyActivity();
