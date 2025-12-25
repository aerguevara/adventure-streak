const admin = require('firebase-admin');
const path = require('path');

// Path to your service account key
const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/tests/e2e_territories/service-account.json';
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const targetUid = 'i1CEf9eU4MhEOabFGrv2ymPSMFH3';
const newName = 'Dania Perpiña';

async function normalizeUser() {
    console.log(`🚀 Starting normalization for user: ${targetUid} -> "${newName}"`);

    const batch = db.batch();

    // 1. Update User Document
    const userRef = db.collection('users').doc(targetUid);
    batch.set(userRef, { displayName: newName, lastUpdated: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    console.log('✅ Queued user document update.');

    // 2. Update Feed
    console.log('🔍 Searching feed documents...');
    const feedSnap = await db.collection('feed').where('userId', '==', targetUid).get();
    feedSnap.forEach(doc => {
        batch.update(doc.ref, { relatedUserName: newName });
    });
    console.log(`✅ Queued ${feedSnap.size} feed updates.`);

    // 3. Update Notifications (as sender)
    console.log('🔍 Searching notifications sent by user...');
    const notifSnap = await db.collection('notifications').where('senderId', '==', targetUid).get();
    notifSnap.forEach(doc => {
        batch.update(doc.ref, { senderName: newName });
    });
    console.log(`✅ Queued ${notifSnap.size} notification updates.`);

    // 4. Update Social Graph (Followers/Following)
    // We need to find everyone this user follows, and update her name in THEIR followers list
    console.log('🔍 Searching social graph (following)...');
    const followingSnap = await db.collection('users').doc(targetUid).collection('following').get();
    for (const doc of followingSnap.docs) {
        const followedUserId = doc.id;
        const ref = db.collection('users').doc(followedUserId).collection('followers').doc(targetUid);
        batch.set(ref, { displayName: newName }, { merge: true });
    }
    console.log(`✅ Queued her name update in ${followingSnap.size} users she follows.`);

    // We need to find everyone who follows this user, and update her name in THEIR following list
    console.log('🔍 Searching social graph (followers)...');
    const followersSnap = await db.collection('users').doc(targetUid).collection('followers').get();
    for (const doc of followersSnap.docs) {
        const followerUserId = doc.id;
        const ref = db.collection('users').doc(followerUserId).collection('following').doc(targetUid);
        batch.set(ref, { displayName: newName }, { merge: true });
    }
    console.log(`✅ Queued her name update in ${followersSnap.size} users who follow her.`);

    // 5. Commit Batch
    console.log('💾 Committing changes...');
    await batch.commit();
    console.log('🏁 Normalization complete!');
}

normalizeUser().catch(err => {
    console.error('❌ Error during normalization:', err);
    process.exit(1);
});
