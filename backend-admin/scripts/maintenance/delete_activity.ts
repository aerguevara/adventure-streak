import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";
import * as path from "path";

async function deleteActivity() {
    const activityId = "36BBBCE3-04DA-4243-B75B-80F542F56130"; // El entreno de ~6km del 15 de enero (0m de ruta en DB)
    const userId = "5CExEpO1mkQHlWo05VOjK2UtbDD2";

    console.log(`🧹 Iniciando eliminación de actividad ${activityId} para el usuario ${userId}...`);

    const serviceAccountPath = path.resolve(__dirname, "../../secrets/serviceAccount.json");
    const databaseId = "(default)"; // Entorno PRO según el análisis previo

    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore(databaseId);

    // 1. Eliminar de la colección 'activities'
    // La ruta es activities/ID
    const activityRef = db.collection("activities").doc(activityId);

    // 2. Buscar y eliminar del 'feed'
    const feedQuery = db.collection("feed").where("activityId", "==", activityId);
    const feedSnapshot = await feedQuery.get();

    const batch = db.batch();

    // Añadir eliminación de actividad si existe
    const activityDoc = await activityRef.get();
    if (activityDoc.exists) {
        console.log(`   - Marcando actividad para eliminar: ${activityId}`);
        batch.delete(activityRef);
    } else {
        console.log(`   ⚠️ La actividad ${activityId} no existe en la colección 'activities'.`);
    }

    // Añadir eliminaciones del feed
    if (!feedSnapshot.empty) {
        feedSnapshot.docs.forEach(doc => {
            console.log(`   - Marcando elemento del feed para eliminar: ${doc.id}`);
            batch.delete(doc.ref);
        });
    } else {
        console.log(`   ⚠️ No se encontraron elementos en el feed para la actividad ${activityId}.`);
    }

    if (activityDoc.exists || !feedSnapshot.empty) {
        await batch.commit();
        console.log("✨ Eliminación completada con éxito.");
        console.log("💡 Nota: El usuario debe abrir la app para que HealthKit detecte el entreno como 'nuevo' y lo vuelva a subir.");
    } else {
        console.log("⏭️ No se realizó ninguna acción (documentos no encontrados).");
    }
}

deleteActivity().catch(console.error);
