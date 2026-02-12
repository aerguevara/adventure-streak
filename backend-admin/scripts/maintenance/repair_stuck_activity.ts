import * as admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

async function main() {
    const activityId = process.argv[2] || "73187FDF-52A0-4288-B5D5-6BFA17AA092C";
    const databaseId = process.argv[3] || "adventure-streak-pre";
    const serviceAccountPath = path.resolve(__dirname, '../../secrets/serviceAccount.json');

    if (admin.apps.length === 0) {
        admin.initializeApp({
            credential: admin.credential.cert(require(serviceAccountPath)),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(databaseId);

    console.log(`\n🔧 REPAIRING ACTIVITY: ${activityId} in ${databaseId}`);

    const activityRef = db.collection("activities").doc(activityId);
    const doc = await activityRef.get();

    if (!doc.exists) {
        console.log("   ❌ Activity not found.");
        return;
    }

    const data = doc.data();
    console.log(`   Current Status: ${data?.processingStatus}`);

    await activityRef.update({
        processingStatus: "pending",
        lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: null // Clear any previous error
    });

    console.log("   ✅ Status reset to 'pending'. This should trigger the Cloud Function.");
}

main().catch(console.error);
