import * as admin from 'firebase-admin';
import * as path from 'path';

/**
 * Script to find the last workout (or incomplete ones) for a specific user in PRO (default database)
 * and display all its data.
 * 
 * Uses in-memory sorting to avoid Firestore index requirements and supports filtering by status.
 */

// Requisitos de Inicialización segun guidelines
const serviceAccountPath = path.resolve(__dirname, '../../secrets/serviceAccount.json');

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(require(serviceAccountPath)),
        projectId: "adventure-streak"
    });
}

const db = admin.firestore();

const userIdFromArgs = process.argv[2];
const targetUserId = userIdFromArgs || "i1CEf9eU4MhEOabFGrv2ymPSMFH3";
const searchIncomplete = process.argv.includes('--incomplete');

async function getLastWorkout(uid: string) {
    console.log(`\n🔍 Buscando ${searchIncomplete ? 'actividades NO COMPLETADAS' : 'la última actividad'} para el usuario: ${uid} en PRO`);

    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
        console.error(`❌ El usuario con UID ${uid} no existe en Firestore PRO.`);
        return;
    }
    const userData = userDoc.data();
    console.log(`👤 Usuario: ${userData?.displayName || 'N/A'} (${uid})`);

    console.log("📋 Consultando colección 'activities' (descargando últimas actividades para filtrar en memoria)...");

    // Consultamos sin order para evitar requisito de índice compuesto
    const activitiesSnapshot = await db.collection("activities")
        .where("userId", "==", uid)
        .limit(100)
        .get();

    if (activitiesSnapshot.empty) {
        console.log("❌ No se encontraron actividades para este usuario.");
        return;
    }

    let docs = activitiesSnapshot.docs;

    if (searchIncomplete) {
        docs = docs.filter(doc => doc.data().processingStatus !== 'completed');
        if (docs.length === 0) {
            console.log("❌ No se encontraron actividades incompletas (todas están 'completed').");
            return;
        }
    }

    // Ordenamos en memoria por el timestamp más reciente disponible (endDate, startDate, lastUpdatedAt)
    const getBestTimestamp = (data: any) => {
        const ts = data.endDate || data.startDate || data.lastUpdatedAt;
        if (!ts) return 0;
        return ts.toDate?.()?.getTime() || new Date(ts.value || ts).getTime() || 0;
    };

    const sortedDocs = docs.sort((a, b) => {
        return getBestTimestamp(b.data()) - getBestTimestamp(a.data());
    });

    const lastWorkoutDoc = sortedDocs[0];
    const lastWorkoutData = lastWorkoutDoc.data();

    console.log("\n✅ ¡ENTRENAMIENTO ENCONTRADO!");
    console.log(`🆔 ID de Actividad: ${lastWorkoutDoc.id}`);
    console.log("--------------------------------------------------");

    // Formateo de fechas para claridad
    const formatDate = (ts: any) => ts?.toDate?.()?.toISOString() || ts?.value || JSON.stringify(ts);
    console.log(`📅 End Date:   ${lastWorkoutData.endDate ? formatDate(lastWorkoutData.endDate) : '❌ MISSING'}`);
    console.log(`📅 Start Date: ${lastWorkoutData.startDate ? formatDate(lastWorkoutData.startDate) : '❌ MISSING'}`);
    console.log(`📅 Updated At: ${lastWorkoutData.lastUpdatedAt ? formatDate(lastWorkoutData.lastUpdatedAt) : '❌ MISSING'}`);
    console.log(`🔄 Status:     ${lastWorkoutData.processingStatus}`);
    console.log("--------------------------------------------------");
    console.log(JSON.stringify(lastWorkoutData, null, 2));
    console.log("--------------------------------------------------");

    const routesSnapshot = await db.collection(`activities/${lastWorkoutDoc.id}/routes`).get();
    console.log(`\n🛤️  Colección 'routes': ${routesSnapshot.size} chunks encontrados.`);
}

getLastWorkout(targetUserId).catch(err => {
    console.error("❌ Error ejecutando el script:", err);
    process.exit(1);
});
