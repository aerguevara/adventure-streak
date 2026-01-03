import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
});

const args = process.argv.slice(2);
const envArg = args[0]?.toUpperCase();

if (!envArg || !["PRE", "PRO"].includes(envArg)) {
    console.error("❌ Usage: npx ts-node scripts/maintenance/cleanup_old_vengeance.ts [PRE|PRO]");
    process.exit(1);
}

const databaseId = envArg === "PRE" ? "adventure-streak-pre" : "(default)";
const db = getFirestore(app, databaseId);

async function cleanupOldVengeance() {
    console.log(`🧹 Starting cleanup of old vengeance targets in PRE...`);
    const now = new Date();
    const cutoff = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000)); // 7 days ago (1 week)
    console.log(`📅 Cutoff date: ${cutoff.toISOString()}`);

    try {
        const usersSnap = await db.collection('users').get();
        let totalDeleted = 0;

        for (const userDoc of usersSnap.docs) {
            const vengeanceSnap = await userDoc.ref.collection('vengeance_targets').get();
            if (vengeanceSnap.empty) continue;

            const batch = db.batch();
            let userDeletedCount = 0;

            vengeanceSnap.docs.forEach(doc => {
                const data = doc.data();
                const stolenAt = data.stolenAt ? data.stolenAt.toDate() : new Date(0);

                if (stolenAt < cutoff) {
                    batch.delete(doc.ref);
                    userDeletedCount++;
                }
            });

            if (userDeletedCount > 0) {
                await batch.commit();
                console.log(`   ✅ Deleted ${userDeletedCount} old targets for user ${userDoc.id} (${userDoc.data().displayName})`);
                totalDeleted += userDeletedCount;
            }
        }

        console.log(`\n✨ Cleanup Finished! Total deleted: ${totalDeleted}`);

    } catch (error) {
        console.error('❌ Error during cleanup:', error);
    } finally {
        process.exit(0);
    }
}

cleanupOldVengeance();
