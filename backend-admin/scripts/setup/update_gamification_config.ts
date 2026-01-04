
import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

// Initialize Firebase Admin
const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';

if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    }
} else {
    console.error("❌ Service account not found at:", serviceAccountPath);
    process.exit(1);
}

const newConfig = {
    // Existing values (keeping them to avoid overwriting with defaults)
    minDistanceKm: 0.5,
    minDurationSeconds: 300,
    baseFactorPerKm: 10.0,
    factorRun: 1.2,
    factorBike: 0.7,
    factorWalk: 0.9,
    factorOther: 1.0,
    factorIndoor: 0.5,
    indoorXPPerMinute: 3.0,
    dailyBaseXPCap: 300,
    xpPerNewCell: 8,
    xpPerDefendedCell: 3,
    xpPerRecapturedCell: 12,
    xpPerStolenCell: 20,
    maxNewCellsXPPerActivity: 50,
    baseStreakXPPerWeek: 10,
    weeklyRecordBaseXP: 30,
    weeklyRecordPerKmDiffXP: 5,
    minWeeklyRecordKm: 5.0,
    legendaryThresholdCells: 20,
    lastMinuteDefenseBonus: 2,
    vengeanceXPReward: 25,

    // NEW HARDENED & LOOT VALUES
    xpLootPerDay: 2.0,
    xpConsolidation15DayBonus: 5,
    xpConsolidation25DayBonus: 8,
    xpStreakInterruptionBonus: 15,

    metadata: {
        minDistanceKm: "Distancia mínima requerida para procesar XP base (en km).",
        minDurationSeconds: "Duración mínima requerida para procesar XP (en segundos).",
        baseFactorPerKm: "Puntos de XP base por cada kilómetro recorrido.",
        factorRun: "Multiplicador para actividades de carrera.",
        factorBike: "Multiplicador para actividades de ciclismo.",
        factorWalk: "Multiplicador para actividades de caminata/senderismo.",
        factorOther: "Multiplicador para otras actividades al aire libre.",
        factorIndoor: "Multiplicador para actividades en interiores con distancia.",
        indoorXPPerMinute: "XP por cada minuto en actividades de interior (sin distancia).",
        dailyBaseXPCap: "Límite máximo diario de XP base.",
        xpPerNewCell: "XP por cada nueva celda conquistada.",
        xpPerDefendedCell: "XP por defender una celda propia.",
        xpPerRecapturedCell: "XP por recuperar una celda propia que había expirado.",
        xpPerStolenCell: "XP por robar una celda activa a otro usuario.",
        maxNewCellsXPPerActivity: "Máximo de celdas nuevas que otorgan XP por actividad.",
        baseStreakXPPerWeek: "XP base por cada semana de racha activa.",
        weeklyRecordBaseXP: "Bono base por superar el récord semanal de distancia.",
        weeklyRecordPerKmDiffXP: "XP adicional por cada km que supere el récord anterior.",
        minWeeklyRecordKm: "Kilómetros mínimos necesarios para activar récords semanales.",
        legendaryThresholdCells: "Celdas mínimas para considerar una misión territorial como legendaria.",
        lastMinuteDefenseBonus: "Bono adicional por defender una celda cerca de expirar.",
        vengeanceXPReward: "XP otorgado al completar una misión de venganza (Vengeance Target).",

        // NEW METADATA
        xpLootPerDay: "XP que acumula una celda por día de control para el dueño (saqueable por un rival).",
        xpConsolidation15DayBonus: "XP extra por defender una celda con más de 15 días de control continuo.",
        xpConsolidation25DayBonus: "XP extra por defender una celda con más de 25 días de control continuo.",
        xpStreakInterruptionBonus: "XP extra por robar una celda a un usuario con racha semanal activa."
    }
};

async function updateConfig(databaseId: string) {
    try {
        const db = databaseId === '(default)' ? getFirestore() : getFirestore(databaseId);

        // Fetch current config to merge metadata (safety measure)
        const docRef = db.collection('config').doc('gamification');
        const snap = await docRef.get();
        const currentData = snap.exists ? snap.data() : {};

        const finalConfig = {
            ...currentData,
            ...newConfig,
            metadata: {
                ...currentData?.metadata,
                ...newConfig.metadata
            }
        };

        await docRef.set(finalConfig);
        console.log(`✅ [${databaseId}] Gamification configuration updated successfully!`);
    } catch (e) {
        console.error(`❌ [${databaseId}] Error updating Firestore configuration:`, e);
    }
}

async function run() {
    const databaseId = process.argv[2] || 'adventure-streak-pre';
    console.log(`🚀 Updating GAMIFICATION CONFIG for ${databaseId}...`);
    await updateConfig(databaseId);
}

run().then(() => process.exit(0)).catch(err => {
    console.error(err);
    process.exit(1);
});
