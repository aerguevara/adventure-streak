import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * COMPREHENSIVE ACTIVITY CELL ANALYSIS
 * 
 * Verifies ALL territory cells attributed to an activity against its GPS path.
 * 
 * Usage: npm run script scripts/analysis/analyze_all_activity_cells.ts
 */

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
    console.log(`\n🧪 INICIANDO ANÁLISIS INTEGRAL DE CELDAS`);
    console.log(`------------------------------------------`);
    console.log(`Actividad: ${ACTIVITY_ID}`);

    // 1. Fetch GPS Route
    console.log(`\n📦 Pasado 1: Recuperando ruta GPS...`);
    const routesSnapshot = await db.collection("activities").doc(ACTIVITY_ID).collection("routes").orderBy("order", "asc").get();

    let allPoints: any[] = [];
    for (const doc of routesSnapshot.docs) {
        const chunk = doc.data();
        if (chunk.points) {
            allPoints = allPoints.concat(chunk.points);
        }
    }
    console.log(`   - Puntos GPS recuperados: ${allPoints.length}`);

    if (allPoints.length === 0) {
        console.log("❌ Error: No hay puntos GPS para analizar.");
        return;
    }

    // 2. Generate Theoretical Cells (Path Trace)
    console.log(`\n🗺️  Paso 2: Trazando ruta teórica (interpolación 20m)...`);
    const theoreticalCells = new Set<string>();

    for (let i = 0; i < allPoints.length - 1; i++) {
        const start = allPoints[i];
        const end = allPoints[i + 1];
        const dist = distanceMeters(start.latitude, start.longitude, end.latitude, end.longitude);

        if (dist < 10) {
            const { x, y } = getCellIndex(start.latitude, start.longitude);
            theoreticalCells.add(getCellId(x, y));
        } else {
            const stepSize = 20.0;
            const steps = Math.ceil(dist / stepSize);
            for (let j = 0; j <= steps; j++) {
                const fraction = j / steps;
                const lat = start.latitude + (end.latitude - start.latitude) * fraction;
                const lon = start.longitude + (end.longitude - start.longitude) * fraction;
                const { x, y } = getCellIndex(lat, lon);
                theoreticalCells.add(getCellId(x, y));
            }
        }
    }
    // Don't forget the last point if it wasn't added
    const lastPoint = allPoints[allPoints.length - 1];
    const { x: lx, y: ly } = getCellIndex(lastPoint.latitude, lastPoint.longitude);
    theoreticalCells.add(getCellId(lx, ly));

    console.log(`   - Celdas teóricas detectadas: ${theoreticalCells.size}`);

    // 3. Fetch Recorded Cells from Activity Subcollection
    console.log(`\n💾 Paso 3: Recuperando celdas registradas en Firestore...`);
    const recordedCells = new Set<string>();
    const recordedSnapshot = await db.collection("activities").doc(ACTIVITY_ID).collection("territories").get();

    for (const doc of recordedSnapshot.docs) {
        const chunk = doc.data();
        if (chunk.cells && Array.isArray(chunk.cells)) {
            chunk.cells.forEach((cell: any) => recordedCells.add(cell.id));
        }
    }
    console.log(`   - Celdas registradas encontradas: ${recordedCells.size}`);

    // 4. Verification & Comparison
    console.log(`\n⚖️  Paso 4: Comparando conjuntos...`);

    const onlyTheoretical = [...theoreticalCells].filter(id => !recordedCells.has(id));
    const onlyRecorded = [...recordedCells].filter(id => !theoreticalCells.has(id));

    if (onlyTheoretical.length === 0 && onlyRecorded.length === 0) {
        console.log(`\n✅ TODO COINCIDE PERFECTAMENTE.`);
        console.log(`Las ${theoreticalCells.size} celdas generadas por la ruta GPS son exactamente las ${recordedCells.size} registradas.`);
    } else {
        console.log(`\n⚠️  DISCREPANCIAS ENCONTRADAS:`);

        if (onlyTheoretical.length > 0) {
            console.log(`\n❌ Celdas TEÓRICAS no registradas (${onlyTheoretical.length}):`);
            onlyTheoretical.forEach(id => console.log(`   - ${id}`));
        }

        if (onlyRecorded.length > 0) {
            console.log(`\n❌ Celdas REGISTRADAS no presentes en la ruta teórica (${onlyRecorded.length}):`);
            onlyRecorded.forEach(id => console.log(`   - ${id}`));
        }

        console.log(`\nResumen:`);
        console.log(`  - Teóricas: ${theoreticalCells.size}`);
        console.log(`  - Registradas: ${recordedCells.size}`);
        console.log(`  - Coincidentes: ${theoreticalCells.size - onlyTheoretical.length}`);
    }
    console.log(`------------------------------------------\n`);
}

main().catch(err => {
    console.error("❌ Error inesperado:", err);
});
