import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
});

const db = getFirestore(app, "adventure-streak-pre");

async function auditVengeanceConsistency() {
    console.log(`🔍 Auditing Vengeance Consistency in PRE...`);

    try {
        const usersSnap = await db.collection('users').get();
        let totalStaleDeleted = 0;

        for (const userDoc of usersSnap.docs) {
            const userId = userDoc.id;
            const vengeanceSnap = await userDoc.ref.collection('vengeance_targets').get();

            if (vengeanceSnap.empty) continue;

            console.log(`👤 Checking user ${userId} (${userDoc.data().displayName}): ${vengeanceSnap.size} targets`);
            const batch = db.batch();
            let userStaleCount = 0;

            for (const vDoc of vengeanceSnap.docs) {
                const cellId = vDoc.id;

                // Check if user already owns this cell
                const territoryDoc = await db.collection('remote_territories').doc(cellId).get();

                if (territoryDoc.exists) {
                    const territoryData = territoryDoc.data();
                    if (territoryData?.userId === userId) {
                        console.log(`   🚨 Ghost Target found! Cell ${cellId} is already owned by user.`);
                        batch.delete(vDoc.ref);
                        userStaleCount++;
                    }
                }
            }

            if (userStaleCount > 0) {
                await batch.commit();
                console.log(`   ✅ Cleaned ${userStaleCount} ghost targets for ${userId}`);
                totalStaleDeleted += userStaleCount;
            }
        }

        console.log(`\n✨ Consistency Audit Finished! Total ghost targets deleted: ${totalStaleDeleted}`);

    } catch (error) {
        console.error('❌ Error during consistency audit:', error);
    } finally {
        process.exit(0);
    }
}

auditVengeanceConsistency();
