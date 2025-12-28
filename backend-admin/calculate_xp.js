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

async function deepAnalyze() {
    let totalXP = 0;
    let activityCount = 0;

    // 1. Get ALL activities for this user
    const activitiesSnapshot = await db.collection('activities')
        .where('userId', '==', userId)
        .get();

    console.log(`Found ${activitiesSnapshot.size} activities.`);

    const activities = [];
    activitiesSnapshot.forEach(doc => {
        const data = doc.data();
        const date = data.startDate ? (data.startDate.toDate ? data.startDate.toDate() : new Date(data.startDate)) :
            (data.endDate ? (data.endDate.toDate ? data.endDate.toDate() : new Date(data.endDate)) : new Date(0));

        activities.push({
            id: doc.id,
            date: date,
            xpTotal: (data.xpBreakdown && data.xpBreakdown.total) ? data.xpBreakdown.total : 0,
            breakdown: data.xpBreakdown || {},
            name: data.workoutName || data.activityType
        });
    });

    // Sort by date ASC
    activities.sort((a, b) => a.date - b.date);

    if (activities.length > 0) {
        console.log(`Absolutly oldest activity: ${activities[0].date.toISOString()} (${activities[0].name})`);
    }

    activities.forEach(a => {
        console.log(`${a.date.toISOString()} | XP: ${a.xpTotal.toString().padStart(4)} | ${a.name}`);
        totalXP += a.xpTotal;
    });

    console.log('-----------------------------------');
    console.log(`Deep calculated Total XP: ${totalXP}`);

    // Check for other collections that might have XP or milestones
    const userSnapshot = await db.collection('users').doc(userId).get();
    const userData = userSnapshot.data();
    console.log(`Current Firestore XP: ${userData.xp}`);
    console.log(`Current Firestore level: ${userData.level}`);
    console.log(`Current Firestore prestige: ${userData.prestige}`);

    process.exit(0);
}

deepAnalyze().catch(console.error);
