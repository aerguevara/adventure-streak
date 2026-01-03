
import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

const USER_ID = "i1CEf9eU4MhEOabFGrv2ymPSMFH3";

async function main() {
    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({ credential: cert(serviceAccount), projectId: "adventure-streak" });
    }

    const db = getFirestore(); // Default (PRO)
    console.log(`Analyzing activities for user: ${USER_ID}`);

    const snapshots = await db.collection("activities").where("userId", "==", USER_ID).get();
    console.log(`Found ${snapshots.size} activities.`);

    const activities = snapshots.docs.map(d => {
        const data = d.data() as any;
        return {
            id: d.id,
            ...data,
            endDate: data.endDate.toDate()
        };
    });

    // Sort by date
    activities.sort((a, b) => b.endDate.getTime() - a.endDate.getTime());

    let novCount = 0;
    let decCount = 0;
    let pendingCount = 0;

    console.log("\n--- Recent Activities ---");
    activities.slice(0, 10).forEach(a => {
        console.log(`[${a.endDate.toISOString()}] ${a.id} - Status: ${a.processingStatus} - XP: ${a.xpBreakdown?.total}`);
    });

    console.log("\n--- Analysis ---");
    activities.forEach(a => {
        if (a.endDate < new Date("2025-12-01")) novCount++;
        else decCount++;

        if (a.processingStatus === "pending") pendingCount++;
    });

    console.log(`Total: ${activities.length}`);
    console.log(`Nov (Should be gone): ${novCount}`);
    console.log(`Dec+ (Valid): ${decCount}`);
    console.log(`Pending: ${pendingCount}`);

    if (activities.length > 0) {
        console.log(`Latest Activity Date: ${activities[0].endDate.toISOString()}`);
    }
}

main().catch(console.error);
