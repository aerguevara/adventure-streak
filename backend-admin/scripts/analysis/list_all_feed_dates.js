const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function listAllFeedDates() {
    console.log(`Listing all feed dates for user: ${userId}`);
    const snapshot = await db.collection('feed')
        .where('userId', '==', userId)
        .get();

    console.log(`Found ${snapshot.size} feed items.`);

    const items = snapshot.docs.map(doc => ({
        id: doc.id,
        date: doc.data().date ? (doc.data().date.toDate ? doc.data().date.toDate() : new Date(doc.data().date)) : null,
        activityId: doc.data().activityId,
        type: doc.data().type
    }));

    items.sort((a, b) => (a.date || 0) - (b.date || 0));

    items.forEach(a => {
        console.log(`${a.date ? a.date.toISOString() : 'NULL'} | ID: ${a.id} | ActivityId: ${a.activityId} | Type: ${a.type}`);
    });
}

listAllFeedDates().catch(console.error);
