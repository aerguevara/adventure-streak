const admin = require('firebase-admin');

if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();

async function testFetch() {
    const ids = ['-1817_20224'];
    console.log(`Querying remote_territories for IDs: ${ids}`);

    try {
        const refs = ids.map(id => db.collection('remote_territories').doc(id));
        const snapshot = await db.getAll(...refs);

        snapshot.forEach(doc => {
            if (doc.exists) {
                console.log(`✅ Found document ${doc.id}:`, doc.data());
            } else {
                console.log(`❌ Document ${doc.id} does not exist!`);
            }
        });
    } catch (error) {
        console.error('❌ Query failed:', error);
    }
}

testFetch();
