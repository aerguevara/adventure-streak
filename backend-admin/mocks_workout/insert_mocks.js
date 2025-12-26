const admin = require('firebase-admin');
const path = require('path');

// Path to your service account
const serviceAccountPath = path.resolve(__dirname, '../secrets/serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

const { getFirestore } = require('firebase-admin/firestore');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// Configure the specific database instance
const db = getFirestore(admin.app(), 'adventure-streak-pre');

const MOCK_COLLECTION = 'debug_mock_workouts';

// Helper to generate UUIDs
const { randomUUID } = require('crypto');

const mocks = [
    {
        id: randomUUID(),
        type: 8, // HKWorkoutActivityType.running
        startDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000)), // 1 hour ago
        endDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1800000)), // 30 mins ago
        distanceMeters: 5200.5,
        durationSeconds: 1800,
        sourceName: "Mock Apple Watch",
        metadata: {
            "HKMetadataKeyIndoorWorkout": false
        },
        route: [
            { latitude: 40.384618, longitude: -3.672212, timestamp: admin.firestore.Timestamp.now(), altitude: 600 },
            { latitude: 40.384616, longitude: -3.672209, timestamp: admin.firestore.Timestamp.now(), altitude: 601 },
            { latitude: 40.384615, longitude: -3.672206, timestamp: admin.firestore.Timestamp.now(), altitude: 602 },
            { latitude: 40.384613, longitude: -3.672202, timestamp: admin.firestore.Timestamp.now(), altitude: 603 },
            { latitude: 40.384500, longitude: -3.672500, timestamp: admin.firestore.Timestamp.now(), altitude: 605 },
            { latitude: 40.384000, longitude: -3.673000, timestamp: admin.firestore.Timestamp.now(), altitude: 610 },
            { latitude: 40.383500, longitude: -3.673500, timestamp: admin.firestore.Timestamp.now(), altitude: 615 },
            { latitude: 40.383000, longitude: -3.673200, timestamp: admin.firestore.Timestamp.now(), altitude: 612 },
            { latitude: 40.382500, longitude: -3.673000, timestamp: admin.firestore.Timestamp.now(), altitude: 610 },
            { latitude: 40.382147, longitude: -3.672906, timestamp: admin.firestore.Timestamp.now(), altitude: 608 }
        ]
    }
    // Other mocks removed as requested
];

async function insertMocks() {
    console.log(`Inserting ${mocks.length} mocks into ${MOCK_COLLECTION}...`);
    const batch = db.batch();

    for (const mock of mocks) {
        const ref = db.collection(MOCK_COLLECTION).doc(mock.id);
        batch.set(ref, mock);
        console.log(`- Prepared: ${mock.id} (${mock.type})`);
    }

    await batch.commit();
    console.log('Mocks inserted successfully!');
}

insertMocks().catch(err => {
    console.error('Error inserting mocks:', err);
    process.exit(1);
});
