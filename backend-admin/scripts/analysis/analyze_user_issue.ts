import * as admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

async function main() {
    const userId = "5CExEpO1mkQHlWo05VOjK2UtbDD2";
    const serviceAccountPath = path.resolve(__dirname, '../../secrets/serviceAccount.json');

    if (admin.apps.length === 0) {
        admin.initializeApp({
            credential: admin.credential.cert(require(serviceAccountPath)),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore("adventure-streak-pre");

    console.log(`\n🔍 ANALYZING ACTIVITIES FOR USER: ${userId} in PRE`);

    const snapshots = await db.collection("activities")
        .where("userId", "==", userId)
        .get();

    if (snapshots.empty) {
        console.log("   ❌ No activities found for this user in PRE.");
        return;
    }

    const activities = snapshots.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
    } as any));

    // Sort by timestamp or startDate
    activities.sort((a, b) => {
        const timeA = a.timestamp?.toMillis() || a.startDate?.toMillis() || 0;
        const timeB = b.timestamp?.toMillis() || b.startDate?.toMillis() || 0;
        return timeB - timeA;
    });

    console.log(`   Found ${activities.length} activities. Most recent:`);

    activities.slice(0, 5).forEach(activity => {
        console.log(`\n      📍 ID: ${activity.id}`);
        console.log(`         Type: ${activity.type}`);
        console.log(`         Status: ${activity.processingStatus}`);
        console.log(`         Start Date: ${activity.startDate?.toDate().toISOString()}`);
        console.log(`         Location Label: ${activity.locationLabel}`);
        console.log(`         Has Route: ${activity.hasRoute || false}`);
        console.log(`         Error: ${activity.error || 'None'}`);
        console.log(`         Step: ${activity.processingStep || 'N/A'}`);
    });
}

main().catch(console.error);
