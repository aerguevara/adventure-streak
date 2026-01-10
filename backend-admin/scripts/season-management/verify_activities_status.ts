import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * VERIFY ACTIVITIES PROCESSING STATUS
 * 
 * Usage: npm run script scripts/season-management/verify_activities_status.ts [PRE|PRO]
 */

async function verifyActivities() {
    const envArg = process.argv[2] || "PRE";
    const isPro = envArg === "PRO";
    const projectId = isPro ? "adventure-streak" : "test-adventure-streak";
    const databaseId = isPro ? "(default)" : "adventure-streak-pre";

    console.log(`🔍 Verifying activities in ${envArg} (${projectId}/${databaseId})...`);

    const serviceAccountPath = path.resolve(process.cwd(), "secrets/serviceAccount.json");

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: projectId
        });
    }

    const db = getFirestore();
    // Guideline: Always use databaseId if not default
    const firestore = databaseId === "(default)" ? db : (db as any).terminate ? db : getFirestore(databaseId);

    // In some versions of firebase-admin, the way to get a specific database varies.
    // Based on previous scripts, we use the standard initialization if DBs are different.
    // Actually, in clear_database.ts we used:
    // const db = getFirestore(databaseId);

    const targetDb = databaseId === "(default)" ? db : getFirestore(databaseId);

    const activitiesCol = targetDb.collection("activities");
    const snapshot = await activitiesCol.get();

    console.log(`📊 Total activities found: ${snapshot.size}`);

    const nonCompleted = snapshot.docs.filter(doc => doc.data().processingStatus !== "completed");

    if (nonCompleted.length === 0) {
        console.log("✅ All activities are in 'completed' status.");
    } else {
        console.log(`⚠️ Found ${nonCompleted.length} activities with non-completed status:`);
        nonCompleted.forEach(doc => {
            console.log(`   - ${doc.id}: ${doc.data().processingStatus || "no status"}`);
        });
        process.exit(1);
    }
}

verifyActivities().catch(err => {
    console.error("❌ Verification failed:", err);
    process.exit(1);
});
