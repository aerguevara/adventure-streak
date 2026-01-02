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

async function setupScenarios() {
    console.log(`🚀 Final Clean Sweep and Setup for User: ${USER_ID}`);

    try {
        const now = admin.firestore.Timestamp.now();
        const tomorrow = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000));
        const nextWeek = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 86400000));

        // --- 1. CLEANUP OLD TEST DATA ---
        console.log("Cleaning up old test documents...");
        await db.collection('users').doc(USER_ID).collection('vengeance_targets').doc('test_vengeance_cell').delete();
        await db.collection('remote_territories').doc('test_vengeance_cell').delete();

        // --- 2. SETUP REAL VENGEANCE TARGET (-1810_20235) ---
        const vCellId = '-1810_20235';
        console.log(`Setting up Vengeance Target: ${vCellId}`);

        // Update territory details to be "perfect"
        await db.collection('remote_territories').doc(vCellId).set({
            userId: THIEF_ID,
            centerLatitude: 40.471,
            centerLongitude: -3.619,
            boundary: [
                { latitude: 40.472, longitude: -3.62 },
                { latitude: 40.472, longitude: -3.618 },
                { latitude: 40.47, longitude: -3.618 },
                { latitude: 40.47, longitude: -3.62 }
            ],
            expiresAt: nextWeek,
            activityId: 'ROBBERY_TEST_ACTIVITY',
            activityEndAt: now,
            timestamp: now,
            uploadedAt: now,
            isHotSpot: false,
            lastInteraction: 'steal'
        });

        // Create the target reference
        await db.collection('users').doc(USER_ID).collection('vengeance_targets').doc(vCellId).set({
            cellId: vCellId,
            centerLatitude: 40.471,
            centerLongitude: -3.619,
            thiefId: THIEF_ID,
            thiefName: "Ladrón de IFEMA",
            stolenAt: now,
            xpReward: 25
        });

        // --- 3. SETUP URGENT OWNED TERRITORY (-1809_20235) ---
        const uCellId = '-1809_20235';
        console.log(`Setting up Urgent Territory: ${uCellId}`);
        await db.collection('remote_territories').doc(uCellId).update({
            expiresAt: tomorrow,
            activityEndAt: now,
            timestamp: now
        });

        console.log('\n✅ Scenarios setup complete!');
        console.log('🏁 Restart the app. Look for "Ladrón de IFEMA" in the Radar.');

    } catch (error) {
        console.error('❌ Error in setup:', error);
    } finally {
        process.exit(0);
    }
}

setupScenarios();
