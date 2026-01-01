const admin = require('firebase-admin');
const path = require('path');

// Determine the path to service account
const serviceAccountPath = path.resolve(__dirname, '../../Docs/serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function normalize() {
    console.log('🚀 Starting normalization of Stolen Territories...');

    // 1. Process Feed Collection
    const feedSnapshot = await db.collection('feed').get();
    console.log(`📊 Processing ${feedSnapshot.size} feed events...`);

    let feedUpdated = 0;
    for (const doc of feedSnapshot.docs) {
        const data = doc.data();
        if (!data.activityId) continue;

        // Only process territory-related events
        if (!['territory_conquered', 'territory_recaptured', 'territory_lost'].includes(data.type)) {
            // Even if not strictly territory type, check if it has activity data with territories
            if (!(data.activityData && (data.activityData.newZonesCount > 0 || data.activityData.recapturedZonesCount > 0))) {
                continue;
            }
        }

        const activityDoc = await db.collection('activities').doc(data.activityId).get();
        if (!activityDoc.exists) {
            console.log(`⚠️  Activity ${data.activityId} not found for feed event ${doc.id}`);
            continue;
        }

        const activity = activityDoc.data();
        const stats = activity.territoryStats || {};

        const stolenCount = stats.stolenCellsCount || 0;
        const recapturedCount = stats.recapturedCellsCount || 0;
        const conquestCount = stats.newCellsCount || 0;
        const defendedCount = stats.defendedCellsCount || 0;

        let needsUpdate = false;
        const activityData = data.activityData || {};

        // Sync activityData counts
        if (activityData.stolenZonesCount !== stolenCount) {
            activityData.stolenZonesCount = stolenCount;
            needsUpdate = true;
        }

        if (activityData.recapturedZonesCount !== recapturedCount) {
            activityData.recapturedZonesCount = recapturedCount;
            needsUpdate = true;
        }

        // Re-generate subtitle to fix "robados" vs "recuperados" labels
        const missions = activity.missions || [];
        const missionNames = missions.map(m => m.name).join(" · ");

        let baseSubtitle = missionNames ? `Misiones: ${missionNames}` : "Actividad de Territorio";
        let territoryHighlights = [];
        if (conquestCount > 0) territoryHighlights.push(`${conquestCount} territorios conquistados`);
        if (defendedCount > 0) territoryHighlights.push(`${defendedCount} territorios defendidos`);
        if (recapturedCount > 0) territoryHighlights.push(`${recapturedCount} territorios recuperados`);
        if (stolenCount > 0) territoryHighlights.push(`${stolenCount} territorios robados`);

        let newSubtitle = baseSubtitle;
        if (territoryHighlights.length > 0) {
            newSubtitle += ` · ${territoryHighlights.join(" · ")}`;
        }

        if (data.subtitle !== newSubtitle) {
            needsUpdate = true;
        }

        if (needsUpdate) {
            console.log(`✅ Updating feed event ${doc.id} (Activity: ${data.activityId.substring(0, 8)}...)`);
            await doc.ref.update({
                activityData: activityData,
                subtitle: newSubtitle
            });
            feedUpdated++;
        }
    }

    console.log(`📈 Feed normalization complete. Updated ${feedUpdated} documents.`);

    // 2. Update User Cumulative Counters
    console.log('👤 Synchronizing user territory counters...');
    const usersSnapshot = await db.collection('users').get();
    let usersUpdated = 0;

    for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userActivities = await db.collection('activities')
            .where('userId', '==', userId)
            .where('processingStatus', '==', 'completed')
            .get();

        let totalConquered = 0;
        let totalStolen = 0;
        let totalDefended = 0;

        userActivities.forEach(ad => {
            const s = ad.data().territoryStats || {};
            totalConquered += (s.newCellsCount || 0);
            totalStolen += (s.stolenCellsCount || 0);
            totalDefended += (s.defendedCellsCount || 0);
        });

        const userData = userDoc.data();

        const currentConquered = userData.totalConqueredTerritories || 0;
        const currentStolen = userData.totalStolenTerritories || 0;
        const currentDefended = userData.totalDefendedTerritories || 0;

        if (currentConquered !== totalConquered ||
            currentStolen !== totalStolen ||
            currentDefended !== totalDefended) {

            console.log(`👤 User ${userData.displayName || userId}:`);
            console.log(`   - Conquered: ${currentConquered} -> ${totalConquered}`);
            console.log(`   - Stolen: ${currentStolen} -> ${totalStolen}`);
            console.log(`   - Defended: ${currentDefended} -> ${totalDefended}`);

            await userDoc.ref.update({
                totalConqueredTerritories: totalConquered,
                totalStolenTerritories: totalStolen,
                totalDefendedTerritories: totalDefended
            });
            usersUpdated++;
        }
    }

    console.log(`✨ User sync complete. Updated ${usersUpdated} users.`);
    console.log('🎉 Normalization Finished Successfuly!');
}

normalize().catch(err => {
    console.error('❌ Error during normalization:', err);
    process.exit(1);
});
