const admin = require('firebase-admin');
const fs = require('fs');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const userId = 'DQN1tyypsEZouksWzmFeSIYip7b2'; // Usuario PRE

if (!admin.apps.length) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = getFirestore('adventure-streak-pre');

async function simulateDefense() {
    console.log('--- Iniciando Simulación de Defensa ---');

    // 1. Crear documento de actividad
    const activityId = 'SIM_DEFENSE_' + Date.now();
    const activityRef = db.collection('activities').doc(activityId);

    const activityData = {
        userId: userId,
        userName: 'Usuario PRE (Simulado)',
        activityType: 'walking',
        startDate: admin.firestore.Timestamp.now(),
        endDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000)), // 10 min después
        distanceMeters: 500,
        durationSeconds: 600,
        processingStatus: 'created', // Inicial
        locationLabel: 'IFEMA Madrid (Simulado)',
        createdAt: admin.firestore.Timestamp.now()
    };

    await activityRef.set(activityData);
    console.log('✅ Actividad creada:', activityId);

    // 2. Añadir ruta (puntos sobre IFEMA)
    // Celda -1809_20235 está en 40.471, -3.617
    const routeRef = activityRef.collection('routes').doc('chunk_0');
    await routeRef.set({
        order: 0,
        points: [
            { latitude: 40.471, longitude: -3.617, timestamp: new Date() },
            { latitude: 40.4711, longitude: -3.6171, timestamp: new Date() }
        ]
    });
    console.log('✅ Puntos de ruta añadidos.');

    // 3. Disparar procesamiento
    console.log('🚀 Disparando procesamiento...');
    await activityRef.update({ processingStatus: 'pending' });

    console.log('--- Simulación enviada ---');
    console.log('Espera unos segundos a que la Cloud Function procese el entreno y revisa el Feed en la App.');
    process.exit(0);
}

simulateDefense().catch(console.error);
