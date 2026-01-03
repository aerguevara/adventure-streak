
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

    const db = getFirestore(); // PRO
    console.log(`Analyzing deleted November activities XP contribution...`);

    // Fetch from ARCHIVE (Phase 1 should have put them there, or they might be lost if I just deleted them)
    // Wait, I deleted them in step 48 WITHOUT archiving them first (my fix script just did batch.delete).
    // So I can't check them in 'activities' collection anymore.
    // However, I can check 'activities_archive' to see if they exist there and sum their XP.

    const snapshots = await db.collection("activities_archive")
        .where("userId", "==", USER_ID)
        .get();

    let novXPSum = 0;
    let novCount = 0;

    console.log(`Found ${snapshots.size} archived activities.`);

    snapshots.docs.forEach(d => {
        const data = d.data();
        const date = data.endDate.toDate();
        if (date < new Date("2025-12-01")) {
            // Only count if it looks like it was recently processed (e.g. has xpBreakdown)
            // The Phase 1 archive copy happened BEFORE Phase 2/3/4.
            // But if Phase 4 processed the *originals* in 'activities' (which I just deleted),
            // those originals would have written to User XP.

            // Since I deleted the originals, I can't see their `xpBreakdown`.
            // But I can guess based on the archived versions IF they have XP data.
            // Or mostly, I can see if 771 approximates the XP of ~11 activities.

            const xp = data.xpBreakdown?.total || 0;
            novXPSum += xp;
            novCount++;
            console.log(`[${date.toISOString()}] ${d.id} - KP: ${xp}`);
        }
    });

    console.log(`\nNovember Archived XP Sum: ${novXPSum}`);
    console.log(`Count: ${novCount}`);
    console.log(`Target Discrepancy: 771`);
}

main().catch(console.error);
