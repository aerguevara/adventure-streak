import * as admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

// Parse arguments
const isExecute = process.argv.includes('--execute');
const env = process.argv.includes('--env') ? process.argv[process.argv.indexOf('--env') + 1] : 'pre';

console.log(`🚀 Starting Guest Cleanup Script`);
console.log(`Environment: ${env.toUpperCase()}`);
console.log(`Mode: ${isExecute ? '⚠️ EXECUTION' : '🔍 DRY RUN'}`);

// Initialize Firebase Admin
const serviceAccountPath = path.resolve(__dirname, '../../secrets/serviceAccount.json');
const projectId = "adventure-streak";
const databaseId = env === 'pro' ? '(default)' : 'adventure-streak-pre';

admin.initializeApp({
    credential: admin.credential.cert(require(serviceAccountPath)),
    projectId: projectId
});

const db = getFirestore(databaseId);

async function cleanupGuests() {
    console.log(`\n--- Fetching users from Firestore (${databaseId}) ---`);

    // We target users with invitationVerified: true AND (no email OR anonymous in Auth)
    // Firestore query first to narrow down
    const usersSnap = await db.collection('users').where('invitationVerified', '==', true).get();

    const candidates: any[] = [];

    for (const doc of usersSnap.docs) {
        const data = doc.data();
        const uid = doc.id;

        // If they have an email, they might not be a guest (unless we want to clean specific emails)
        // But guests generated in AuthenticationService.swift have email = nil
        if (data.email) {
            continue;
        }

        try {
            const authUser = await admin.auth().getUser(uid);
            const isAnonymous = authUser.providerData.length === 0;

            if (isAnonymous) {
                candidates.push({
                    uid,
                    displayName: data.displayName || 'Unknown',
                    joinedAt: data.joinedAt?.toDate() || 'Unknown',
                    xp: data.xp || 0
                });
            }
        } catch (error: any) {
            if (error.code === 'auth/user-not-found') {
                // If user is in Firestore but not in Auth, it's a ghost record
                candidates.push({
                    uid,
                    displayName: data.displayName || 'Unknown (Auth Deleted)',
                    joinedAt: data.joinedAt?.toDate() || 'Unknown',
                    xp: data.xp || 0,
                    ghost: true
                });
            } else {
                console.error(`Error checking user ${uid}:`, error.message);
            }
        }
    }

    console.log(`Found ${candidates.length} candidate guest users.\n`);

    if (candidates.length === 0) {
        console.log('No guests found matching criteria.');
        process.exit(0);
    }

    // List candidates
    console.log('UID | Display Name | Joined At | XP');
    console.log('--------------------------------------------------');
    candidates.forEach(c => {
        console.log(`${c.uid} | ${c.displayName} | ${c.joinedAt} | ${c.xp} ${c.ghost ? '(GHOST)' : ''}`);
    });

    if (isExecute) {
        console.log('\n⚠️ ATTENTION: Permanent deletion starting in 5 seconds...');
        await new Promise(resolve => setTimeout(resolve, 5000));

        for (const guest of candidates) {
            const uid = guest.uid;
            console.log(`[DELETING] ${uid} (${guest.displayName})`);

            const batch = db.batch();

            // 1. Delete associated activities
            const activitiesSnap = await db.collection('activities').where('userId', '==', uid).get();
            activitiesSnap.docs.forEach(doc => batch.delete(doc.ref));

            // 2. Delete associated feed items
            const feedSnap = await db.collection('feed').where('userId', '==', uid).get();
            feedSnap.docs.forEach(doc => batch.delete(doc.ref));

            // 3. Delete reserved icons
            const iconsSnap = await db.collection('reserved_icons').where('userId', '==', uid).get();
            iconsSnap.docs.forEach(doc => batch.delete(doc.ref));

            // 4. Delete user document
            batch.delete(db.collection('users').doc(uid));

            await batch.commit();
            console.log(`   - Firestore data cleared (${activitiesSnap.size} activities, ${feedSnap.size} feed items)`);

            // 5. Delete from Auth
            if (!guest.ghost) {
                try {
                    await admin.auth().deleteUser(uid);
                    console.log(`   - Auth user deleted`);
                } catch (e: any) {
                    console.error(`   - Failed to delete Auth user ${uid}:`, e.message);
                }
            }
        }
        console.log('\n✅ Cleanup execution finished.');
    } else {
        console.log('\n🔍 DRY RUN: No changes made. Run with --execute to commit deletions.');
    }

    process.exit(0);
}

cleanupGuests().catch(err => {
    console.error('Error during cleanup:', err);
    process.exit(1);
});
