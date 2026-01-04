
import admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import * as fs from 'fs';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

if (!admin.apps || admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();
db.settings({ databaseId: 'adventure-streak-pre' });

async function runSimulation() {
    const thiefId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82'; // Test user as thief
    const victimId = 'JaSFY1oPRUfJmuIgFf1LUzl6yOp2'; // Rival
    const targetCellId = "-1915_20408";

    console.log(`🚀 SIMULATION: Treasure Theft (Accumulated Loot XP)`);
    console.log(`👤 Thief: ${thiefId}`);
    console.log(`👤 Victim: ${victimId}`);
    console.log(`🏰 Target Cell: ${targetCellId}`);

    try {
        // 1. Setup: Make the cell old and owned by victim
        const cellRef = db.collection('remote_territories').doc(targetCellId);
        const cellSnap = await cellRef.get();

        const tenDaysAgo = new Date();
        tenDaysAgo.setDate(tenDaysAgo.getDate() - 10);

        console.log(`⚙️ Setting cell age to 10 days ago (Accumulated Loot = 20 XP)...`);
        await cellRef.update({
            userId: victimId,
            firstConqueredAt: admin.firestore.Timestamp.fromDate(tenDaysAgo),
            defenseCount: 2,
            isExpired: false,
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 3600 * 1000))
        });

        // 2. Simulate Theft Activity
        const originalActivityId = cellSnap.data()?.activityId;
        const newActivityId = `SIM_THEFT_${uuidv4().substring(0, 8)}`.toUpperCase();
        console.log(`🆕 Creating theft activity: ${newActivityId}`);

        const now = new Date();
        const newRef = db.collection('activities').doc(newActivityId);
        await newRef.set({
            userId: thiefId,
            activityType: 'hike',
            startDate: admin.firestore.Timestamp.fromDate(now),
            endDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 1800 * 1000)),
            processingStatus: 'uploading',
            lastUpdatedAt: admin.firestore.Timestamp.fromDate(now),
            distanceMeters: 1000,
            durationSeconds: 1800,
            locationLabel: "Madrigal de la Sierra"
        });

        // Add route point to match the cell
        await newRef.collection('routes').add({
            order: 0,
            points: [
                { latitude: 40.817, longitude: -3.829, timestamp: admin.firestore.Timestamp.fromDate(now) }
            ]
        });

        console.log(`🛰️ Triggering processing...`);
        await newRef.update({ processingStatus: 'pending' });

        // Wait and check results
        for (let i = 0; i < 10; i++) {
            await new Promise(r => setTimeout(r, 2000));
            const checkSnap = await newRef.get();
            if (checkSnap.data()?.processingStatus === 'completed') {
                const stats = checkSnap.data()?.territoryStats;
                console.log(`✅ Activity Processed!`);
                console.log(`📊 Stats:`, stats);

                if (stats.totalLootXP > 0) {
                    console.log(`🎉 SUCCESS: Loot XP stolen: ${stats.totalLootXP}`);
                } else {
                    console.log(`⚠️ Loot XP NOT awarded. Check if theft was detected.`);
                }
                break;
            }
        }

    } catch (e) {
        console.error(`❌ Simulation failed:`, e);
    }
}

runSimulation().then(() => process.exit(0));
