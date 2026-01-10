import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * VERIFY TERRITORIES CONSISTENCY
 * 
 * Compares the total number of documents in "remote_territories" 
 * with the sum of "totalCellsOwned" across all users.
 * 
 * Usage: npm run script scripts/season-management/verify_territories_consistency.ts [PRE|PRO]
 */

async function verifyConsistency() {
    const envArg = process.argv[2] || "PRE";
    const isPro = envArg === "PRO";
    const projectId = isPro ? "adventure-streak" : "test-adventure-streak";
    const databaseId = isPro ? "(default)" : "adventure-streak-pre";

    console.log(`🔍 Verifying territory consistency in ${envArg} (${projectId}/${databaseId})...`);

    const serviceAccountPath = path.resolve(process.cwd(), "secrets/serviceAccount.json");

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: projectId
        });
    }

    const db = getFirestore();
    const targetDb = databaseId === "(default)" ? db : getFirestore(databaseId);

    // 1. Get total territories from remote_territories collection
    console.log("📦 Counting remote_territories...");
    const territoriesSnapshot = await targetDb.collection("remote_territories").get();
    const totalGlobalTerritories = territoriesSnapshot.size;

    // 2. Sum totalCellsOwned from users
    console.log("👤 Summing totalCellsOwned from users...");
    const usersSnapshot = await targetDb.collection("users").get();
    let sumUserTerritories = 0;

    usersSnapshot.forEach(doc => {
        const data = doc.data();
        const owned = data.totalCellsOwned || 0;
        sumUserTerritories += owned;
        if (owned > 0) {
            console.log(`   - User ${doc.id}: ${owned} cells`);
        }
    });

    console.log("\n📊 Results:");
    console.log(`   - Global Territories (remote_territories): ${totalGlobalTerritories}`);
    console.log(`   - Sum of users' totalCellsOwned:         ${sumUserTerritories}`);

    if (totalGlobalTerritories === sumUserTerritories) {
        console.log("\n✅ CONSISTENCY CHECK PASSED: The counts match perfectly.");
    } else {
        const diff = Math.abs(totalGlobalTerritories - sumUserTerritories);
        console.log(`\n❌ CONSISTENCY CHECK FAILED: There is a difference of ${diff} cells.`);
        if (totalGlobalTerritories > sumUserTerritories) {
            console.log("   (Orphaned territories found in remote_territories or users missing updates)");
        } else {
            console.log("   (Users have more cells recorded than exist in remote_territories)");
        }
        process.exit(1);
    }
}

verifyConsistency().catch(err => {
    console.error("❌ Verification failed:", err);
    process.exit(1);
});
