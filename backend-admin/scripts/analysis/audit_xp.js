const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';

if (!fs.existsSync(serviceAccountPath)) {
    console.error('Service account file not found');
    process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function auditAllUsers() {
    console.log("--- STARTING GLOBAL XP AUDIT ---");
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} users to audit.`);

    const report = [];

    for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const storedXP = userData.xp || 0;
        const storedLevel = userData.level || 1;
        const displayName = userData.displayName || "Unknown";

        // Sum activities
        const activitiesSnapshot = await db.collection('activities')
            .where('userId', '==', userId)
            .get();

        let calculatedXP = 0;
        activitiesSnapshot.forEach(doc => {
            const data = doc.data();
            calculatedXP += (data.xpBreakdown && data.xpBreakdown.total) ? data.xpBreakdown.total : 0;
        });

        const discrepancy = calculatedXP - storedXP;
        const calculatedLevel = 1 + Math.floor(calculatedXP / 1000);

        if (discrepancy !== 0 || calculatedLevel !== storedLevel) {
            report.push({
                userId,
                displayName,
                storedXP,
                calculatedXP,
                discrepancy,
                storedLevel,
                calculatedLevel,
                activityCount: activitiesSnapshot.size
            });
        }
    }

    console.log("--- AUDIT REPORT ---");
    if (report.length === 0) {
        console.log("✅ No discrepancies found!");
    } else {
        console.log(`❌ Found ${report.length} users with discrepancies:`);
        report.forEach(r => {
            console.log(`User: ${r.displayName} (${r.userId})`);
            console.log(`  Stored: ${r.storedXP} XP (Lvl ${r.storedLevel})`);
            console.log(`  Calculated: ${r.calculatedXP} XP (Lvl ${r.calculatedLevel})`);
            console.log(`  Discrepancy: ${r.discrepancy} XP`);
            console.log(`  Activities: ${r.activityCount}`);
            console.log("-----------------------------------");
        });
    }

    process.exit(0);
}

auditAllUsers().catch(console.error);
