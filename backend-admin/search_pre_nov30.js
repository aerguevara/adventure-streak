const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// Correct syntax for specific database in recent firebase-admin
const db = getFirestore('adventure-streak-pre');

async function searchNov30InPre(userId) {
    console.log(`Deep Dive Search for Nov 30 in PRE database for user: ${userId}`);

    const collections = ['activities', 'feed', 'remote_territories'];
    const targetDateStr = '2025-11-30';

    for (const collName of collections) {
        console.log(`\nScanning collection: ${collName}`);
        const snapshot = await db.collection(collName).get();

        let foundCount = 0;
        snapshot.forEach(doc => {
            const dataStr = JSON.stringify(doc.data());
            if (dataStr.includes(targetDateStr) || (doc.data().userId === userId && dataStr.includes('2025-11'))) {
                console.log(`- MATCH FOUND in ${collName}/${doc.id}`);
                // Log more details if it's the specific target date
                if (dataStr.includes(targetDateStr)) {
                    console.log(`  Data: ${dataStr.substring(0, 500)}...`);
                    foundCount++;
                }
            }
        });

        if (foundCount === 0) {
            console.log(`No explicit Nov 30 matches in ${collName}.`);
        }
    }
}

const targetUserId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
searchNov30InPre(targetUserId).catch(console.error);
