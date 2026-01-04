
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
    const thiefId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
    const victimId = 'JaSFY1oPRUfJmuIgFf1LUzl6yOp2';
    const targetCellId = "-1915_20408";

    console.log(`🚀 SIMULATION: Streak Breaker (Bonus for Stealing from Active User)`);
    console.log(`👤 Thief: ${thiefId}`);
    console.log(`👤 Victim: ${victimId}`);

    try {
        // 1. Setup: Make victim have a streak
        console.log(`⚙️ Setting victim streak to 5 weeks...`);
        await db.collection('users').doc(victimId).update({
            currentStreakWeeks: 5
        });

        // Ensure victim owns the cell
        await db.collection('remote_territories').doc(targetCellId).update({
            userId: victimId,
            isExpired: false
        });

        // 2. Simulate Theft Activity
        // Find an activity to clone
        const cellSnap = await db.collection('remote_territories').doc(targetCellId).get();
        const originalActivityId = cellSnap.data()?.activityId;
        const newActivityId = `SIM_STREAK_${uuidv4().substring(0, 8)}`.toUpperCase();

        const originalSnap = await db.collection('activities').doc(originalActivityId).get();
        const originalData = originalSnap.data()!;

        const now = new Date();
        const newData = {
            ...originalData,
            userId: thiefId,
            processingStatus: 'pending'
        };

        const newRef = db.collection('activities').doc(newActivityId);
        await newRef.set(newData);

        // Copy routes
        const routesSnap = await db.collection('activities').doc(originalActivityId).collection('routes').get();
        for (const doc of routesSnap.docs) {
            await newRef.collection('routes').doc(doc.id).set(doc.data());
        }

        console.log(`🛰️ Triggering processing...`);
        await newRef.update({ processingStatus: 'pending' });

        // Wait and check results
        for (let i = 0; i < 10; i++) {
            await new Promise(r => setTimeout(r, 2000));
            const checkSnap = await newRef.get();
            if (checkSnap.data()?.processingStatus === 'completed') {
                const stats = checkSnap.data()?.territoryStats;
                const badges = checkSnap.data()?.unlockedBadges || [];
                console.log(`✅ Activity Processed!`);
                console.log(`📊 Stats:`, stats);
                console.log(`🏅 Badges:`, badges);

                if (stats.totalStreakInterruptionXP > 0) {
                    console.log(`🎉 SUCCESS: Streak Interruption XP awarded!`);
                }
                if (badges.includes('streak_breaker')) {
                    console.log(`🎉 SUCCESS: Badge 'streak_breaker' unlocked!`);
                }
                break;
            }
        }

    } catch (e) {
        console.error(`❌ Simulation failed:`, e);
    }
}

runSimulation().then(() => process.exit(0));
