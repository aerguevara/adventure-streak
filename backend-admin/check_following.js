
const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkFollowing(userId) {
    console.log(`Checking following for user: ${userId}`);
    const followingSnapshot = await db.collection('users').doc(userId).collection('following').get();

    if (followingSnapshot.empty) {
        console.log('User is not following anyone.');
        return;
    }

    console.log(`User is following ${followingSnapshot.size} users:`);
    followingSnapshot.forEach(doc => {
        console.log(`- ${doc.id}: ${doc.data().displayName || 'No Name'}`);
    });
}

const targetUserId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
checkFollowing(targetUserId).catch(console.error);
