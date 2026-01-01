
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = getFirestore('adventure-streak-pre');
const TARGET_USER_ID = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
const ACTIVITY_ID = 'AB1E9C16-8767-416D-A7F3-061CE84E568B';
const FEED_ID = 'QbSSdcoHAAI7b1Q2m9kG';
const XP_TO_REVERT = 6;

async function deletePhantomWorkout() {
    console.log(`Starting deletion of phantom workout from PRE: ${ACTIVITY_ID}`);

    try {
        const batch = db.batch();

        // 1. Delete Activity
        const activityRef = db.collection('activities').doc(ACTIVITY_ID);
        batch.delete(activityRef);

        // 2. Delete Feed Item
        const feedRef = db.collection('feed').doc(FEED_ID);
        batch.delete(feedRef);

        // 3. Revert XP
        const userRef = db.collection('users').doc(TARGET_USER_ID);
        batch.update(userRef, {
            xp: admin.firestore.FieldValue.increment(-XP_TO_REVERT)
        });

        await batch.commit();
        console.log('Successfully deleted activity, feed item and reverted XP in PRE database.');

        // 4. Cleanup subcollections if any
        console.log('Cleaning up subcollections...');
        const collections = ['routes', 'territories'];
        for (const sub of collections) {
            const subdocs = await activityRef.collection(sub).listDocuments();
            for (const doc of subdocs) {
                await doc.delete();
            }
        }
        console.log('Cleanup complete.');

    } catch (error) {
        console.error('Error during deletion:', error);
    }
}

deletePhantomWorkout().catch(console.error);
