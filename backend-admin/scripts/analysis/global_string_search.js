const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const SEARCH_STRING = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function globalSearch() {
    console.log(`Global search for string: ${SEARCH_STRING}`);

    // We can't query all collections at once without listing them first
    const collections = await db.listCollections();

    for (const col of collections) {
        console.log(`Searching collection: ${col.id}`);
        // This is slow but thorough for a few collections
        const snapshot = await col.get();
        snapshot.forEach(doc => {
            const json = JSON.stringify(doc.data());
            if (json.includes('2025-11-30') && json.includes(SEARCH_STRING)) {
                console.log(`🎯 MATCH in ${col.id}/${doc.id}`);
                console.log(json);
            }
        });
    }
}

globalSearch().catch(console.error);
