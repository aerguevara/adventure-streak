
import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { readFileSync } from "fs";

const USER_ID = "i1CEf9eU4MhEOabFGrv2ymPSMFH3";

async function main() {
    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({ credential: cert(serviceAccount), projectId: "adventure-streak" });
    }

    const db = getFirestore(); // PRO
    console.log(`Fixing user: ${USER_ID}`);

    // 1. Get all activities again
    const snapshots = await db.collection("activities").where("userId", "==", USER_ID).get();
    const activities = snapshots.docs.map(d => {
        const data = d.data() as any;
        return {
            id: d.id,
            ref: d.ref,
            endDate: data.endDate.toDate()
        };
    });

    // 2. Identify November trash
    const novActivities = activities.filter(a => a.endDate < new Date("2025-12-01"));
    console.log(`Found ${novActivities.length} November activities to delete.`);

    // 3. Identify Latest Activity
    const validActivities = activities.filter(a => a.endDate >= new Date("2025-12-01"));
    validActivities.sort((a, b) => b.endDate.getTime() - a.endDate.getTime());

    if (validActivities.length === 0) {
        console.error("No valid activities found!");
        return;
    }

    const latestActivity = validActivities[0];
    console.log(`Latest Valid Activity: ${latestActivity.id} at ${latestActivity.endDate.toISOString()}`);

    // 4. Execute Fixes
    const batch = db.batch();

    // Delete Nov
    if (novActivities.length > 0) {
        novActivities.forEach(a => {
            batch.delete(a.ref);
        });
        console.log(`Queued deletion of ${novActivities.length} activities.`);
    }

    // Update User Profile
    const userRef = db.collection("users").doc(USER_ID);
    batch.update(userRef, {
        lastActivityDate: Timestamp.fromDate(latestActivity.endDate),
        lastUpdated: Timestamp.now()
    });
    console.log(`Queued update for user lastActivityDate to ${latestActivity.endDate.toISOString()}`);

    await batch.commit();
    console.log("✅ Fix applied successfully.");
}

main().catch(console.error);
