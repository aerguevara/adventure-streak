import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * ACTIVITY DEEP ANALYSIS TOOL
 * 
 * Comprehensive diagnostic for a specific activity or territory.
 * 
 * Usage: 
 *   npm run script scripts/analysis/activity_deep_analysis.ts [PRE|PRO] --activity [ID]
 *   npm run script scripts/analysis/activity_deep_analysis.ts [PRE|PRO] --cell [ID]
 */

const CELL_SIZE_DEGREES = 0.002;
const MAX_INTERPOLATION_DISTANCE_METERS = 300;

function getCellIndex(latitude: number, longitude: number): { x: number, y: number } {
    const x = Math.floor(longitude / CELL_SIZE_DEGREES);
    const y = Math.floor(latitude / CELL_SIZE_DEGREES);
    return { x, y };
}

function getCellId(x: number, y: number): string {
    return `${x}_${y}`;
}

function distanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371e3;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
        Math.cos(φ1) * Math.cos(φ2) *
        Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

async function main() {
    const args = process.argv.slice(2);
    const envArg = args[0] || "PRE";
    const mode = args[1]; // --activity or --cell
    const targetId = args[2];

    if (!mode || !targetId) {
        console.log("Usage: npm run script scripts/analysis/activity_deep_analysis.ts [PRE|PRO] --activity [ID] | --cell [ID]");
        process.exit(1);
    }

    const isPro = envArg === "PRO";
    const projectId = "adventure-streak";
    const databaseId = isPro ? "(default)" : "adventure-streak-pre";

    const serviceAccountPath = path.resolve(process.cwd(), "secrets/serviceAccount.json");
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: projectId
        });
    }

    const db = databaseId === "(default)" ? getFirestore() : getFirestore(databaseId);

    let activityId = "";

    if (mode === "--cell") {
        console.log(`\n🔎 Buscando actividad para la celda ${targetId}...`);
        const cellDoc = await db.collection("remote_territories").doc(targetId).get();
        if (!cellDoc.exists) {
            console.error(`❌ Error: La celda ${targetId} no existe en ${envArg}.`);
            process.exit(1);
        }
        activityId = cellDoc.data()?.activityId;
        if (!activityId) {
            console.error(`❌ Error: La celda no tiene una actividad asociada.`);
            process.exit(1);
        }
        console.log(`✅ Actividad encontrada: ${activityId}`);
    } else {
        activityId = targetId;
    }

    console.log(`\n🧪 INICIANDO ANÁLISIS PROFUNDO DE ACTIVIDAD`);
    console.log(`------------------------------------------`);
    console.log(`ID: ${activityId}`);
    console.log(`Entorno: ${envArg} (${databaseId})`);

    // 1. Fetch Activity Doc
    const activityDoc = await db.collection("activities").doc(activityId).get();
    if (!activityDoc.exists) {
        console.error(`❌ Error: La actividad ${activityId} no existe.`);
        process.exit(1);
    }
    const data = activityDoc.data() || {};

    console.log(`\n📋 DATOS DEL DOCUMENTO:`);
    console.log(`   - Usuario: ${data.userId} (${data.userName || 'N/A'})`);
    console.log(`   - Tipo: ${data.activityType}`);
    console.log(`   - Distancia Registrada: ${data.distanceMeters?.toFixed(2)} m`);
    console.log(`   - Fecha: ${data.endDate?.toDate?.().toISOString() || data.endDate}`);
    console.log(`   - Status de Procesamiento: ${data.processingStatus}`);
    if (data.territoryStats) {
        console.log(`   - Stats Territoriales: ${JSON.stringify(data.territoryStats)}`);
    }

    // 2. Fetch GPS Route
    console.log(`\n📦 Pasado 1: Analizando ruta GPS...`);
    const routesSnapshot = await db.collection("activities").doc(activityId).collection("routes").orderBy("order", "asc").get();

    let allPoints: any[] = [];
    for (const doc of routesSnapshot.docs) {
        const chunk = doc.data();
        if (chunk.points) allPoints = allPoints.concat(chunk.points);
    }
    console.log(`   - Puntos GPS totales: ${allPoints.length}`);

    if (allPoints.length === 0) {
        console.log("   ⚠️  No hay puntos GPS en esta actividad.");
    } else {
        let calculatedGpsDist = 0;
        let theoreticalCells = new Set<string>();
        let jumps: any[] = [];

        for (let i = 0; i < allPoints.length - 1; i++) {
            const p1 = allPoints[i];
            const p2 = allPoints[i + 1];
            const d = distanceMeters(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
            calculatedGpsDist += d;

            if (d > MAX_INTERPOLATION_DISTANCE_METERS) {
                jumps.push({ idx: i, dist: d });
            }

            // Theoretical trace logic
            if (d < 10) {
                const { x, y } = getCellIndex(p1.latitude, p1.longitude);
                theoreticalCells.add(getCellId(x, y));
            } else if (d <= MAX_INTERPOLATION_DISTANCE_METERS) {
                const steps = Math.ceil(d / 20.0);
                for (let j = 0; j <= steps; j++) {
                    const lat = p1.latitude + (p2.latitude - p1.latitude) * (j / steps);
                    const lon = p1.longitude + (p2.longitude - p1.longitude) * (j / steps);
                    const idx = getCellIndex(lat, lon);
                    theoreticalCells.add(getCellId(idx.x, idx.y));
                }
            } else {
                // Jump detected: only endpoints
                const sIdx = getCellIndex(p1.latitude, p1.longitude);
                theoreticalCells.add(getCellId(sIdx.x, sIdx.y));
                const eIdx = getCellIndex(p2.latitude, p2.longitude);
                theoreticalCells.add(getCellId(eIdx.x, eIdx.y));
            }
        }

        console.log(`   - Distancia Σ GPS: ${calculatedGpsDist.toFixed(2)} m`);
        console.log(`   - Saltos > ${MAX_INTERPOLATION_DISTANCE_METERS}m: ${jumps.length}`);
        jumps.forEach(j => {
            console.log(`     🚩 Salto en índice ${j.idx}: ${j.dist.toFixed(0)}m`);
        });

        // 3. Fetch Recorded Territories
        console.log(`\n💾 Paso 2: Comparando con territorios registrados...`);
        const recordedCells = new Set<string>();
        const recordedSnapshot = await db.collection("activities").doc(activityId).collection("territories").get();
        for (const doc of recordedSnapshot.docs) {
            const chunk = doc.data();
            if (chunk.cells) chunk.cells.forEach((c: any) => recordedCells.add(c.id));
        }

        console.log(`   - Celdas Teóricas (con parche GPS): ${theoreticalCells.size}`);
        console.log(`   - Celdas Registradas en Firestore: ${recordedCells.size}`);

        const onlyTheoretical = [...theoreticalCells].filter(id => !recordedCells.has(id));
        const onlyRecorded = [...recordedCells].filter(id => !theoreticalCells.has(id));

        if (onlyTheoretical.length === 0 && onlyRecorded.length === 0) {
            console.log(`   ✅ COINCIDENCIA TOTAL: Los territorios coinciden con la ruta analizada.`);
        } else {
            console.log(`   ⚠️  DISCREPANCIAS:`);
            if (onlyTheoretical.length > 0) console.log(`      - Solo teóricas (${onlyTheoretical.length}): ${onlyTheoretical.slice(0, 5).join(", ")}...`);
            if (onlyRecorded.length > 0) console.log(`      - Solo registradas (${onlyRecorded.length}): ${onlyRecorded.slice(0, 5).join(", ")}...`);
        }
    }

    console.log(`------------------------------------------\n`);
}

main().catch(err => {
    console.error("❌ Error inesperado:", err);
});
