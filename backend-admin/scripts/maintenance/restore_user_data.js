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
const auth = admin.auth();

async function restoreData() {
    const targetXP = 3648;
    const targetLevel = 4;
    const targetJoinedAt = new Date('2025-11-25T19:48:02.516Z');

    console.log(`Updating Firestore for user ${userId}...`);
    await db.collection('users').doc(userId).update({
        xp: targetXP,
        level: targetLevel,
        joinedAt: targetJoinedAt,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Updating Auth custom claims for user ${userId}...`);
    await auth.setCustomUserClaims(userId, {
        xp: targetXP,
        level: targetLevel
    });

    console.log('✅ Restoration complete.');
    process.exit(0);
}

restoreData().catch(console.error);
