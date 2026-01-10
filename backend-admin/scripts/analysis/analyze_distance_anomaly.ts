import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * DISTANCE ANOMALY ANALYZER
 * 
 * Recalculates exact GPS distance and territory coverage distance.
 */

const CELL_SIZE_DEGREES = 0.002;

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
    console.log(`\n🔍 INVESTIGACIÓN DE DISCREPANCIA DE DISTANCIA`);
    console.log(`---------------------------------------------`);
    console.log(`Actividad: ${ACTIVITY_ID}`);

    // 1. GPS Distance
    const routesSnapshot = await db.collection("activities").doc(ACTIVITY_ID).collection("routes").orderBy("order", "asc").get();
    let allPoints: any[] = [];
    for (const doc of routesSnapshot.docs) {
        const chunk = doc.data();
        if (chunk.points) allPoints = allPoints.concat(chunk.points);
    }

    let calculatedGpsDistance = 0;
    let jumpsCount = 0;
    let maxJump = 0;

    for (let i = 0; i < allPoints.length - 1; i++) {
        const d = distanceMeters(allPoints[i].latitude, allPoints[i].longitude, allPoints[i + 1].latitude, allPoints[i + 1].longitude);
        calculatedGpsDistance += d;
        if (d > 50) { // Any jump > 50m between points (usually 1s apart) is suspicious for a walk
            jumpsCount++;
            maxJump = Math.max(maxJump, d);
        }
    }

    // 2. Territory Distance (Recorded)
    const recordedSnapshot = await db.collection("activities").doc(ACTIVITY_ID).collection("territories").get();
    let cells: any[] = [];
    for (const doc of recordedSnapshot.docs) {
        const chunk = doc.data();
        if (chunk.cells) cells = cells.concat(chunk.cells);
    }

    // Sort cells by longitude to get a rough idea of span
    const minLon = Math.min(...cells.map(c => c.centerLongitude));
    const maxLon = Math.max(...cells.map(c => c.centerLongitude));
    const minLat = Math.min(...cells.map(c => c.centerLatitude));
    const maxLat = Math.max(...cells.map(c => c.centerLatitude));

    const spanDistance = distanceMeters(minLat, minLon, maxLat, maxLon);

    // 3. Activity Summary
    const activityDoc = await db.collection("activities").doc(ACTIVITY_ID).get();
    const activityData = activityDoc.data() || {};

    console.log(`\n📋 DATOS REGISTRADOS EN FIREBASE:`);
    console.log(`   - Distancia en el Doc: ${(activityData.distanceMeters || 0).toFixed(2)} m`);
    console.log(`   - Celdas Registradas: ${cells.length}`);

    console.log(`\n🧮 RE-CÁLCULO TÉCNICO:`);
    console.log(`   - Distancia Real GPS (Σ segmentos): ${calculatedGpsDistance.toFixed(2)} m`);
    console.log(`   - Distancia en línea recta (Min -> Max): ${spanDistance.toFixed(2)} m`);
    console.log(`   - Saltos > 50m detectados: ${jumpsCount}`);
    if (jumpsCount > 0) {
        console.log(`   - Salto máximo entre dos puntos: ${maxJump.toFixed(2)} m`);
    }

    console.log(`\n⚠️  ANÁLISIS DE ANOMALÍA:`);
    if (Math.abs(calculatedGpsDistance - activityData.distanceMeters) > 10) {
        console.log(`   ❌ ERROR: La distancia sumada de los GPS (${calculatedGpsDistance.toFixed(2)}m) NO coincide con el total del documento (${activityData.distanceMeters.toFixed(2)}m).`);
    } else {
        console.log(`   ✅ La distancia en el documento coincide con la suma de puntos.`);
    }

    if (spanDistance > calculatedGpsDistance) {
        console.log(`   🚨 GRAVE: La distancia lineal entre las celdas tomadas (${spanDistance.toFixed(2)}m) es MAYOR que la distancia total recorrida (${calculatedGpsDistance.toFixed(2)}m).`);
        console.log(`   Esto indica que el GPS dio saltos temporales (teletransporte) o la grabación se cortó.`);
    }

    console.log(`   - Ratio Celdas/Distancia: ${(cells.length / (calculatedGpsDistance / 100)).toFixed(2)} celdas/100m`);
    console.log(`---------------------------------------------\n`);
}

main().catch(err => {
    console.error(err);
});
