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

async function checkVengeanceTargets() {
    console.log(`🔎 Auditing Vengeance Targets...`);

    try {
        const usersSnap = await db.collection('users').get();
        console.log(`👥 Checking ${usersSnap.size} users...`);

        let totalVengeance = 0;
        let missingLabelCount = 0;

        for (const userDoc of usersSnap.docs) {
            const vengeanceSnap = await userDoc.ref.collection('vengeance_targets').get();
            if (vengeanceSnap.empty) continue;

            console.log(`   👉 User ${userDoc.id} (${userDoc.data().displayName}) has ${vengeanceSnap.size} targets.`);
            totalVengeance += vengeanceSnap.size;

            vengeanceSnap.docs.forEach(doc => {
                const data = doc.data();
                if (!data.locationLabel || data.locationLabel === 'Exploración') {
                    console.log(`      ❌ Target ${doc.id} (Activity ${data.activityId}) is missing label!`);
                    missingLabelCount++;
                } else {
                    console.log(`      ✅ Target ${doc.id} has label: ${data.locationLabel}`);
                }
            });
        }

        console.log(`\n📊 Audit Finished:`);
        console.log(`📊 Total Vengeance Targets: ${totalVengeance}`);
        console.log(`📊 Missing Labels: ${missingLabelCount}`);

    } catch (error) {
        console.error('❌ Error during audit:', error);
    } finally {
        process.exit(0);
    }
}

checkVengeanceTargets();
