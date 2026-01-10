import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";
import * as readline from "readline";

/**
 * OPTIMIZED DATABASE CLEAR
 * Focuses on cleaning PRE environment or specific database.
 */

async function clearPREDatabase() {
    const args = process.argv.slice(2);
    const envArg = args[0]?.toUpperCase() || "PRE";

    if (envArg !== "PRE") {
        console.error("❌ ERROR: This script is EXCLUSIVELY for the PRE environment (adventure-streak-pre).");
        console.error("   Production clearing is disabled for safety.");
        process.exit(1);
    }

    const databaseId = "adventure-streak-pre";
    console.log(`🧹 Starting OPTIMIZED CLEAR of PRE (${databaseId})...`);

    const serviceAccountPath = path.resolve(process.cwd(), "secrets/serviceAccount.json");

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(databaseId);

    const collections = [
        "activities", "activities_archive", "feed", "feed_archive",
        "notifications", "notifications_archive", "remote_territories",
        "activity_reactions", "activity_reaction_stats", "users",
        "reserved_icons", "debug_mock_workouts", "config",
        "activity_reactions_archive", "remote_territories_archive"
    ];

    for (const colName of collections) {
        console.log(`   Cleaning collection: ${colName}...`);
        const colRef = db.collection(colName);

        // Guidelines: recursiveDelete is the fastest way to clear collections
        await db.recursiveDelete(colRef);
    }

    console.log(`✨ PRE Environment cleared successfully.`);
}

clearPREDatabase().catch(console.error);
