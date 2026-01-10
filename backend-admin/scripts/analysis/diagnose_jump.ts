import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * GPS JUMP DIAGNOSTIC
 * 
 * Pinpoints the exact location and time of the GPS teleportation.
 */

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
    const routesSnapshot = await db.collection("activities").doc(ACTIVITY_ID).collection("routes").orderBy("order", "asc").get();
    let allPoints: any[] = [];
    for (const doc of routesSnapshot.docs) {
        const chunk = doc.data();
        if (chunk.points) allPoints = allPoints.concat(chunk.points);
    }

    console.log(`\n🚨 DIAGNÓSTICO DE SALTO GPS`);
    console.log(`------------------------------`);

    for (let i = 0; i < allPoints.length - 1; i++) {
        const p1 = allPoints[i];
        const p2 = allPoints[i + 1];
        const d = distanceMeters(p1.latitude, p1.longitude, p2.latitude, p2.longitude);

        if (d > 500) { // Highlight jumps over 500m
            const t1 = p1.timestamp?.toDate ? p1.timestamp.toDate() : new Date(p1.timestamp);
            const t2 = p2.timestamp?.toDate ? p2.timestamp.toDate() : new Date(p2.timestamp);
            const timeDiff = (t2.getTime() - t1.getTime()) / 1000;

            console.log(`🚩 SALTO DETECTADO (Índice ${i} -> ${i + 1}):`);
            console.log(`   - Punto A: (${p1.latitude.toFixed(6)}, ${p1.longitude.toFixed(6)}) @ ${t1.toISOString()}`);
            console.log(`   - Punto B: (${p2.latitude.toFixed(6)}, ${p2.longitude.toFixed(6)}) @ ${t2.toISOString()}`);
            console.log(`   - Distancia del salto: ${d.toFixed(2)} m`);
            console.log(`   - Tiempo entre puntos: ${timeDiff.toFixed(2)} segundos`);
            console.log(`   - Velocidad aparente: ${(d / timeDiff * 3.6).toFixed(2)} km/h`);
        }
    }
    console.log(`------------------------------\n`);
}

main().catch(err => console.error(err));
