const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
});

const db = getFirestore(app, "adventure-streak-pre");

const USER_ID = 'DQN1tyypsEZouksWzmFeSIYip7b2';
const THIEF_ID = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function performStealTest() {
    console.log(`🥷 Performing STEAL TEST on territory -1809_20235`);

    try {
        const now = admin.firestore.Timestamp.now();
        const cellId = '-1809_20235';

        // 1. UPDATE OWNERSHIP (Steal)
        console.log(`Updating territory ${cellId} owner to ${THIEF_ID}`);
        await db.collection('remote_territories').doc(cellId).update({
            userId: THIEF_ID,
            lastInteraction: 'steal',
            activityEndAt: now,
            timestamp: now,
            uploadedAt: now
        });

        // 2. ADD TO VENGEANCE TARGETS
        console.log(`Adding ${cellId} to vengeance_targets for ${USER_ID}`);
        await db.collection('users').doc(USER_ID).collection('vengeance_targets').doc(cellId).set({
            cellId: cellId,
            centerLatitude: 40.471,
            centerLongitude: -3.617,
            thiefId: THIEF_ID,
            thiefName: "El Ladrón de IFEMA",
            stolenAt: now,
            xpReward: 25
        });

        console.log('\n✅ Steal test configured!');
        console.log('🏁 Restart the app. The territory "-1809_20235" should move from "Urgente" to "OBJETIVO".');

    } catch (error) {
        console.error('❌ Error in steal test:', error);
    } finally {
        process.exit(0);
    }
}

performStealTest();
