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

async function searchHistoryUnordered() {
    console.log("Searching history subcollections (unordered)...");
    const historyQuery = await db.collectionGroup('history')
        .where('userId', '==', userId)
        .limit(100)
        .get();

    if (!historyQuery.empty) {
        const dates = historyQuery.docs.map(doc => {
            const data = doc.data();
            return data.timestamp?.toDate ? data.timestamp.toDate() : new Date(0);
        });
        dates.sort((a, b) => a - b);
        console.log(`Earliest history entry found: ${dates[0].toISOString()}`);
        console.log(`Found ${historyQuery.size} history entries total.`);
    } else {
        console.log("No history found for user.");
    }

    process.exit(0);
}

searchHistoryUnordered().catch(console.error);
