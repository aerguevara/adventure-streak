const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function listAllDates() {
    console.log(`Listing all activity dates for user: ${userId}`);
    const snapshot = await db.collection('activities')
        .where('userId', '==', userId)
        .get();

    console.log(`Found ${snapshot.size} activities.`);

    const activities = snapshot.docs.map(doc => ({
        id: doc.id,
        date: doc.data().startDate.toDate()
    }));

    activities.sort((a, b) => a.date - b.date);

    activities.forEach(a => {
        console.log(`${a.date.toISOString()} | ID: ${a.id}`);
    });
}

listAllDates().catch(console.error);
