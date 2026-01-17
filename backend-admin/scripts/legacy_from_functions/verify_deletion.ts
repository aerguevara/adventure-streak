import * as admin from 'firebase-admin';
import * as path from 'path';
import { getFirestore } from 'firebase-admin/firestore';

// Load service account
// Load service account (Adjusted for src/scripts/verify_deletion.ts)
const serviceAccountPath = require('path').resolve(__dirname, '../../secrets/serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: "adventure-streak"
    });
}

const db = getFirestore("adventure-streak-pre");
const auth = admin.auth();

const TARGET_USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82";

async function verifyDeletion() {
    console.log(`🔍 Verifying deletion and archival for user: ${TARGET_USER_ID}`);

    // Collections to check
    const activeCollections = [
        `users/${TARGET_USER_ID}`,
        'activities',
        'remote_territories',
        'feed',
        'notifications'
    ];

    const archiveCollections = [
        `archived_users/${TARGET_USER_ID}`,
        'archived_activities',
        'archived_remote_territories',
        'archived_feed',
        'archived_notifications'
    ];

    console.log("\n--- Active Collections (Should be empty) ---");
    for (const coll of activeCollections) {
        if (coll.includes('/')) {
            const doc = await db.doc(coll).get();
            console.log(`${coll.padEnd(40)}: ${doc.exists ? '❌ STILL EXISTS' : '✅ DELETED'}`);
        } else {
            const snapshot = await db.collection(coll).where('userId', '==', TARGET_USER_ID).get();
            console.log(`${coll.padEnd(40)}: ${snapshot.empty ? '✅ DELETED' : `❌ ${snapshot.size} DOCS REMAIN`}`);
        }
    }

    console.log("\n--- Archive Collections (Should have data) ---");
    for (const coll of archiveCollections) {
        if (coll.includes('/')) {
            const doc = await db.doc(coll).get();
            console.log(`${coll.padEnd(40)}: ${doc.exists ? '✅ ARCHIVED' : '❌ NOT FOUND'}`);

            // Subcollection Check for Users
            if (coll === `archived_users/${TARGET_USER_ID}` && doc.exists) {
                const subcols = await doc.ref.listCollections();
                if (subcols.length > 0) {
                    console.log(`${"  ↳ Subcollections (e.g. stats)".padEnd(40)}: ✅ ${subcols.length} FOUND (${subcols.map(s => s.id).join(', ')})`);
                } else {
                    console.log(`${"  ↳ Subcollections".padEnd(40)}: ⚠️ NONE FOUND (Might be okay if user had none)`);
                }
            }
        } else {
            const snapshot = await db.collection(coll).where('userId', '==', TARGET_USER_ID).get();
            console.log(`${coll.padEnd(40)}: ${snapshot.empty ? '❌ NOT FOUND' : `✅ ${snapshot.size} DOCS ARCHIVED`}`);
        }
    }

    // Check specific subcollections in active user to ensure they are GONE
    console.log("\n--- Active User Subcollections (Should be empty) ---");
    const userRef = db.doc(`users/${TARGET_USER_ID}`);
    const activeSubcols = await userRef.listCollections();
    if (activeSubcols.length > 0) {
        console.log(`${"  ↳ Subcollections".padEnd(40)}: ❌ STILL EXIST (${activeSubcols.map(s => s.id).join(', ')})`);
    } else {
        console.log(`${"  ↳ Subcollections".padEnd(40)}: ✅ DELETED`);
    }

    console.log("\n--- Firebase Authentication ---");
    try {
        await auth.getUser(TARGET_USER_ID);
        console.log(`${"Auth User".padEnd(40)}: ❌ STILL EXISTS`);
    } catch (error: any) {
        if (error.code === 'auth/user-not-found') {
            console.log(`${"Auth User".padEnd(40)}: ✅ DELETED`);
        } else {
            console.log(`${"Auth User".padEnd(40)}: ❌ ERROR: ${error.message}`);
        }
    }
}

verifyDeletion().catch(console.error);
