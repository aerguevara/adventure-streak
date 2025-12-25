const admin = require("firebase-admin");
const serviceAccount = require("../e2e_territories/service-account.json");

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function normalizeFeed() {
    console.log("🚀 Starting feed normalization...");
    const feedRef = db.collection("feed");
    const usersRef = db.collection("users");

    const feedSnapshot = await feedRef.get();
    console.log(`Found ${feedSnapshot.size} feed items.`);

    const userCache = new Map();
    let updatedCount = 0;
    let batch = db.batch();
    let opCount = 0;

    for (const feedDoc of feedSnapshot.docs) {
        const feedData = feedDoc.data();
        const userId = feedData.userId;

        if (!userId) {
            console.log(`⚠️ Feed item ${feedDoc.id} has no userId. Skipping.`);
            continue;
        }

        let userData = userCache.get(userId);
        if (!userData) {
            console.log(`Fetching user ${userId}...`);
            const userDoc = await usersRef.doc(userId).get();
            if (userDoc.exists) {
                userData = userDoc.data();
                userCache.set(userId, userData);
            }
        }

        if (userData) {
            const updates = {};

            // Normalize relatedUserName
            const correctName = userData.displayName || "Adventurer";
            if (feedData.relatedUserName !== correctName) {
                updates.relatedUserName = correctName;
            }

            // Normalize userLevel
            const correctLevel = userData.level || 1;
            if (feedData.userLevel !== correctLevel) {
                updates.userLevel = correctLevel;
            }

            // Normalize userAvatarURL
            const correctAvatar = userData.avatarURL || userData.photoURL || null;
            if (feedData.userAvatarURL !== correctAvatar) {
                updates.userAvatarURL = correctAvatar;
            }

            if (Object.keys(updates).length > 0) {
                console.log(`✅ Updating feed item ${feedDoc.id} for user ${correctName}:`, updates);
                batch.update(feedDoc.ref, updates);
                opCount++;
                updatedCount++;

                if (opCount >= 400) {
                    await batch.commit();
                    console.log(`📦 Committed batch of ${opCount} updates.`);
                    batch = db.batch();
                    opCount = 0;
                }
            }
        } else {
            console.log(`❌ User ${userId} not found for feed item ${feedDoc.id}.`);
        }
    }

    if (opCount > 0) {
        await batch.commit();
        console.log(`📦 Committed final batch of ${opCount} updates.`);
    }

    console.log(`🏁 Normalization complete. Updated ${updatedCount} feed items.`);
}

normalizeFeed().catch(e => {
    console.error("💥 Normalization failed:", e);
    process.exit(1);
});
