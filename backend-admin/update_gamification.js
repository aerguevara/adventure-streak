const admin = require('firebase-admin');

const serviceAccountPath = './secrets/serviceAccount.json';

try {
    admin.initializeApp({
        credential: admin.credential.cert(require(serviceAccountPath)),
        projectId: "adventure-streak"
    });
} catch (e) {
    console.log("Admin already initialized or error:", e.message);
}

const { getFirestore } = require('firebase-admin/firestore');

async function updateConfig() {
    const dbs = ["(default)", "adventure-streak-pre"];
    const updateData = {
        xpLootPerDay: 5,
        xpConsolidation15DayBonus: 10,
        xpConsolidation25DayBonus: 20
    };

    for (const dbId of dbs) {
        process.stdout.write(`Updating ${dbId}... `);
        try {
            const db = getFirestore(dbId);
            await db.collection("config").doc("gamification").set(updateData, { merge: true });
            process.stdout.write(`✅\n`);
        } catch (err) {
            process.stdout.write(`❌ Error: ${err.message}\n`);
        }
    }
}

updateConfig().then(() => {
    process.exit(0);
}).catch(e => {
    console.error("Critical error:", e);
    process.exit(1);
});
