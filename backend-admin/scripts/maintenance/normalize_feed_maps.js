const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.resolve(__dirname, '../../Docs/serviceAccount.json'));

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Helper to calculate region
function calculateRegion(cells) {
    if (!cells || cells.length === 0) return null;

    let minLat = cells[0].centerLatitude;
    let maxLat = cells[0].centerLatitude;
    let minLon = cells[0].centerLongitude;
    let maxLon = cells[0].centerLongitude;

    cells.forEach(cell => {
        if (cell.centerLatitude < minLat) minLat = cell.centerLatitude;
        if (cell.centerLatitude > maxLat) maxLat = cell.centerLatitude;
        if (cell.centerLongitude < minLon) minLon = cell.centerLongitude;
        if (cell.centerLongitude > maxLon) maxLon = cell.centerLongitude;
    });

    // Add padding (approx 1.5x span)
    const latSpan = (maxLat - minLat);
    const lonSpan = (maxLon - minLon);

    // Ensure minimum span
    const finalLatSpan = Math.max(latSpan * 1.5, 0.005);
    const finalLonSpan = Math.max(lonSpan * 1.5, 0.005);

    const centerLat = (minLat + maxLat) / 2.0;
    const centerLon = (minLon + maxLon) / 2.0;

    return {
        centerLatitude: centerLat,
        centerLongitude: centerLon,
        spanLatitudeDelta: finalLatSpan,
        spanLongitudeDelta: finalLonSpan
    };
}

async function run() {
    console.log("🔍 Starting Feed Map Normalization...");

    // 1. Get all feed items for our user
    const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
    const feedSnapshot = await db.collection('feed')
        .where('userId', '==', userId)
        .get();

    console.log(`Found ${feedSnapshot.size} feed items.`);

    let updatedCount = 0;

    for (const doc of feedSnapshot.docs) {
        const feedData = doc.data();

        // Skip if already has map
        if (feedData.miniMapRegion) {
            console.log(`✅ Skipping ${doc.id} (already has map)`);
            continue;
        }

        // Needs map
        const activityId = feedData.activityId;
        console.log(`🛠 Processing ${doc.id} (Activity: ${activityId})...`);

        if (!activityId) {
            console.log(`⚠️ No activityId for ${doc.id}`);
            continue;
        }

        // Fetch territories for this activity
        // They are in activities/{activityId}/territories/{chunk_X}
        const territoryChunksQuery = await db.collection('activities')
            .doc(activityId)
            .collection('territories')
            .get();

        let allCells = [];
        territoryChunksQuery.forEach(chunkDoc => {
            const data = chunkDoc.data();
            if (data.cells && Array.isArray(data.cells)) {
                allCells = allCells.concat(data.cells);
            }
        });

        if (allCells.length > 0) {
            const region = calculateRegion(allCells);
            if (region) {
                await doc.ref.update({ miniMapRegion: region });
                console.log(`✨ Updated ${doc.id} with region from ${allCells.length} cells.`);
                updatedCount++;
            } else {
                console.log(`⚠️ Failed to calc region for ${doc.id}`);
            }
        } else {
            console.log(`⚠️ No territories found for activity ${activityId}. Applying fallback region.`);
            // Fallback: Global map (Null Island / World View)
            const fallbackRegion = {
                centerLatitude: 0.0,
                centerLongitude: 0.0,
                spanLatitudeDelta: 90.0,
                spanLongitudeDelta: 180.0
            };
            await doc.ref.update({ miniMapRegion: fallbackRegion });
            updatedCount++;
        }
    }

    console.log(`\n🎉 Normalization Complete.`);
    console.log(`Updated ${updatedCount} documents.`);
}

run().catch(console.error);
