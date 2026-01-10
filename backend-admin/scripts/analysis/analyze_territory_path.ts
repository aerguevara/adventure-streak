import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * PATH ANALYSIS TOOL
 * 
 * Verifies if a specific activity's GPS path actually intersects a given territory cell.
 */

// Grid logic from territories.ts
const CELL_SIZE_DEGREES = 0.002;

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

const TARGET_CELL_ID = "-1828_20190";
const ACTIVITY_ID = "0F97A333-C5CA-45FA-A824-426CB92407F5";

async function main() {
    const serviceAccountPath = path.resolve(process.cwd(), "secrets/serviceAccount.json");
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore();
    console.log(`\n🔍 ANALIZANDO RUTA GPS`);
    console.log(`------------------------------`);
    console.log(`Actividad: ${ACTIVITY_ID}`);
    console.log(`Celda Objetivo: ${TARGET_CELL_ID}`);
    console.log(`Límites Teóricos Celda: Lat [40.380, 40.382], Lon [-3.656, -3.654]`);

    // Fetch route chunks
    console.log(`\n📦 Recuperando fragmentos de ruta...`);
    const routesSnapshot = await db.collection("activities").doc(ACTIVITY_ID).collection("routes").orderBy("order", "asc").get();

    let allPoints: any[] = [];
    for (const doc of routesSnapshot.docs) {
        const chunk = doc.data();
        if (chunk.points) {
            allPoints = allPoints.concat(chunk.points);
        }
    }

    console.log(`📊 Puntos GPS totales: ${allPoints.length}`);

    if (allPoints.length === 0) {
        console.log("❌ Error: No se encontraron puntos GPS.");
        return;
    }

    let foundIntersection = false;
    let intersections: any[] = [];

    // Check every point and every segment (with interpolation)
    for (let i = 0; i < allPoints.length - 1; i++) {
        const start = allPoints[i];
        const end = allPoints[i + 1];
        const dist = distanceMeters(start.latitude, start.longitude, end.latitude, end.longitude);

        // Logic from getCellsBetween in territories.ts
        if (dist < 10) {
            const { x, y } = getCellIndex(start.latitude, start.longitude);
            if (getCellId(x, y) === TARGET_CELL_ID) {
                foundIntersection = true;
                intersections.push({ type: "Punto Original", index: i, lat: start.latitude, lon: start.longitude });
            }
        } else {
            const stepSize = 20.0; // 20 meters step as per function StepId 600
            const steps = Math.ceil(dist / stepSize);
            for (let j = 0; j <= steps; j++) {
                const fraction = j / steps;
                const lat = start.latitude + (end.latitude - start.latitude) * fraction;
                const lon = start.longitude + (end.longitude - start.longitude) * fraction;
                const { x, y } = getCellIndex(lat, lon);
                if (getCellId(x, y) === TARGET_CELL_ID) {
                    foundIntersection = true;
                    intersections.push({ type: "Segmento Interpolado", index: i, step: j, lat, lon });
                }
            }
        }
    }

    if (foundIntersection) {
        console.log(`\n✅ RESULTADO: ¡INTERSECCIÓN ENCONTRADA!`);
        console.log(`La actividad tocó la celda ${TARGET_CELL_ID} en ${intersections.length} instancias.`);

        console.log(`\n📍 Primeros puntos de impacto:`);
        intersections.slice(0, 5).forEach((hit, idx) => {
            console.log(`   [${idx + 1}] ${hit.type} (Coord: ${hit.lat.toFixed(6)}, ${hit.lon.toFixed(6)})`);
        });
    } else {
        console.log(`\n❌ RESULTADO: NO HAY INTERSECCIÓN.`);
        console.log(`La ruta GPS nunca entra en los límites de la celda ${TARGET_CELL_ID}.`);

        // Context box
        let minLat = Math.min(...allPoints.map(p => p.latitude));
        let maxLat = Math.max(...allPoints.map(p => p.latitude));
        let minLon = Math.min(...allPoints.map(p => p.longitude));
        let maxLon = Math.max(...allPoints.map(p => p.longitude));

        console.log(`\n🗺️  Caja Envolvente de la Actividad:`);
        console.log(`   Lat: [${minLat.toFixed(6)}, ${maxLat.toFixed(6)}]`);
        console.log(`   Lon: [${minLon.toFixed(6)}, ${maxLon.toFixed(6)}]`);
    }
    console.log(`------------------------------\n`);
}

main().catch(err => {
    console.error("❌ Error en el análisis:", err);
});
