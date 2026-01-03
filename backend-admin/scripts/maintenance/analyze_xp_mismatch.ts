
import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

const USER_ID = "i1CEf9eU4MhEOabFGrv2ymPSMFH3";
const RESET_REPORT_TIME = new Date("2026-01-02T22:01:03Z"); // Time from the markdown report

async function main() {
    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({ credential: cert(serviceAccount), projectId: "adventure-streak" });
    }

    const db = getFirestore();
    console.log(`Analyzing XP for user: ${USER_ID}`);

    // 1. Get User Profile
    const userDoc = await db.collection("users").doc(USER_ID).get();
    const userData = userDoc.data() as any;
    console.log(`\n👤 User Profile:`);
    console.log(`- Current XP: ${userData.xp}`);
    console.log(`- Last Updated: ${userData.lastUpdated?.toDate().toISOString()}`);

    // 2. Get All Valid Activities
    const snapshots = await db.collection("activities")
        .where("userId", "==", USER_ID)
        .get();

    console.log(`\n📂 Found ${snapshots.size} valid activities (Dec+).`);

    let calculatedTotalXP = 0;
    const activitiesAfterReport: any[] = [];

    snapshots.docs.forEach(d => {
        const data = d.data() as any;
        const xp = data.xpBreakdown?.total || 0;
        calculatedTotalXP += xp;

        const updatedAt = data.lastUpdatedAt?.toDate();
        if (updatedAt && updatedAt > RESET_REPORT_TIME) {
            activitiesAfterReport.push({
                id: d.id,
                updatedAt: updatedAt,
                xp: xp,
                name: data.workoutName || "Unknown"
            });
        }
    });

    console.log(`\n🧮 Calculated XP from Activity History: ${calculatedTotalXP}`);
    console.log(`📉 User Profile XP: ${userData.xp}`);
    const diff = userData.xp - calculatedTotalXP;
    console.log(`⚠️ Discrepancy: ${diff} XP`);

    if (activitiesAfterReport.length > 0) {
        console.log(`\n🕒 Activities updated AFTER report generation (${RESET_REPORT_TIME.toISOString()}):`);
        activitiesAfterReport.sort((a, b) => a.updatedAt.getTime() - b.updatedAt.getTime());

        let lateXPSum = 0;
        activitiesAfterReport.forEach(a => {
            console.log(`- [${a.updatedAt.toISOString()}] ${a.id} (+${a.xp} XP)`);
            lateXPSum += a.xp;
        });
        console.log(`\n👉 Total XP linked to 'late' updates: ${lateXPSum}`);
    } else {
        console.log("\n✅ No activities were updated after the report.");
    }

    const baseline = 7738;
    console.log(`\n📊 Baseline Analysis:`);
    console.log(`XP at Report (22:01): ${baseline}`);
    console.log(`XP Added Later: ${userData.xp - baseline}`);
}

main().catch(console.error);
