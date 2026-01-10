import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

/**
 * CLEANUP & REPROCESS PRE ACTIVITY
 * 
 * Prepares a specific activity in PRE for a fresh processing run 
 * by removing associated territories and resetting its status.
 */

const ACTIVITY_ID = "0F97A333-C5CA-45FA-A824-426CB92407F5";
const PRE_DATABASE_ID = "adventure-streak-pre";

async function main() {
    const serviceAccountPath = path.resolve(process.cwd(), "secrets/serviceAccount.json");
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(PRE_DATABASE_ID);
    console.log(`\n🧹 LIMPIEZA DE ACTIVIDAD EN PRE: ${ACTIVITY_ID}`);
    console.log(`-----------------------------------------------`);

    // 1. Delete territories from remote_territories where activityId matches
    console.log(`📦 Borrando territorios asociados en remote_territories...`);
    const territoriesSnap = await db.collection("remote_territories")
        .where("activityId", "==", ACTIVITY_ID)
        .get();

    console.log(`   - Encontrados: ${territoriesSnap.size} territorios.`);

    if (!territoriesSnap.empty) {
        const batch = db.batch();
        territoriesSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`   - Borrado completado.`);
    }

    // 2. Delete territories subcollection in the activity
    console.log(`📂 Borrando subcolección 'territories' de la actividad...`);
    const subColSnap = await db.collection("activities").doc(ACTIVITY_ID).collection("territories").get();
    if (!subColSnap.empty) {
        const batch = db.batch();
        subColSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`   - Borrado de subcolección completado (${subColSnap.size} chunks).`);
    }

    // 3. Reset activity status and stats
    console.log(`🔄 Reiniciando estado de procesamiento a 'pending'...`);
    await db.collection("activities").doc(ACTIVITY_ID).update({
        processingStatus: "pending",
        territoryStats: null,
        xpBreakdown: null,
        missions: null,
        conqueredVictims: null,
        territoryChunkCount: 0,
        territoryPointsCount: 0
    });

    console.log(`\n✅ ACTIVIDAD LISTA PARA REPROCESAR.`);
    console.log(`La Cloud Function 'processActivityCompletePRE' debería activarse en breve.`);
    console.log(`-----------------------------------------------\n`);
}

main().catch(err => console.error(err));
