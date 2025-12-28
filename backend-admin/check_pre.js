const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

if (!fs.existsSync(serviceAccountPath)) {
    console.error('Service account file not found');
    process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function findInAltDB() {
    // Try to access the PRE database if possible
    try {
        const preDB = admin.firestore('adventure-streak-pre');
        const activitiesSnapshot = await preDB.collection('activities')
            .where('userId', '==', userId)
            .get();

        console.log(`[PRE DB] Found ${activitiesSnapshot.size} activities.`);
        activitiesSnapshot.forEach(doc => {
            const data = doc.data();
            const date = data.startDate ? (data.startDate.toDate ? data.startDate.toDate() : new Date(data.startDate)) : new Date(0);
            console.log(`[PRE DB] ${date.toISOString()} | XP: ${data.xpBreakdown?.total || 0} | ${data.workoutName || data.activityType}`);
        });
    } catch (e) {
        console.log(`[PRE DB] Error or No PRE database found: ${e.message}`);
    }

    process.exit(0);
}

findInAltDB().catch(console.error);
