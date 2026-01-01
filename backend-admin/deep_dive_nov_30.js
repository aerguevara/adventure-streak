const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function deepDive() {
    console.log(`Deep dive for Nov 30th related data for user: ${userId}`);

    const collections = ['activities', 'feed', 'remote_territories'];

    for (const col of collections) {
        console.log(`Checking collection: ${col}`);
        const snapshot = await db.collection(col)
            .where('userId', '==', userId)
            .get();

        snapshot.forEach(doc => {
            const json = JSON.stringify(doc.data());
            if (json.includes('2025-11-30')) {
                console.log(`🎯 MATCH in ${col}/${doc.id}`);
                console.log(json);
            }
        });
    }
}

deepDive().catch(console.error);
