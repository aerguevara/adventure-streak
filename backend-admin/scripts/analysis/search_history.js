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

async function searchHistory() {
    console.log("Searching history subcollections...");
    const historyQuery = await db.collectionGroup('history')
        .where('userId', '==', userId)
        .orderBy('timestamp', 'asc')
        .limit(1)
        .get();

    if (!historyQuery.empty) {
        const firstEntry = historyQuery.docs[0].data();
        const date = firstEntry.timestamp?.toDate ? firstEntry.timestamp.toDate() : new Date(0);
        console.log(`Earliest history entry found: ${date.toISOString()} | interaction: ${firstEntry.interaction}`);
    } else {
        console.log("No history found for user.");
    }

    process.exit(0);
}

searchHistory().catch(console.error);
