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

const VICTIM_ID = 'DQN1tyypsEZouksWzmFeSIYip7b2';
const THIEF_ID = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
const THIEF_NAME = 'Ladrón de IFEMA';

async function simulateFuenfriaTheft() {
    console.log(`🥷 Simulating theft of Fuenfría territories from ${VICTIM_ID} to ${THIEF_ID}`);

    try {
        const now = admin.firestore.Timestamp.now();

        // 1. Find all territories owned by the victim in the Fuenfría area
        // Fuenfría area is roughly Lat > 40.75 and Lng around -4.06
        const snapshot = await db.collection('remote_territories')
            .where('userId', '==', VICTIM_ID)
            .get();

        const fuenfriaTerritories = snapshot.docs.filter(doc => {
            const data = doc.data();
            // Using a broad bounding box for Fuenfría area based on user's hint and previous research
            return data.centerLatitude > 40.75 && data.centerLongitude < -3.9;
        });

        if (fuenfriaTerritories.length === 0) {
            console.log('⚠️ No territories found for victim in the Fuenfría area.');
            // Let's add the specific one the user mentioned just in case it needs to be created or if I missed it
            // Based on user hint: -2033_20380
            const specificId = '-2033_20380';
            console.log(`Force-creating/updating specific territory ${specificId} to ensure simulation works.`);

            // We'll create it with plausible coordinates for Fuenfría
            const lat = 40.762;
            const lng = -4.058;

            const territoryData = {
                userId: THIEF_ID,
                centerLatitude: lat,
                centerLongitude: lng,
                boundary: [
                    { latitude: lat + 0.001, longitude: lng - 0.001 },
                    { latitude: lat + 0.001, longitude: lng + 0.001 },
                    { latitude: lat - 0.001, longitude: lng + 0.001 },
                    { latitude: lat - 0.001, longitude: lng - 0.001 }
                ],
                lastInteraction: 'steal',
                activityEndAt: now,
                timestamp: now,
                uploadedAt: now,
                expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 86400000)), // 7 days from now
                isHotSpot: false,
                activityId: 'FUENFRIA_THEFT_SIMULATION'
            };

            await db.collection('remote_territories').doc(specificId).set(territoryData);

            await db.collection('users').doc(VICTIM_ID).collection('vengeance_targets').doc(specificId).set({
                cellId: specificId,
                centerLatitude: lat,
                centerLongitude: lng,
                thiefId: THIEF_ID,
                thiefName: THIEF_NAME,
                stolenAt: now,
                xpReward: 30
            });

            console.log(`✅ Specific territory ${specificId} simulated.`);
        } else {
            console.log(`Found ${fuenfriaTerritories.length} territories to steal.`);

            const batch = db.batch();

            for (const doc of fuenfriaTerritories) {
                const data = doc.data();
                const cellId = doc.id;

                // Update ownership
                batch.update(doc.ref, {
                    userId: THIEF_ID,
                    lastInteraction: 'steal',
                    activityEndAt: now,
                    timestamp: now,
                    uploadedAt: now
                });

                // Add to vengeance targets
                const vengeanceRef = db.collection('users').doc(VICTIM_ID).collection('vengeance_targets').doc(cellId);
                batch.set(vengeanceRef, {
                    cellId: cellId,
                    centerLatitude: data.centerLatitude,
                    centerLongitude: data.centerLongitude,
                    thiefId: THIEF_ID,
                    thiefName: THIEF_NAME,
                    stolenAt: now,
                    xpReward: 30
                });
            }

            await batch.commit();
            console.log(`✅ ${fuenfriaTerritories.length} territories transferred and vengeance targets created.`);
        }

        console.log('\n🏁 Simulation complete. Restart the app to see the changes.');

    } catch (error) {
        console.error('❌ Error during simulation:', error);
    } finally {
        process.exit(0);
    }
}

simulateFuenfriaTheft();
