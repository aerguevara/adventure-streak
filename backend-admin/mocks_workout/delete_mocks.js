const admin = require('firebase-admin');
const path = require('path');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccountPath = path.resolve(__dirname, '../secrets/serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

// Ensure correct DB
const db = getFirestore(admin.app(), 'adventure-streak-pre');

async function deleteMocks() {
    console.log("Deleting all mocks from debug_mock_workouts...");
    const collectionRef = db.collection('debug_mock_workouts');

    // Batch delete (limit 500 per batch)
    const snapshot = await collectionRef.limit(500).get();

    if (snapshot.empty) {
        console.log("No mocks found to delete.");
        return;
    }

    const batch = db.batch();
    snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Deleted ${snapshot.size} mocks.`);

    // Recurse if there might be more
    if (snapshot.size === 500) {
        await deleteMocks();
    }
}

deleteMocks().catch(console.error);
