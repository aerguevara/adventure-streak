const admin = require('firebase-admin');

const { getFirestore } = require('firebase-admin/firestore');

// Initialize with service account
const serviceAccount = require('../../secrets/serviceAccount.json');

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const sourceDb = getFirestore(app);
const destDb = getFirestore(app, 'adventure-streak-pre');

console.log(`Project: ${serviceAccount.project_id}`);
console.log(`Source: (default)`);
console.log(`Dest: adventure-streak-pre`);

const collectionsToMigrate = [
    'users',
    'activities',
    'remote_territories',
    'feed',
    'notifications',
    'config',
    'activity_reactions',
    'activity_reaction_stats'
];

const subcollectionsMap = {
    'users': ['followers', 'following'],
    'activities': ['routes', 'territories'],
    'remote_territories': ['history']
};

async function migrateCollection(collectionName) {
    console.log(`\n--- Migrating collection: ${collectionName} ---`);
    const snapshot = await sourceDb.collection(collectionName).get();
    console.log(`Found ${snapshot.size} documents in ${collectionName}`);

    for (const doc of snapshot.docs) {
        const data = doc.data();
        await destDb.collection(collectionName).doc(doc.id).set(data);

        // Migrate subcollections if defined
        if (subcollectionsMap[collectionName]) {
            for (const subName of subcollectionsMap[collectionName]) {
                await migrateSubcollection(doc.ref, destDb.collection(collectionName).doc(doc.id), subName);
            }
        }
    }
}

async function migrateSubcollection(sourceDocRef, destDocRef, subName) {
    const snapshot = await sourceDocRef.collection(subName).get();
    if (snapshot.empty) return;

    console.log(`  -> Migrating subcollection ${subName} (${snapshot.size} docs)`);
    const batchSize = 400;
    let batch = destDb.batch();
    let count = 0;

    for (const doc of snapshot.docs) {
        batch.set(destDocRef.collection(subName).doc(doc.id), doc.data());
        count++;

        if (count % batchSize === 0) {
            await batch.commit();
            batch = destDb.batch();
        }
    }

    if (count % batchSize !== 0) {
        await batch.commit();
    }
}

async function runMigration() {
    try {
        for (const coll of collectionsToMigrate) {
            await migrateCollection(coll);
        }
        console.log('\n✅ Migration completed successfully!');
    } catch (error) {
        console.error('\n❌ Migration failed:', error);
    } finally {
        process.exit(0);
    }
}

runMigration();
