
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
    const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
    // We need 5 adjacent cells. Let's pick some known coordinates or arbitrary ones that exist.
    // In PRE, some known clusters exist around Madrid.
    const clusterCells = [
        "-1915_20408",
        "-1915_20409",
        "-1916_20408",
        "-1916_20409",
        "-1914_20408"
    ];

    console.log(`🚀 SIMULATION: Lord of the Fief (Legendary Mission)`);
    console.log(`👤 User: ${userId}`);

    try {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 35);

        console.log(`⚙️ Hardening 5 cells to 30+ days...`);
        for (const cellId of clusterCells) {
            await db.collection('remote_territories').doc(cellId).set({
                id: cellId,
                userId: userId,
                firstConqueredAt: admin.firestore.Timestamp.fromDate(thirtyDaysAgo),
                defenseCount: 10,
                isExpired: false,
                expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 3600 * 1000)),
                centerLatitude: 40.4168, // Placeholder
                centerLongitude: -3.7038, // Placeholder
                boundary: [] // Simplified for setup
            }, { merge: true });
        }

        // Simulate a defense of all of them (approximate with one large activity)
        // We'll use the same cloning logic but we need an activity that touched these.
        // For simplicity, we'll just mock the activity stats or use a representative one.
        const newActivityId = `SIM_LORD_${uuidv4().substring(0, 8)}`.toUpperCase();
        const now = new Date();

        const newRef = db.collection('activities').doc(newActivityId);
        await newRef.set({
            userId: userId,
            activityType: 'hike',
            startDate: admin.firestore.Timestamp.fromDate(now),
            endDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 3600 * 1000)),
            processingStatus: 'uploading',
            lastUpdatedAt: admin.firestore.Timestamp.fromDate(now),
            distanceMeters: 5000,
            durationSeconds: 3600,
            locationLabel: "Fiefdom Territory"
        });

        // Add 5 points, one for each cell
        const points = [
            { latitude: 40.816, longitude: -3.830 },
            { latitude: 40.818, longitude: -3.830 },
            { latitude: 40.816, longitude: -3.832 },
            { latitude: 40.818, longitude: -3.832 },
            { latitude: 40.814, longitude: -3.830 }
        ];

        await newRef.collection('routes').add({
            order: 0,
            points: points.map((p, i) => ({ ...p, timestamp: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + i * 100 * 1000)) }))
        });

        console.log(`🛰️ Triggering processing...`);
        await newRef.update({ processingStatus: 'pending' });

        // Wait and check results
        for (let i = 0; i < 10; i++) {
            await new Promise(r => setTimeout(r, 2000));
            const checkSnap = await newRef.get();
            if (checkSnap.data()?.processingStatus === 'completed') {
                const missions = checkSnap.data()?.missions || [];
                console.log(`✅ Activity Processed!`);
                console.log(`📜 Missions:`, missions);

                const found = missions.find((m: any) => m.name === "Señor del Feudo");
                if (found) {
                    console.log(`🎉 SUCCESS: 'Señor del Feudo' Mission unlocked!`);
                } else {
                    console.log(`⚠️ Mission not found. Check adjacency or age conditions.`);
                }
                break;
            }
        }

    } catch (e) {
        console.error(`❌ Simulation failed:`, e);
    }
}

runSimulation().then(() => process.exit(0));
