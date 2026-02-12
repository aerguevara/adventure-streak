import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore, DocumentReference, WriteBatch } from "firebase-admin/firestore";
import { readFileSync } from "fs";

const CONCURRENCY_LIMIT = 20;
const BATCH_SIZE = 500;

async function clearPRE() {
    console.log("🧹 Starting OPTIMIZED TOTAL CLEAR of adventure-streak-pre...");

    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/backend-admin/secrets/serviceAccount.json";
    const databaseId = "adventure-streak-pre";

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(databaseId);

    const collections = await db.listCollections();

    for (const colRef of collections) {
        const colName = colRef.id;
        console.log(`   Cleaning collection: ${colName}...`);

        // Use recursiveDelete for massive speedup and thoroughness
        await db.recursiveDelete(colRef);
        console.log(`      ✅ Collection ${colName} cleared.`);
    }

    console.log("✨ PRE Environment cleared successfully.");
}

// Helper removed as recursiveDelete handles it internally
// async function deleteDocRecursive(docRef: DocumentReference) { ... }
// async function runInParallel<T>(items: T[], fn: (item: T) => Promise<void>) { ... }

function chunk<T>(array: T[], size: number): T[][] {
    return Array.from({ length: Math.ceil(array.length / size) }, (_, i) => array.slice(i * size, i * size + size));
}

clearPRE().catch(console.error);
