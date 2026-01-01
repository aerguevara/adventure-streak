
const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function run() {
    const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

    // 1. Update user
    console.log(`Updating user ${userId}...`);
    await db.collection('users').doc(userId).update({
        hasAcknowledgedDecReset: false
    });
    console.log('User updated.');

    // 2. Find activity from Nov 30
    // Note: Firestore timestamps can be tricky in queries from Node.
    const startOfNov30 = new Date('2025-11-30T00:00:00Z');
    const endOfNov30 = new Date('2025-11-30T23:59:59Z');

    console.log('Searching for activity on Nov 30...');
    const activitiesSnapshot = await db.collection('activities')
        .where('userId', '==', userId)
        .get();

    const toDelete = activitiesSnapshot.docs.filter(doc => {
        const startDate = doc.data().startDate.toDate();
        return startDate >= startOfNov30 && startDate <= endOfNov30;
    });

    if (toDelete.length === 0) {
        console.log('No activity found on Nov 30.');
    } else {
        for (const doc of toDelete) { // Changed from activitiesSnapshot.docs to toDelete
            console.log(`Deleting activity ${doc.id}...`);
            await db.collection('activities').doc(doc.id).delete();

            // 3. Delete from feed
            const feedSnapshot = await db.collection('feed')
                .where('activityId', '==', doc.id)
                .get();

            for (const feedDoc of feedSnapshot.docs) {
                console.log(`Deleting feed item ${feedDoc.id}...`);
                await db.collection('feed').doc(feedDoc.id).delete();
            }
        }
        console.log('Cleanup complete.');
    }
}

run().catch(console.error);
