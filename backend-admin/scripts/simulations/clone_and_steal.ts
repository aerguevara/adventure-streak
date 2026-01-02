
import admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import * as fs from 'fs';

// Initialize Firebase Admin for PRE environment
const serviceAccount = JSON.parse(fs.readFileSync('/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json', 'utf8'));

if (!admin.apps || admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
    });
}

const db = admin.firestore();
db.settings({ databaseId: 'adventure-streak-pre' });

async function simulateTheftByDuplicate() {
    const originalActivityId = 'EF8B71EE-253E-45C9-A28E-663CF8FD887A';
    const attackerUserId = 'DQN1tyypsEZouksWzmFeSIYip7b2';
    const newActivityId = uuidv4().toUpperCase();

    console.log(`🚀 Simulating Theft: Duplicating ${originalActivityId} for Attacker ${attackerUserId}`);
    console.log(`🆕 New Activity ID: ${newActivityId}`);

    try {
        // 1. Fetch Original Activity Metadata
        const originalRef = db.collection('activities').doc(originalActivityId);
        const originalSnap = await originalRef.get();

        if (!originalSnap.exists) {
            console.error(`❌ Original activity ${originalActivityId} not found!`);
            return;
        }

        const originalData = originalSnap.data()!;

        // 2. Prepare New Metadata
        const now = new Date();
        const startTime = now;
        const endTime = new Date(now.getTime() + (originalData.durationSeconds * 1000));

        const newData = {
            ...originalData,
            userId: attackerUserId,
            startDate: admin.firestore.Timestamp.fromDate(startTime),
            endDate: admin.firestore.Timestamp.fromDate(endTime),
            processingStatus: 'pending', // Important: This triggers the Cloud Function
            lastUpdatedAt: admin.firestore.Timestamp.fromDate(now),
            // Reset stats and missions to let the function calculate them
            territoryStats: {
                newCellsCount: 0,
                defendedCellsCount: 0,
                recapturedCellsCount: 0,
                stolenCellsCount: 0
            },
            xpBreakdown: {
                total: 0,
                xpBase: 0,
                xpTerritory: 0,
                xpStreak: 0,
                xpBadges: 0,
                xpWeeklyRecord: 0
            },
            missions: [],
            conqueredVictims: []
        };

        // 3. Save New Metadata (Initially 'uploading')
        const newRef = db.collection('activities').doc(newActivityId);
        await newRef.set({
            ...newData,
            processingStatus: 'uploading'
        });
        console.log(`✅ Metadata created for ${newActivityId} (Status: uploading)`);

        // 4. Fetch and Duplicate Routes
        const routesSnap = await originalRef.collection('routes').get();
        console.log(`🛣️ Copying ${routesSnap.size} route chunks...`);
        for (const doc of routesSnap.docs) {
            await newRef.collection('routes').doc(doc.id).set(doc.data());
        }
        console.log(`✅ Routes duplicated`);

        // 5. Fetch and Duplicate Territories (Optional but good for history)
        const territoriesSnap = await originalRef.collection('territories').get();
        console.log(`🌍 Copying ${territoriesSnap.size} territory chunks...`);
        for (const doc of territoriesSnap.docs) {
            await newRef.collection('territories').doc(doc.id).set(doc.data());
        }
        console.log(`✅ Territories duplicated`);

        // 6. TRIGGER: Update status to 'pending'
        await newRef.update({
            processingStatus: 'pending',
            lastUpdatedAt: admin.firestore.Timestamp.fromDate(new Date())
        });
        console.log(`🚀 STATUS UPDATED TO 'PENDING' - Triggering Cloud Function...`);

        console.log(`\n🏁 SIMULATION TRIGGERED!`);
        console.log(`The Firebase Function 'processActivityCompletePRE' should now process activity ${newActivityId}.`);
        console.log(`Monitor Firestore for updates on:`);
        console.log(`- activities/${newActivityId} (Wait for processingStatus: 'completed')`);
        console.log(`- remote_territories/-1817_20224 (Wait for userId: ${attackerUserId})`);

    } catch (error) {
        console.error('❌ Error during simulation:', error);
    }
}

simulateTheftByDuplicate();
