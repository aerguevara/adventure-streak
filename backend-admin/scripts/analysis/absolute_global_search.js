const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function absoluteGlobalSearch() {
    console.log(`Absolute global search for string: 2025-11-30`);

    const collections = await db.listCollections();

    for (const col of collections) {
        console.log(`Searching collection: ${col.id}`);
        const snapshot = await col.get();
        snapshot.forEach(doc => {
            const json = JSON.stringify(doc.data());
            if (json.includes('2025-11-30')) {
                console.log(`🎯 MATCH in ${col.id}/${doc.id}`);
                console.log(json);
            }
        });
    }
}

absoluteGlobalSearch().catch(console.error);
