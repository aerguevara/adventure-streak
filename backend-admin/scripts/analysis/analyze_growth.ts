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
    const now = new Date();
    const todayReset = new Date("2026-01-02T00:00:00Z"); // Approx 01:00 local
    const decStart = new Date("2025-12-01T00:00:00Z");

    console.log(`\n📊 ANALYZING GROWTH FOR USER: ${userId}`);
    console.log(`   Period: Since Reset (${todayReset.toISOString()}) to Now (${now.toISOString()})`);

    // 1. User Profile
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
        console.error("❌ User not found");
        return;
    }
    const userData = userDoc.data()!;
    console.log(`\n👤 Profile:`);
    console.log(`   Display Name: ${userData.displayName}`);
    console.log(`   Level: ${userData.level}`);
    console.log(`   Total XP: ${userData.xp}`);
    console.log(`   Cells Owned: ${userData.totalCellsOwned}`);

    // 2. Activities
    console.log(`\n🏃 Activities Since Dec 1st:`);
    // Fetch all user activities and filter in memory to avoid index requirement
    const activitiesSnapshot = await db.collection("activities")
        .where("userId", "==", userId)
        .get();

    const activities = activitiesSnapshot.docs.filter(doc => {
        const start = doc.data().startDate.toDate();
        return start >= decStart;
    });

    let totalXpToday = 0;
    let totalXpReprocessed = 0;
    let activitiesTodayCount = 0;
    let activitiesReprocessedCount = 0;

    const sortedActivities = activities.sort((a, b) => b.data().startDate.toDate().getTime() - a.data().startDate.toDate().getTime());

    for (const doc of sortedActivities) {
        const data = doc.data();
        const start = data.startDate.toDate();
        const xp = data.xpBreakdown?.total || 0;

        if (start >= todayReset) {
            console.log(`   ✅ [TODAY] ${start.toISOString()} - ${data.workoutName || 'Unknown'} - XP: ${xp}`);
            totalXpToday += xp;
            activitiesTodayCount++;
        } else {
            // These were reprocessed today if a reset happened at 01:00
            totalXpReprocessed += xp;
            activitiesReprocessedCount++;
        }
    }

    console.log(`\n📈 Activity Summary:`);
    console.log(`   Today's Activities: ${activitiesTodayCount} (Total XP: ${totalXpToday})`);
    console.log(`   Reprocessed Activities (from Dec): ${activitiesReprocessedCount} (Total XP: ${totalXpReprocessed})`);
    console.log(`   Calculated Total XP: ${totalXpToday + totalXpReprocessed}`);

    // 3. Territories
    console.log(`\n🗺️ Recent Territories (Conquered/Defended Today):`);
    const territories = await db.collection("remote_territories")
        .where("userId", "==", userId)
        .get();

    let territoriesToday = 0;
    for (const doc of territories.docs) {
        const data = doc.data();
        const lastConquered = data.lastConqueredAt?.toDate();
        if (lastConquered && lastConquered >= todayReset) {
            console.log(`   📍 ${data.id} - Conquered at: ${lastConquered.toISOString()}`);
            territoriesToday++;
        }
    }
    console.log(`   Total territories interacted with today: ${territoriesToday}`);

    console.log(`\n📝 CONCLUSION:`);
    if (userData.xp === totalXpToday + totalXpReprocessed) {
        console.log(`   ✅ XP matches exactly the sum of reprocessed activities since Dec 1st.`);
    } else {
        console.log(`   ⚠️ XP mismatch! (Diff: ${userData.xp - (totalXpToday + totalXpReprocessed)}). Check for other XP sources (badges, missions).`);
    }
}

main().catch(console.error);
