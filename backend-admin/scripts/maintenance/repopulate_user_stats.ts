import * as admin from "firebase-admin";
import * as fs from "fs";

// Initialize Firebase Admin
const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/backend-admin/secrets/serviceAccount.json";
if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
} else {
    console.log("⚠️ No serviceAccountKey.json found. Attempting default credentials...");
    admin.initializeApp(); // Use default credentials
}

const db = admin.firestore();

async function repopulateUserStats() {
    console.log("🚀 Starting User Stats Repopulation...");
    const now = new Date();

    const usersSnapshot = await db.collection("users").get();
    console.log(`Processing ${usersSnapshot.size} users...\n`);

    let updatedCount = 0;

    for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        console.log(`👤 User: ${userData.displayName || userId} (${userId})`);

        try {
            // 1. Count Total Activities
            const activitiesSnapshot = await db.collection("activities")
                .where("userId", "==", userId)
                .count()
                .get();
            const totalActivities = activitiesSnapshot.data().count;

            // 2. Count Active Territories (Current Ownership)
            const territoriesSnapshot = await db.collection("remote_territories")
                .where("userId", "==", userId)
                .where("expiresAt", ">", now)
                .count()
                .get();
            const activeOwnedCount = territoriesSnapshot.data().count;

            console.log(`   📊 Stats -> Activities: ${totalActivities}, Active Territories: ${activeOwnedCount}`);

            // 3. Update User Document
            await userDoc.ref.update({
                totalActivities: totalActivities,
                totalCellsOwned: activeOwnedCount,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            });

            updatedCount++;
        } catch (error) {
            console.error(`   ❌ Error updating user ${userId}:`, error);
        }
    }

    console.log(`\n✅ Finished! Updated ${updatedCount} users.`);
}

repopulateUserStats()
    .then(() => process.exit(0))
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
