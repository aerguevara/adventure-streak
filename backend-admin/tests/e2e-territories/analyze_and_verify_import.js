const admin = require("firebase-admin");
const serviceAccount = require("../../secrets/serviceAccount.json");
const h3 = require("h3-js");

// --- CONFIG ---
const CELL_SIZE_DEGREES = 0.002;
const TARGET_USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82";
const GRID_RESOLUTION = 9; // Approx fit for 0.002 deg? Wait, code uses manual grid, not H3.
// WARNING: The TS code 'territories.ts' uses MANUALLY CALCULATED CELLS (0.002 deg), NOT h3-js proper.
// I must replicate THAT logic, not h3.

// Replicating territories.ts exactly
function getCellIndex(latitude, longitude) {
    const x = Math.floor(longitude / CELL_SIZE_DEGREES);
    const y = Math.floor(latitude / CELL_SIZE_DEGREES);
    return { x, y };
}
function getCellId(x, y) { return `${x}_${y}`; }

function distanceMeters(lat1, lon1, lat2, lon2) {
    const R = 6371e3;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

function getCellsBetween(start, end) {
    const cells = new Set();
    const dist = distanceMeters(start.latitude, start.longitude, end.latitude, end.longitude);
    if (dist < 10) {
        const { x, y } = getCellIndex(start.latitude, start.longitude);
        cells.add(getCellId(x, y));
        return cells;
    }
    const stepSize = 20.0;
    const steps = Math.ceil(dist / stepSize);
    for (let i = 0; i <= steps; i++) {
        const fraction = i / steps;
        const lat = start.latitude + (end.latitude - start.latitude) * fraction;
        const lon = start.longitude + (end.longitude - start.longitude) * fraction;
        const { x, y } = getCellIndex(lat, lon);
        cells.add(getCellId(x, y));
    }
    return cells;
}

// --- MAIN ---
if (admin.apps.length === 0) {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}
const db = admin.firestore();

async function analyze() {
    console.log(`🧠 STARTING ANALYSIS FOR: ${TARGET_USER_ID}`);

    // 1. Fetch All Activities (Index-free)
    const snaps = await db.collection("activities")
        .where("userId", "==", TARGET_USER_ID)
        .get();

    // In-memory sort
    const docs = snaps.docs.sort((a, b) => a.data().endDate.toMillis() - b.data().endDate.toMillis());

    console.log(`📂 Found ${docs.length} activities. Fetching full data (routes)...`);

    // Mock "Server State" of territories
    // Map<CellID, OwnerID>
    const globalTerritoryMap = new Map();

    const config = {
        minDistanceKm: 0.5,
        minDurationSeconds: 300,
        xpPerNewCell: 8,
        xpPerDefendedCell: 3,
        xpPerRecapturedCell: 12,
        maxNewCellsXPPerActivity: 50,
        baseFactorPerKm: 10,
        legendaryThresholdCells: 20
    };

    let totalCalculatedXP = 0;
    let localLevel = 1;

    for (const doc of docs) {
        const data = doc.data();
        const activityId = doc.id;

        // A. Reconstruct Route
        // We need to fetch subcollection 'routes'
        const routeSnaps = await doc.ref.collection("routes").orderBy("order").get();
        let allPoints = [];
        routeSnaps.docs.forEach(r => {
            const rd = r.data();
            if (rd.points) {
                allPoints = allPoints.concat(rd.points.map(p => ({
                    latitude: p.latitude,
                    longitude: p.longitude
                })));
            }
        });

        if (allPoints.length === 0) {
            console.log(`⚠️ Activity ${activityId} has NO POINTS.`);
            continue;
        }

        // B. Calculate Traversed Cells
        const traversedCells = new Set();
        // Start point
        const startIdx = getCellIndex(allPoints[0].latitude, allPoints[0].longitude);
        traversedCells.add(getCellId(startIdx.x, startIdx.y));

        for (let i = 0; i < allPoints.length - 1; i++) {
            const seg = getCellsBetween(allPoints[i], allPoints[i + 1]);
            seg.forEach(c => traversedCells.add(c));
        }

        // C. Determine Status vs Global Map
        let newCells = 0;
        let defended = 0;
        let recaptured = 0;

        // Since it's a fresh user with NO competitors (in this sim), 
        // every cell is either NEW (not in map) or DEFENDED (already mine). 
        // Unless we are comparing against REAL DB which might have other people?
        // User asked "comparar con lo que ha hecho la app". The app (Server) ran against the REAL DB.
        // But we just wiped the user, so "REAL DB" should only have THIS user's stuff appearing incrementally.
        // Assumption: No other users interfere in this region.

        traversedCells.forEach(cellId => {
            if (globalTerritoryMap.has(cellId)) {
                // Already owned by me (since I'm the only one in this sim)
                defended++;
            } else {
                newCells++;
                globalTerritoryMap.set(cellId, TARGET_USER_ID);
            }
        });

        // D. Calculate XP (SIMULATED)
        const distKm = (data.distanceMeters || 0) / 1000;
        const durSec = data.durationSeconds || 0;

        // Base XP
        let baseXP = distKm * config.baseFactorPerKm;
        if (data.activityType === "run") baseXP *= 1.2;
        else if (data.activityType === "bike") baseXP *= 0.7;

        // Territory XP
        const cellXP = Math.min((newCells * config.xpPerNewCell), config.maxNewCellsXPPerActivity) + (defended * config.xpPerDefendedCell);

        const totalSimXP = Math.round(baseXP + cellXP);
        totalCalculatedXP += totalSimXP;

        // E. Missions (SIMULATED)
        const simMissions = [];
        // Territorial
        if (newCells >= config.legendaryThresholdCells) simMissions.push("Dominio Legendario");
        else if (newCells >= 15) simMissions.push("Conquista Épica");
        else if (newCells >= 5) simMissions.push("Expedición");
        else if (newCells > 0) simMissions.push("Exploración Inicial");

        // Physical
        const pace = distKm > 0 ? durSec / distKm : 0;
        if (data.activityType === "run" && pace < 360 && distKm > 0) { // < 6 min/km
            simMissions.push("Sprint Intenso");
        }

        // F. COMPARE
        console.log(`\n📊 Activity: ${data.workoutName || activityId} (${data.activityType})`);
        console.log(`   📅 Date: ${new Date(data.endDate.toDate()).toLocaleString()}`);
        console.log(`   📍 Cells Traversed: ${traversedCells.size} | Calculated: New=${newCells}, Def=${defended}`);

        // Compare Territory Stats
        const storedStats = data.territoryStats || { newCellsCount: 0, defendedCellsCount: 0, recapturedCellsCount: 0 };
        const statsMatch = (storedStats.newCellsCount === newCells && storedStats.defendedCellsCount === defended);
        console.log(`   🏳️  Territory Check: ${statsMatch ? "✅ MATCH" : "❌ MISMATCH"}`);
        if (!statsMatch) console.log(`      > Sim: +${newCells} / 🛡️${defended} / ♻️${recaptured}  vs  Stored: +${storedStats.newCellsCount} / 🛡️${storedStats.defendedCellsCount} / ♻️${storedStats.recapturedCellsCount}`);

        // Compare Missions
        const storedMissions = (data.missions || []).map(m => m.name);
        const missionMatch = JSON.stringify(simMissions.sort()) === JSON.stringify(storedMissions.sort());
        console.log(`   🎖️  Mission Check:   ${missionMatch ? "✅ MATCH" : "❌ MISMATCH"}`);
        if (!missionMatch) console.log(`      > Sim: ${JSON.stringify(simMissions)}  vs  Stored: ${JSON.stringify(storedMissions)}`);

        // Debug Physical
        if (data.activityType === "run") {
            const paceMinKm = pace / 60;
            console.log(`      > Pace: ${paceMinKm.toFixed(2)} min/km (Threshold: 6.00)`);
        }

        // Compare XP (Roughly)
        const storedXP = data.xpBreakdown ? data.xpBreakdown.total : 0;
        const xpDiff = Math.abs(storedXP - totalSimXP);
        console.log(`   ⚡ XP Check:        ${xpDiff < 5 ? "✅ MATCH" : "⚠️ DIFF"} (Sim: ${totalSimXP} vs Stored: ${storedXP})`);
    }
}

analyze().catch(console.error);
