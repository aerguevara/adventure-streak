import * as admin from 'firebase-admin';
import * as path from 'path';

// Relative path to service account
const serviceAccountPath = path.resolve(__dirname, '../../secrets/serviceAccount.json');

async function insertGlobalCode(databaseId: string, label: string) {
    console.log(`\n🚀 [${label}] Processing database: ${databaseId}`);

    // Initialize app if not already initialized
    const appName = `app-${databaseId.replace(/[()]/g, '')}`;
    let app: admin.app.App;

    if (admin.apps.find(a => a?.name === appName)) {
        app = admin.app(appName);
    } else {
        app = admin.initializeApp({
            credential: admin.credential.cert(require(serviceAccountPath)),
            projectId: "adventure-streak"
        }, appName);
    }

    const db = app.firestore();
    const now = new Date();
    const oneMonthFromNow = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    const codeId = "LIMITED2026";
    const globalRef = db.collection("global_invitations").doc(codeId);

    await globalRef.set({
        issuer: "SYSTEM-MANUAL",
        startsAt: admin.firestore.Timestamp.fromDate(now),
        endsAt: admin.firestore.Timestamp.fromDate(oneMonthFromNow),
        active: true,
        usageCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ [${label}] Global code ${codeId} inserted successfully.`);
}

async function run() {
    try {
        // Run for PRO
        await insertGlobalCode("(default)", "PRO");

        // Run for PRE
        await insertGlobalCode("adventure-streak-pre", "PRE");

        console.log("\n✨ All operations completed successfully.");
        process.exit(0);
    } catch (error) {
        console.error("\n❌ Error during insertion:", error);
        process.exit(1);
    }
}

run();
