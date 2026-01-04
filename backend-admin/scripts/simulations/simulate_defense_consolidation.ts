
import admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import * as fs from 'fs';

// Initialize Firebase Admin for PRE environment
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
    const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82'; // Test user
    const targetCellId = "-1915_20408";

    console.log(`🚀 SIMULATION: Defense Consolidation (Hardened Cell XP Bonus)`);
    console.log(`👤 User: ${userId}`);
    console.log(`🏰 Target Cell: ${targetCellId}`);

    try {
        // 1. Setup: Make the cell "hardened" (20 days old)
        const cellRef = db.collection('remote_territories').doc(targetCellId);
        const cellSnap = await cellRef.get();

        if (!cellSnap.exists) {
            console.error(`❌ Cell ${targetCellId} not found. Please ensure it exists first.`);
            return;
        }

        const twentyDaysAgo = new Date();
        twentyDaysAgo.setDate(twentyDaysAgo.getDate() - 20);

        console.log(`⚙️ Setting cell age to 20 days ago...`);
        await cellRef.update({
            userId: userId, // Ensure test user owns it
            firstConqueredAt: admin.firestore.Timestamp.fromDate(twentyDaysAgo),
            defenseCount: 5,
            isExpired: false,
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 3600 * 1000))
        });

        // 2. Simulate Defense Activity
        // We'll clone the activity that originally created this cell
        const originalActivityId = cellSnap.data()?.activityId;
        if (!originalActivityId) {
            console.error(`❌ Target cell has no activityId to clone from.`);
            return;
        }

        const newActivityId = `SIM_DEF_${uuidv4().substring(0, 8)}`.toUpperCase();
        console.log(`🆕 Creating simulation activity: ${newActivityId}`);

        const originalRef = db.collection('activities').doc(originalActivityId);
        const originalSnap = await originalRef.get();
        const originalData = originalSnap.data()!;

        const now = new Date();
        const newData = {
            ...originalData,
            userId: userId,
            startDate: admin.firestore.Timestamp.fromDate(now),
            endDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 1800 * 1000)), // 30 min
            processingStatus: 'uploading',
            lastUpdatedAt: admin.firestore.Timestamp.fromDate(now),
            territoryStats: {
                newCellsCount: 0,
                defendedCellsCount: 0,
                recapturedCellsCount: 0,
                stolenCellsCount: 0,
                totalLootXP: 0,
                totalConsolidationXP: 0
            }
        };

        const newRef = db.collection('activities').doc(newActivityId);
        await newRef.set(newData);

        // Copy routes
        const routesSnap = await originalRef.collection('routes').get();
        for (const doc of routesSnap.docs) {
            await newRef.collection('routes').doc(doc.id).set(doc.data());
        }

        // Trigger Processing
        console.log(`🛰️ Triggering processing...`);
        await newRef.update({ processingStatus: 'pending' });

        console.log(`⏳ Waiting for processing to complete...`);

        // Wait and check results
        let processed = false;
        for (let i = 0; i < 10; i++) {
            await new Promise(r => setTimeout(r, 2000));
            const checkSnap = await newRef.get();
            if (checkSnap.data()?.processingStatus === 'completed') {
                processed = true;
                const stats = checkSnap.data()?.territoryStats;
                const xp = checkSnap.data()?.xpBreakdown;
                console.log(`✅ Activity Processed!`);
                console.log(`📊 Stats:`, stats);
                console.log(`✨ XP Breakdown:`, xp);

                if (stats.totalConsolidationXP > 0) {
                    console.log(`🎉 SUCCESS: Consolidation XP awarded: ${stats.totalConsolidationXP}`);
                } else {
                    console.log(`⚠️ Consolidation XP NOT awarded. Check logs.`);
                }
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

runSimulation().then(() => process.exit(0));
