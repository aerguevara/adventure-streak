const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function listNovActivities() {
    console.log(`Listing all November activities for user: ${userId}`);
    const snapshot = await db.collection('activities')
        .where('userId', '==', userId)
        .get();

    const novActivities = snapshot.docs.filter(doc => {
        const date = doc.data().startDate.toDate();
        return date.getMonth() === 10 && date.getFullYear() === 2025; // November is index 10
    });

    console.log(`Found ${novActivities.length} November activities.`);

    novActivities.forEach(doc => {
        const data = doc.data();
        console.log(`- ID: ${doc.id} | Date: ${data.startDate.toDate().toISOString()} | Name: ${data.workoutName} | XP: ${data.xpBreakdown?.total}`);
    });
}

listNovActivities().catch(console.error);
