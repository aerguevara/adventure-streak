import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

async function audit() {
    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore("(default)");
    const cutOffDate = new Date("2025-12-01T00:00:00Z");

    console.log("\n--- AUDIT: OLD ACTIVITIES (Before Dec 1st) ---");
    const oldActivities = await db.collection("activities").where("endDate", "<", cutOffDate).get();
    console.log(`Found ${oldActivities.size} activities:`);
    oldActivities.docs.forEach(doc => {
        const data = doc.data();
        console.log(`- ID: ${doc.id}, EndDate: ${data.endDate?.toDate()?.toISOString()}, User: ${data.userId}, Type: ${data.activityType}`);
    });

    console.log("\n--- AUDIT: USER XP & LEVELS ---");
    const users = await db.collection("users").orderBy("xp", "desc").get();
    console.log(`Total users: ${users.size}`);
    users.docs.forEach((u, i) => {
        const data = u.data();
        console.log(`${i + 1}. User ${u.id}: XP: ${data.xp}, Lvl: ${data.level}, Territories: ${data.totalConqueredTerritories}`);
    });
}

audit().catch(console.error);
