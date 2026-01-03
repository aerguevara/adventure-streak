
import admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import * as fs from 'fs';

// Initialize Firebase Admin for PRE environment
// NOTE: Adjust path to serviceAccount if needed
const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
        });
    }
} else {
    // Fallback or rely on default env if running in cloud context (but this is local script)
    if (!admin.apps.length) admin.initializeApp();
}

const db = admin.firestore();
db.settings({ databaseId: 'adventure-streak-pre' });

const TARGET_USER_ID = 'DQN1tyypsEZouksWzmFeSIYip7b2'; // Main Test User

// Helpers
function getTimestamp(date: Date) {
    return admin.firestore.Timestamp.fromDate(date);
}

// ------------------------------------------------------------------
// SCENARIO 1: Early Bird (Madrugador)
// ------------------------------------------------------------------
async function triggerEarlyBird(userId: string) {
    console.log(`🌅 Triggering 'Early Bird' for ${userId}...`);
    const activityId = uuidv4().toUpperCase();
    const now = new Date();

    // Set start time to 06:15 AM today
    const startDate = new Date(now);
    startDate.setHours(6, 15, 0, 0);
    const endDate = new Date(startDate.getTime() + 30 * 60000); // 30 mins

    const data = {
        userId: userId,
        activityType: 'run',
        startDate: getTimestamp(startDate),
        endDate: getTimestamp(endDate),
        durationSeconds: 1800,
        distanceMeters: 5500, // > 5km
        processingStatus: 'pending',
        locationLabel: 'Simulation City',
        mockedForBadge: 'early_bird'
    };

    await db.collection('activities').doc(activityId).set(data);
    console.log(`✅ Created Activity ${activityId} (Run, 5.5km, 6:15 AM)`);
}

// ------------------------------------------------------------------
// SCENARIO 2: Iron Stamina (Resistencia de Hierro)
// ------------------------------------------------------------------
async function triggerIronStamina(userId: string) {
    console.log(`🏋️ Triggering 'Iron Stamina' for ${userId}...`);
    const activityId = uuidv4().toUpperCase();
    const now = new Date();

    // 95 minutes
    const durationSec = 95 * 60;
    const startDate = new Date(now.getTime() - durationSec * 1000);

    const data = {
        userId: userId,
        activityType: 'indoor',
        startDate: getTimestamp(startDate),
        endDate: getTimestamp(now),
        durationSeconds: durationSec,
        distanceMeters: 0,
        processingStatus: 'pending',
        locationLabel: 'Gym Simulation',
        mockedForBadge: 'iron_stamina'
    };

    await db.collection('activities').doc(activityId).set(data);
    console.log(`✅ Created Activity ${activityId} (Indoor, 95 mins)`);
}

// ------------------------------------------------------------------
// SCENARIO 3: Elite Sprinter
// ------------------------------------------------------------------
async function triggerEliteSprinter(userId: string) {
    console.log(`🐆 Triggering 'Elite Sprinter' for ${userId}...`);
    const activityId = uuidv4().toUpperCase();
    const now = new Date();

    // 5km in 20 mins (4:00 min/km) -> Threshold is 4:30
    const distance = 5000;
    const duration = 20 * 60; // 1200s

    const startDate = new Date(now.getTime() - duration * 1000);

    const data = {
        userId: userId,
        activityType: 'run',
        startDate: getTimestamp(startDate),
        endDate: getTimestamp(now),
        durationSeconds: duration,
        distanceMeters: distance,
        processingStatus: 'pending',
        mockedForBadge: 'elite_sprinter'
    };

    await db.collection('activities').doc(activityId).set(data);
    console.log(`✅ Created Activity ${activityId} (Run, 5km, 4:00 min/km)`);
}

// ------------------------------------------------------------------
// SCENARIO 4: White Glove (Ladrón de Guante Blanco)
// ------------------------------------------------------------------
async function triggerWhiteGlove(userId: string) {
    console.log(`🧤 Triggering 'White Glove' for ${userId}...`);

    // 1. Create a setup with an OLD territory
    // We need a route that passes through a specific cell.
    // Let's manually create a cell check in `territories.ts` logic? 
    // No, we need to create the `remote_territory` doc FIRST.

    const cellId = "-1000_1000"; // Fake cell
    const victimId = "VICTIM_OLD_USER";

    const oldDate = new Date();
    oldDate.setDate(oldDate.getDate() - 40); // 40 days ago

    // Setup the victim cell
    await db.collection('remote_territories').doc(cellId).set({
        id: cellId,
        userId: victimId,
        lastConqueredAt: getTimestamp(oldDate), // 40 days old
        expiresAt: getTimestamp(new Date(oldDate.getTime() + 60 * 24 * 3600 * 1000)), // expires in future (long expiry config?) or assume it's still valid if config says so. 
        // Wait, default expiry is capture 7 days? Only 30+ days if re-defended?
        // Or "Epic" means it was originally conquered > 30 days ago and HELD?
        // Prompt says: "Robar una celda épica (conquistada originalmente hace más de 30 días)."
        // Usually implies it hasn't been stolen since.
        centerLatitude: 0, // Mock
        centerLongitude: 0,
        activityId: "old_activity"
    });

    console.log(`   - Setup Cell ${cellId} owned by ${victimId} since 40 days ago`);

    // 2. Create Activity passing through this cell
    // We need to provide a route that hits this cell.
    // Cell "-1000_1000" -> x=-1000, y=1000. 
    // Lat/Lon? 
    // x = floor(lon / CELL_SIZE). CELL_SIZE = 0.002.
    // lon = -1000 * 0.002 = -2.0
    // lat = 1000 * 0.002 = 2.0

    const activityId = uuidv4().toUpperCase();
    const now = new Date();

    const data = {
        userId: userId,
        activityType: 'walk',
        startDate: getTimestamp(now),
        endDate: getTimestamp(new Date(now.getTime() + 600)),
        distanceMeters: 100,
        processingStatus: 'pending',
        locationLabel: 'Epic Heist'
    };

    await db.collection('activities').doc(activityId).set(data);

    // Add Route Chunk hitting the cell
    // Center is (2.001, -1.999) approx?
    // Let's just put points exactly at 2.0, -2.0
    await db.collection('activities').doc(activityId).collection('routes').doc('chunk_0').set({
        order: 0,
        points: [
            { latitude: 2.001, longitude: -1.999, timestamp: getTimestamp(now) }
        ]
    });

    console.log(`✅ Created Activity ${activityId} stealing cell ${cellId}`);
}

// ------------------------------------------------------------------
// SCENARIO 5: Steel Influencer (Influencer de Acero)
// ------------------------------------------------------------------
async function triggerSteelInfluencer(userId: string) {
    console.log(`📸 Triggering 'Steel Influencer' for ${userId}...`);

    // 1. Find a recent activity or create one
    // Let's create a dummy one
    const activityId = `INFLUENCER_TEST_${uuidv4().substring(0, 8)}`;
    await db.collection('activities').doc(activityId).set({
        userId: userId,
        activityType: 'run',
        startDate: getTimestamp(new Date()),
        locationLabel: 'Viral Run'
    });

    // 2. Add 50 reactions
    const batch = db.batch();
    for (let i = 0; i < 50; i++) {
        const reactionId = uuidv4();
        const ref = db.collection('activity_reactions').doc(reactionId);
        batch.set(ref, {
            activityId: activityId,
            reactionType: '🔥',
            reactedUserId: `FAN_${i}`,
            timestamp: getTimestamp(new Date())
        });
    }
    await batch.commit();
    console.log(`✅ Added 50 reactions to ${activityId}`);

    // Note: The badge trigger is in `reactions.ts`, listening to `onCreate`.
    // Batch commit might trigger 50 function executions or we might need to rely on the *last* one.
    // However, the `checkSocialBadges` logic queries the COUNT.
    // So the 50th write will see count=50 and award it.
}

// MAIN RUNNER
async function main() {
    const args = process.argv.slice(2);
    const scenario = args[0];
    const userId = args[1] || TARGET_USER_ID;

    if (!scenario) {
        console.log("Please specify scenario: early_bird, iron_stamina, elite_sprinter, white_glove, steel_influencer");
        return;
    }

    switch (scenario) {
        case 'early_bird': await triggerEarlyBird(userId); break;
        case 'iron_stamina': await triggerIronStamina(userId); break;
        case 'elite_sprinter': await triggerEliteSprinter(userId); break;
        case 'white_glove': await triggerWhiteGlove(userId); break;
        case 'steel_influencer': await triggerSteelInfluencer(userId); break;
        default: console.log("Unknown scenario");
    }
}

main().then(() => console.log("Done")).catch(console.error);
