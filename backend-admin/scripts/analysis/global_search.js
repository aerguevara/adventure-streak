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

async function globalSearch() {
    const collections = await db.listCollections();
    console.log(`Searching across ${collections.length} collections...`);

    for (const col of collections) {
        try {
            const q = await col.where('userId', '==', userId).limit(5).get();
            if (!q.empty) {
                console.log(`Found in [${col.id}]: ${q.size} documents.`);
                q.docs.forEach(d => {
                    const data = d.data();
                    const date = data.timestamp || data.createdAt || data.date || data.startDate || data.endDate;
                    const dateVal = date?.toDate ? date.toDate() : (date ? new Date(date) : null);
                    console.log(`   - Doc ID: ${d.id} | Date: ${dateVal?.toISOString() || 'N/A'}`);
                });
            }
        } catch (e) {
            // Probably doesn't have userId field
        }
    }

    process.exit(0);
}

globalSearch().catch(console.error);
