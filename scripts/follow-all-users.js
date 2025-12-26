const admin = require('firebase-admin');
const path = require('path');

// Path to your service account
const serviceAccountPath = path.resolve(__dirname, '../tests/e2e_territories/service-account.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function followAllUsers() {
    console.log('Fetching all users...');
    const usersSnapshot = await db.collection('users').get();
    const users = usersSnapshot.docs.map(doc => ({
        id: doc.id,
        data: doc.data()
    }));

    console.log(`Found ${users.length} users. Starting cross-follow process...`);

    let totalOperations = 0;
    let batch = db.batch();
    let operationCount = 0;

    for (const userA of users) {
        for (const userB of users) {
            if (userA.id === userB.id) continue;

            const now = admin.firestore.FieldValue.serverTimestamp();

            // User A follows User B
            const followingRef = db.collection('users').doc(userA.id).collection('following').doc(userB.id);
            batch.set(followingRef, {
                followedAt: now,
                displayName: userB.data.displayName || 'Usuario',
                avatarURL: userB.data.avatarURL || userB.data.photoURL || ''
            });
            operationCount++;

            // User B gets User A as follower
            const followerRef = db.collection('users').doc(userB.id).collection('followers').doc(userA.id);
            batch.set(followerRef, {
                followedAt: now,
                displayName: userA.data.displayName || 'Usuario',
                avatarURL: userA.data.avatarURL || userA.data.photoURL || ''
            });
            operationCount++;

            totalOperations += 2;

            // Commit batch every 400 operations (Firestore limit is 500)
            if (operationCount >= 400) {
                await batch.commit();
                console.log(`Committed ${totalOperations} operations...`);
                batch = db.batch();
                operationCount = 0;
            }
        }
    }

    if (operationCount > 0) {
        await batch.commit();
        console.log(`Final batch committed. Total operations: ${totalOperations}`);
    }

    console.log('Cross-follow process completed successfully!');
}

followAllUsers().catch(error => {
    console.error('Error during cross-follow process:', error);
    process.exit(1);
});
