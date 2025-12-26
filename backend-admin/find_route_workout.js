const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function findWorkoutWithRoute() {
    console.log('Searching for a workout with route data...');

    // Try to find one in 'activities' collection
    const snapshot = await db.collection('activities')
        .where('hasRoute', '==', true) // assuming we might have this flag, or just check fields
        .limit(5)
        .get();

    if (snapshot.empty) {
        // If no flag, just grab some and check fields
        const recent = await db.collection('activities')
            .orderBy('endDate', 'desc')
            .limit(100)
            .get();

        for (const doc of recent.docs) {
            const data = doc.data();
            if (data.route && data.route.length > 10) {
                console.log(`FOUND CANDIDATE: ${doc.id}`);
                console.log(JSON.stringify(data, null, 2));
                return;
            }
        }
        console.log('No route-heavy workouts found in recent 20.');
    } else {
        const doc = snapshot.docs[0];
        console.log(`FOUND CANDIDATE: ${doc.id}`);
        console.log(JSON.stringify(doc.data(), null, 2));
    }
}

findWorkoutWithRoute();
