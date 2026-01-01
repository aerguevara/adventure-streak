
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = getFirestore('adventure-streak-pre');

async function listUserActivitiesInPre(userId) {
    console.log(`Listing all activities in PRE database for user: ${userId}`);

    const snapshot = await db.collection('activities')
        .where('userId', '==', userId)
        .get();

    if (snapshot.empty) {
        console.log('No activities found for this user in PRE.');
        return;
    }

    snapshot.forEach(doc => {
        const data = doc.data();
        const date = data.startDate ? (data.startDate.toDate ? data.startDate.toDate() : data.startDate) : 'No Date';
        console.log(`- Activity ID: ${doc.id} | Date: ${date} | Name: ${data.workoutName || 'N/A'}`);
    });
}

const targetUserId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
listUserActivitiesInPre(targetUserId).catch(console.error);
