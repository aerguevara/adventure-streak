import * as admin from 'firebase-admin';
import * as path from 'path';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// Ruta relativa desde functions/src/scripts/ hacia la raíz del proyecto
const serviceAccountPath = require('path').resolve(__dirname, '../../secrets/serviceAccount.json');

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(require(serviceAccountPath)),
        projectId: "adventure-streak"
    });
}

async function run() {
    const activityId = "A09BB1FD-C143-44EF-8C1C-B9BE9B23ECD5";
    const db = getFirestore("adventure-streak-pre");

    console.log(`🚀 Reprocesando actividad en PRE: ${activityId}`);

    const activityRef = db.collection("activities").doc(activityId);
    const activityDoc = await activityRef.get();

    if (!activityDoc.exists) {
        console.error("❌ ¡Actividad no encontrada en PRE!");
        return;
    }

    const activityData = activityDoc.data()!;
    const userId = activityData.userId;
    const stats = activityData.territoryStats || {};
    const xpToSubtract = activityData.xpBreakdown?.total || 0;
    const distanceToSubtract = (activityData.distanceMeters || 0) / 1000.0;

    console.log(`👤 Usuario: ${userId}`);
    console.log(`📉 Revirtiendo - XP: ${xpToSubtract}, Distancia: ${distanceToSubtract.toFixed(3)}km`);
    console.log(`📉 Revirtiendo stats de territorio:`, stats);

    const userRef = db.collection("users").doc(userId);

    // Revertir incrementos previos basándonos en lo que la actividad TRALÓ originalmente
    // Nota: vengeanceCellsCount NO se sustrae de totalStolenTerritories porque 
    // identificamos que antes NO se sumaba allí.
    const userUpdate: any = {
        xp: FieldValue.increment(-xpToSubtract),
        totalActivities: FieldValue.increment(-1),
        currentWeekDistanceKm: FieldValue.increment(-distanceToSubtract),
        totalDistanceKm: FieldValue.increment(-distanceToSubtract),
        totalConqueredTerritories: FieldValue.increment(-(stats.newCellsCount || 0)),
        totalStolenTerritories: FieldValue.increment(-(stats.stolenCellsCount || 0)),
        totalDefendedTerritories: FieldValue.increment(-(stats.defendedCellsCount || 0)),
        totalRecapturedTerritories: FieldValue.increment(-(stats.recapturedCellsCount || 0)),
        lastUpdated: FieldValue.serverTimestamp()
    };

    if (!activityData.xpBreakdown) {
        console.log("⚠️ La actividad no tiene xpBreakdown. Se saltará la reversión de stats del usuario para evitar valores negativos si nunca se sumaron.");
        // Solo quitamos la actividad y distancia si procede, o nada
    } else {
        await userRef.update(userUpdate);
        console.log("✅ Estadísticas del usuario revertidas en PRE.");
    }

    // Limpiar subcolección de territorios interna de la actividad
    console.log("🧹 Limpiando subcolección 'territories' de la actividad...");
    const territoriesSnapshot = await activityRef.collection("territories").get();
    const batch = db.batch();
    territoriesSnapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    // Resetear actividad a 'pending' para que la Cloud Function haga su magia con el nuevo código
    await activityRef.update({
        processingStatus: "pending",
        lastUpdatedAt: FieldValue.serverTimestamp(),
        // Limpiar resultados previos para evitar confusión
        conqueredVictims: FieldValue.delete(),
        territoryStats: FieldValue.delete(),
        xpBreakdown: FieldValue.delete(),
        missions: FieldValue.delete()
    });

    console.log("✅ Estado de la actividad cambiado a 'pending'. La función processActivityCompletePRE la procesará ahora.");
}

run().catch(console.error);
