
import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';

if (admin.apps.length === 0) {
    admin.initializeApp({
        projectId: 'adventure-streak'
    });
}

const db = admin.firestore();
db.settings({ databaseId: 'adventure-streak-pre' });

async function runTheftSimulation() {
    const thiefId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82'; // Test user
    const victimId = 'JaSFY1oPRUfJmuIgFf1LUzl6yOp2'; // Victim
    const targetCellId = "-1915_20409"; // A DIFFERENT CELL

    console.log(`🚀 SIMULATION: Treasure Theft (Isolated Cell)`);
    console.log(`👤 Thief: ${thiefId}`);
    console.log(`👤 Victim: ${victimId}`);
    console.log(`🏰 Target Cell: ${targetCellId}`);

    try {
        // 1. Setup: Make the cell owned by the victim for 10 days
        console.log(`⚙️ Setting up cell for victim...`);
        const tenDaysAgo = new Date();
        tenDaysAgo.setDate(tenDaysAgo.getDate() - 10);

        await db.collection('remote_territories').doc(targetCellId).set({
            userId: victimId,
            firstConqueredAt: admin.firestore.Timestamp.fromDate(tenDaysAgo),
            lastConqueredAt: admin.firestore.Timestamp.fromDate(tenDaysAgo),
            activityEndAt: admin.firestore.Timestamp.fromDate(tenDaysAgo),
            defenseCount: 1,
            isExpired: false,
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 3600 * 1000)),
            centerLatitude: 40.817,
            centerLongitude: -3.830,
            boundary: [
                { latitude: 40.818, longitude: -3.831 },
                { latitude: 40.818, longitude: -3.829 },
                { latitude: 40.816, longitude: -3.829 },
                { latitude: 40.816, longitude: -3.831 }
            ]
        });

        // 2. Simulate Theft Activity
        // We'll create a new activity with a route that covers this cell
        const newActivityId = `SIM_THEFT_NEW_${uuidv4().substring(0, 8)}`.toUpperCase();
        console.log(`🆕 Creating simulation activity: ${newActivityId}`);

        const now = new Date();
        const activityData = {
            userId: thiefId,
            activityType: 'run',
            startDate: admin.firestore.Timestamp.fromDate(now),
            endDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 600 * 1000)), // 10 min
            processingStatus: 'uploading',
            lastUpdatedAt: admin.firestore.Timestamp.fromDate(now),
            distanceMeters: 500,
            durationSeconds: 600,
            locationLabel: "Simulated Park"
        };

        const newRef = db.collection('activities').doc(newActivityId);
        await newRef.set(activityData);

        // Add a route point inside the cell
        await newRef.collection('routes').add({
            order: 0,
            points: [
                { latitude: 40.817, longitude: -3.830 }
            ]
        });

        // Trigger Processing
        console.log(`🛰️ Triggering processing...`);
        await newRef.update({ processingStatus: 'pending' });

        console.log(`⏳ Waiting for processing to complete (up to 60s)...`);

        let processed = false;
        for (let i = 0; i < 30; i++) {
            await new Promise(r => setTimeout(r, 2000));
            const checkSnap = await newRef.get();
            const data = checkSnap.data();
            console.log(`   [${i * 2}s] Status: ${data?.processingStatus}`);
            if (data?.processingStatus === 'completed') {
                processed = true;
                const stats = data?.territoryStats;
                console.log(`✅ Activity Processed!`);
                console.log(`📊 Stats:`, stats);
                if (stats.totalLootXP > 0) {
                    console.log(`🎉 SUCCESS: Loot XP awarded: ${stats.totalLootXP}`);
                } else {
                    console.log(`⚠️ Loot XP NOT awarded. Stolen Cells: ${stats.stolenCellsCount}`);
                }
                break;
            } else if (data?.processingStatus === 'error') {
                console.log(`❌ Error during processing reported in activity.`);
                break;
            }
        }

        if (!processed) {
            console.log(`⌛ Timeout waiting for processing. Check Firebase Logs.`);
        }

    } catch (e) {
        console.error(`❌ Simulation failed:`, e);
    }
}

runTheftSimulation();
