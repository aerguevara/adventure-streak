import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
    });
}

const db = getFirestore(admin.apps[0]!, "adventure-streak-pre");

async function cleanupMocks() {
    const dryRun = process.argv.includes('--dry-run') || !process.argv.includes('--execute');

    if (dryRun) {
        console.log('🔍 DRY RUN DETECTED. No changes will be made. Pass --execute to perform deletions.');
    } else {
        console.log('⚠️ EXECUTION MODE. Deleting data...');
    }

    const mockPrefixes = ['SIM_', 'MOCK_'];
    const testUserIds = [
        'CVZ34x99UuU6fCrOEc8Wg5nPYX82', // Anyelo / Thief
        'JaSFY1oPRUfJmuIgFf1LUzl6yOp2', // Victim
        'DQN1tyypsEZouksWzmFeSIYip7b2', // Another Victim
        'i1CEf9eU4MhEOabFGrv2ymPSMFH3'  // Dania
    ];

    // Date: 2026-01-02T00:00:00.000Z
    const cutOffDate = new Date('2026-01-02T00:00:00.000Z');

    console.log(`Criteria: Starts with ${mockPrefixes.join(', ')} OR (User in list AND Created > ${cutOffDate.toISOString()})`);

    let activitiesToDelete: string[] = [];
    let feedsToDelete: string[] = [];

    // 1. Scan Activities
    console.log('\n--- Scanning Activities ---');
    const activitiesSnap = await db.collection('activities').get();

    for (const doc of activitiesSnap.docs) {
        const id = doc.id;
        const data = doc.data();
        let shouldDelete = false;
        let reason = '';

        // Check Prefix
        if (mockPrefixes.some(prefix => id.startsWith(prefix))) {
            shouldDelete = true;
            reason = 'Prefix Match';
        }
        // Check User + Date
        else if (testUserIds.includes(data.userId)) {
            let createdAt: Date | null = null;
            if (data.timestamp) createdAt = data.timestamp.toDate();
            else if (data.date) createdAt = data.date.toDate();
            else if (data.startDate) createdAt = data.startDate.toDate();

            if (createdAt && createdAt > cutOffDate) {
                shouldDelete = true;
                reason = `Test User + Recent Date (${createdAt.toISOString()})`;
            }
        }

        if (shouldDelete) {
            console.log(`[DELETE] Activity ${id} (${reason}) - User: ${data.userId}`);
            activitiesToDelete.push(id);
        }
    }

    console.log(`Found ${activitiesToDelete.length} matching activities.`);

    // 2. Scan Feed based on activityId
    console.log('\n--- Scanning Feed ---');
    // We can't easily query feed by activityId IN [...large array...], so we scan recent feeds or scan all and check.
    // Given the request implies recent tests, scanning all might be okay if dataset is small, 
    // but better to query feed where matches occur.
    // For safety/simplicity in this script, let's scan all feed items. 
    // Optimization: Feed is likely smaller or we can query by date if indexed, but full scan is safer to catch "ghosts".

    const feedSnap = await db.collection('feed').get();
    for (const doc of feedSnap.docs) {
        const data = doc.data();
        const feedActivityId = data.activityId;

        // If the feed points to an activity we are deleting
        if (feedActivityId && activitiesToDelete.includes(feedActivityId)) {
            console.log(`[DELETE] Feed Item ${doc.id} (Linked to Activity ${feedActivityId})`);
            feedsToDelete.push(doc.id);
        }
        // Also check if feed item ITSELF looks like a mock/test (e.g. by date/user if activityId is missing/mismatch)
        // For now, adhere strictly to "generated in tests" which implies linkage.
    }

    console.log(`Found ${feedsToDelete.length} matching feed items.`);

    if (!dryRun) {
        const batchSize = 400; // Firestore batch limit is 500

        // Delete Activities
        for (let i = 0; i < activitiesToDelete.length; i += batchSize) {
            const batch = db.batch();
            const chunk = activitiesToDelete.slice(i, i + batchSize);
            chunk.forEach(id => {
                batch.delete(db.collection('activities').doc(id));
            });
            await batch.commit();
            console.log(`Deleted batch of ${chunk.length} activities.`);
        }

        // Delete Feeds
        for (let i = 0; i < feedsToDelete.length; i += batchSize) {
            const batch = db.batch();
            const chunk = feedsToDelete.slice(i, i + batchSize);
            chunk.forEach(id => {
                batch.delete(db.collection('feed').doc(id));
            });
            await batch.commit();
            console.log(`Deleted batch of ${chunk.length} feed items.`);
        }

        console.log('✅ Cleanup complete.');
    } else {
        console.log('\n🚫 Dry run finished. Pass --execute to delete.');
    }

    process.exit(0);
}

cleanupMocks();
