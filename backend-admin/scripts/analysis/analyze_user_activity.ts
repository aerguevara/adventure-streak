import * as admin from 'firebase-admin';
import * as path from 'path';

// Requisitos de Inicialización segun guidelines
const serviceAccountPath = path.resolve(__dirname, '../../secrets/serviceAccount.json');

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(require(serviceAccountPath)),
        projectId: "adventure-streak"
    });
}

// Entorno PRO
const db = admin.firestore();

const userId = process.argv[2];
if (!userId) {
    console.error("❌ Por favor, proporciona un userId como argumento.");
    process.exit(1);
}

// --- HELPERS PARA SIMULACION (Copiados de analyze_territories.js) ---
const CELL_SIZE_DEGREES = 0.002;

function getCellIndex(latitude: number, longitude: number) {
    const x = Math.floor(longitude / CELL_SIZE_DEGREES);
    const y = Math.floor(latitude / CELL_SIZE_DEGREES);
    return { x, y };
}

function getCellId(x: number, y: number) {
    return `${x}_${y}`;
}

async function analyzeUser(uid: string) {
    console.log(`\n🔍 Analizando usuario: ${uid}`);

    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
        console.log("❌ Usuario no encontrado.");
        return;
    }
    const userData = userDoc.data()!;
    console.log(`👤 Nombre: ${userData.displayName}`);
    console.log(`📅 Última actividad (perfil): ${userData.lastActivityDate?.toDate()?.toISOString() || 'N/A'}`);
    console.log(`📅 Último resumen (perfil): ${userData.lastUpdated?.toDate()?.toISOString() || 'N/A'}`);

    console.log("\n📋 Buscando actividades...");
    const activitiesSnapshot = await db.collection("activities")
        .where("userId", "==", uid)
        .get();

    if (activitiesSnapshot.empty) {
        console.log("❌ No se encontraron actividades para este usuario.");
        return;
    }

    // Sort in memory to avoid index requirement
    const sortedDocs = activitiesSnapshot.docs.sort((a, b) => {
        const dateA = a.data().endDate?.toDate?.() || new Date(a.data().endDate);
        const dateB = b.data().endDate?.toDate?.() || new Date(b.data().endDate);
        return dateB.getTime() - dateA.getTime();
    }).slice(0, 10);

    for (const doc of sortedDocs) {
        const data = doc.data();
        const id = doc.id;
        const endDate = data.endDate?.toDate?.() || new Date(data.endDate);

        console.log(`\n--- ACTIVIDAD: ${id} ---`);
        console.log(`📅 Fecha: ${endDate.toISOString()}`);
        console.log(`🏷️  Tipo: ${data.activityType}`);
        console.log(`📍 Ubicación: ${data.locationLabel || 'N/A'}`);
        console.log(`🔄 Status: ${data.processingStatus}`);
        const distanceKm = (data.distanceMeters || 0) / 1000;
        console.log(`📏 Distancia: ${distanceKm.toFixed(2)} km`);
        console.log(`🛤️  Puntos Ruta: ${data.routePointsCount || 0}`);
        console.log(`🗺️  Territorios: ${data.territoryPointsCount || 0}`);

        if (data.activityType === 'indoor') {
            console.log("ℹ️  INFO: Actividad Indoor. Los territorios no se procesan para este tipo.");
        }

        if (data.processingStatus !== 'completed') {
            console.log("⚠️  ADVERTENCIA: El status de procesamiento no es 'completed'.");
        }

        // Análisis de rutas
        const routesSnapshot = await db.collection(`activities/${id}/routes`).get();
        if (routesSnapshot.empty) {
            console.log("❌ ERROR: No hay colección 'routes' para esta actividad.");
        } else {
            console.log(`✅ Colección 'routes' encontrada (${routesSnapshot.size} chunks).`);
            let totalPoints = 0;
            routesSnapshot.docs.forEach(d => {
                totalPoints += (d.data().points || []).length;
            });
            console.log(`📊 Puntos reales en chunks: ${totalPoints}`);

            if (totalPoints === 0 && data.activityType !== 'indoor') {
                console.log("❌ ERROR: No hay puntos de GPS pero el tipo no es 'indoor'.");
            }
        }

        // Simulación de territorios si hay puntos
        if (data.activityType !== 'indoor') {
            console.log("🧪 Simulación de territorios...");
            // Aquí podríamos añadir lógica de simulación más pesada si fuera necesario
        }

        // Check de errores conocidos
        if (data.error) {
            console.log(`❌ ERROR REGISTRADO: ${JSON.stringify(data.error)}`);
        }
    }
}

analyzeUser(userId).catch(console.error);
