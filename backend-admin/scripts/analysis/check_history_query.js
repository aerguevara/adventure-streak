const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.resolve(__dirname, '../../Docs/serviceAccount.json'));

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkHistory() {
    const activityId = 'DAB63E0A-1DD2-4EAB-A79A-19171EC0F825';
    console.log('Querying history for', activityId);
    try {
        const snap = await db.collectionGroup('history').where('activityId', '==', activityId).get();
        console.log('Found history docs:', snap.size);
        if (!snap.empty) {
            const parentPath = snap.docs[0].ref.parent.parent.path;
            console.log('Sample parent path:', parentPath); // Should be remote_territories/x_y
        }
    } catch (e) {
        console.error('Query failed:', e.message);
    }
}

checkHistory().catch(console.error);
