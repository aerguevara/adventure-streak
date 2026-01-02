import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

async function main() {
    const userId = process.argv[2] || "i1CEf9eU4MhEOabFGrv2ymPSMFH3";
    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore();

    console.log(`\n🔍 CHECKING ACTIVITY PROCESSING STATUS FOR USER: ${userId}`);

    const snapshots = await db.collection("activities")
        .where("userId", "==", userId)
        .where("processingStatus", "!=", "completed")
        .get();

    if (snapshots.empty) {
        console.log("   ✅ All activities for this user are already completed.");
    } else {
        console.log(`   ⚠️ Found ${snapshots.size} activities NOT completed:`);
        snapshots.forEach(doc => {
            const data = doc.data();
            console.log(`      📍 ID: ${doc.id} | Status: ${data.processingStatus} | Start: ${data.startDate?.toDate().toISOString()}`);
        });
    }
}

main().catch(console.error);
