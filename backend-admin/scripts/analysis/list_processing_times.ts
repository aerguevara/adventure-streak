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
    const todayReset = new Date("2026-01-02T00:00:00Z");

    console.log(`\n🕒 PROCESSING COMPLETION TIMES FOR USER: ${userId}`);

    const snapshots = await db.collection("activities")
        .where("userId", "==", userId)
        .get();

    const activities = snapshots.docs
        .map(doc => ({ id: doc.id, ...doc.data() } as any))
        .filter(data => data.lastUpdatedAt && data.lastUpdatedAt.toDate() >= todayReset)
        .sort((a, b) => a.lastUpdatedAt.toDate().getTime() - b.lastUpdatedAt.toDate().getTime());

    if (activities.length === 0) {
        console.log("   ❌ No activities were updated today.");
    } else {
        console.log(`   Found ${activities.length} activities processed today:`);
        activities.forEach(data => {
            const completedAt = data.lastUpdatedAt.toDate();
            const originalStart = data.startDate?.toDate();
            console.log(`      🏁 Finished: ${completedAt.toISOString()} | Activity Date: ${originalStart?.toISOString() || 'N/A'} | ID: ${data.id}`);
        });
    }
}

main().catch(console.error);
