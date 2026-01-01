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

const db = admin.firestore();

async function deepDive() {
    console.log("--- SEARCHING PRIMARY DB ---");
    const activitiesSnapshot = await db.collection('activities')
        .where('userId', '==', userId)
        .get();

    let totalXP = 0;
    const activities = [];
    activitiesSnapshot.forEach(doc => {
        const data = doc.data();
        const date = data.startDate ? (data.startDate.toDate ? data.startDate.toDate() : new Date(data.startDate)) : new Date(0);
        activities.push({ date, xp: data.xpBreakdown?.total || 0 });
    });

    activities.sort((a, b) => a.date - b.date);
    if (activities.length > 0) {
        console.log(`Earliest Primary Activity: ${activities[0].date.toISOString()}`);
    }
    activities.forEach(a => totalXP += a.xp);
    console.log(`Primary Activities Total XP: ${totalXP}`);

    console.log("--- SEARCHING LOGS/METADATA ---");
    // Sometimes there are legacy collections or "history"
    const historySnapshot = await db.collectionGroup('history')
        .where('userId', '==', userId)
        .limit(10)
        .get();
    console.log(`Found ${historySnapshot.size} history entries.`);
    historySnapshot.forEach(doc => {
        const data = doc.data();
        const date = data.timestamp?.toDate ? data.timestamp.toDate() : new Date(0);
        console.log(`History entry: ${date.toISOString()} | interaction: ${data.interaction}`);
    });

    // Check for another possible project ID if it was renamed
    console.log("Current Project ID:", admin.app().options.projectId);

    process.exit(0);
}

deepDive().catch(console.error);
