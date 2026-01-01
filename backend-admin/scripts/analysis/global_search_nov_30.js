const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function searchGlobalNov30() {
    console.log(`Global search for Nov 30th workouts...`);

    const startOfNov30 = new Date('2025-11-30T00:00:00Z');
    const endOfNov30 = new Date('2025-11-30T23:59:59Z');

    const snapshot = await db.collection('activities')
        .where('startDate', '>=', startOfNov30)
        .where('startDate', '<=', endOfNov30)
        .get();

    if (snapshot.empty) {
        console.log('❌ No activities found globally for Nov 30th.');
        return;
    }

    console.log(`✅ Found ${snapshot.size} activities globally on Nov 30th.`);

    snapshot.forEach(doc => {
        const data = doc.data();
        console.log(`- ID: ${doc.id} | User: ${data.userId} | Date: ${data.startDate.toDate().toISOString()} | Name: ${data.workoutName || 'N/A'}`);
    });
}

searchGlobalNov30().catch(console.error);
