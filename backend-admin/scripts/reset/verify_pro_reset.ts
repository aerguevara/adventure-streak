import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, Firestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

async function verifyReset() {
    const envArg = process.argv[2]?.toUpperCase();
    if (!envArg || !["PRE", "PRO"].includes(envArg)) {
        console.error("❌ Usage: npm run script scripts/reset/verify_pro_reset.ts [PRE|PRO]");
        process.exit(1);
    }

    const databaseId = envArg === "PRE" ? "adventure-streak-pre" : "(default)";
    console.log(`\n🔍 Verifying RESET state for ${envArg} (${databaseId})...\n`);

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(databaseId);
    const cutOffDate = new Date("2025-12-01T00:00:00Z");

    try {
        // 1. Check Silent Mode
        const maintenance = await db.collection("config").doc("maintenance").get();
        const isSilent = maintenance.data()?.silentMode;
        console.log(`${isSilent ? '✅' : '⚠️'} Silent Mode: ${isSilent ? 'ACTIVE' : 'INACTIVE'}`);

        // 2. Check Activities
        const oldActivities = await db.collection("activities").where("endDate", "<", cutOffDate).get();
        console.log(`${oldActivities.size === 0 ? '✅' : '❌'} Active activities before Dec 1st: ${oldActivities.size}`);

        const newActivities = await db.collection("activities").where("endDate", ">=", cutOffDate).get();
        console.log(`ℹ️ Active activities after Dec 1st: ${newActivities.size}`);

        // 3. Check Archives
        const activitiesArchive = await db.collection("activities_archive").get();
        console.log(`ℹ️ Activities in archive: ${activitiesArchive.size}`);

        const feedArchive = await db.collection("feed_archive").get();
        console.log(`ℹ️ Feed events in archive: ${feedArchive.size}`);

        // 4. Check Territories and Clean collections
        const territories = await db.collection("remote_territories").get();
        console.log(`${territories.size === 0 ? '✅' : '⚠️'} Current territories: ${territories.size}`);

        const feed = await db.collection("feed").get();
        console.log(`${feed.size <= newActivities.size ? '✅' : '⚠️'} Current feed events: ${feed.size} (Expected to match post-Dec activities)`);

        // 5. Check Random User Reset
        const users = await db.collection("users").limit(5).get();
        console.log(`\n👤 Sampling 5 users for reset status:`);
        users.docs.forEach(u => {
            const data = u.data();
            const isReset = data.xp === 0 && data.level === 1 && data.totalConqueredTerritories === 0;
            console.log(`   - User ${u.id}: ${isReset ? '✅ RESET' : '❌ NOT RESET'} (XP: ${data.xp}, Lvl: ${data.level})`);
        });

        console.log(`\n🏁 Verification Complete.`);
    } catch (err) {
        console.error("❌ Verification failed:", err);
        process.exit(1);
    }
}

verifyReset().catch(console.error);
