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

// 1. Define the Target User (Current Simulator User from Logs)
const USER_ID = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82'; // Our test user

async function setupAlertScenarios() {
    console.log(`🚀 Setting up Alert Card Scenarios for User: ${USER_ID}`);

    try {
        const now = admin.firestore.Timestamp.now();
        const nowMillis = Date.now();

        // Dummy boundary (small square)
        const boundary = [
            { latitude: 40.45 + 0.001, longitude: -3.7 - 0.001 },
            { latitude: 40.45 + 0.001, longitude: -3.7 + 0.001 },
            { latitude: 40.45 - 0.001, longitude: -3.7 + 0.001 },
            { latitude: 40.45 - 0.001, longitude: -3.7 - 0.001 }
        ];

        // 1. HOT SPOT (-1883_20406)
        // Expires in 7 days (healthy), but isHotSpot=true
        const hotSpotId = '-1883_20406';
        console.log(`🔥 Setting up Hot Spot: ${hotSpotId}`);
        await db.collection('remote_territories').doc(hotSpotId).set({
            userId: USER_ID,
            activityId: 'SCENARIO_HOTSPOT',
            centerLatitude: 40.45,
            centerLongitude: -3.7,
            boundary: boundary,
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(nowMillis + 7 * 86400000)),
            activityEndAt: now,
            lastConqueredAt: now, // Explicit field
            timestamp: now,
            uploadedAt: now,
            isHotSpot: true,
            locationLabel: "Zona Caliente Test"
        }, { merge: true });

        // 2. EXPIRING SOON (-1853_20239)
        // Expires in 2 hours
        const expiringId = '-1853_20239';
        console.log(`⚠️ Setting up Expiring Soon: ${expiringId}`);
        await db.collection('remote_territories').doc(expiringId).set({
            userId: USER_ID,
            activityId: 'SCENARIO_EXPIRING',
            centerLatitude: 40.46,
            centerLongitude: -3.68,
            boundary: boundary,
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(nowMillis + 2 * 3600000)), // +2 hours
            activityEndAt: now,
            lastConqueredAt: now,
            timestamp: now,
            uploadedAt: now,
            isHotSpot: false,
            locationLabel: "Zona Por Expirar"
        }, { merge: true });

        // 3. RECENTLY EXPIRED (-1838_20193)
        // Expired 2 hours ago
        // NOTE: For 'Recently Expired' to show, it usually needs to be in the local store.
        // If the query excludes it, it won't show.
        // But TerritoryRepository query is ONLY by userId. So it SHOULD fetch it.
        const expiredId = '-1838_20193';
        console.log(`☠️ Setting up Expired: ${expiredId}`);
        await db.collection('remote_territories').doc(expiredId).set({
            userId: USER_ID,
            activityId: 'SCENARIO_EXPIRED',
            centerLatitude: 40.47,
            centerLongitude: -3.65,
            boundary: boundary,
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(nowMillis - 2 * 3600000)), // -2 hours
            activityEndAt: admin.firestore.Timestamp.fromDate(new Date(nowMillis - 7 * 86400000)),
            lastConqueredAt: admin.firestore.Timestamp.fromDate(new Date(nowMillis - 7 * 86400000)),
            timestamp: now,
            uploadedAt: now,
            isHotSpot: false,
            locationLabel: "Zona Vencida"
        }, { merge: true });

        console.log('\n✅ Alert Scenarios Setup Complete!');
        console.log('🔄 Pull to refresh in the app to see the new cards.');

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        process.exit(0);
    }
}

setupAlertScenarios();
