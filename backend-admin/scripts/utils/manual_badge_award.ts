
import admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import { FieldValue } from "firebase-admin/firestore";

// --- CONFIGURATION ---
const SERVICE_ACCOUNT_PATH = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const DB_URL = "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app";
const USER_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82";

// --- INITIALIZATION ---
if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(`❌ Service account not found at: ${SERVICE_ACCOUNT_PATH}`);
    process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(SERVICE_ACCOUNT_PATH, 'utf8'));

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: DB_URL
    });
}
const db = admin.firestore();
db.settings({ databaseId: 'adventure-streak-pre' });

// ==========================================
// SECTION: XP TYPES & CONFIG
// ==========================================

export interface XPConfigData {
    minDistanceKm: number;
    minDurationSeconds: number;
    baseFactorPerKm: number;
    factorRun: number;
    factorBike: number;
    factorWalk: number;
    factorOther: number;
    factorIndoor: number;
    indoorXPPerMinute: number;
    dailyBaseXPCap: number;
    xpPerNewCell: number;
    xpPerDefendedCell: number;
    xpPerRecapturedCell: number;
    xpPerStolenCell: number;
    maxNewCellsXPPerActivity: number;
    baseStreakXPPerWeek: number;
    weeklyRecordBaseXP: number;
    weeklyRecordPerKmDiffXP: number;
    minWeeklyRecordKm: number;
    legendaryThresholdCells: number;
}

export interface XPBreakdown {
    xpBase: number;
    xpTerritory: number;
    xpStreak: number;
    xpWeeklyRecord: number;
    xpBadges: number;
    total: number;
}

export interface XPContext {
    userId: string;
    currentWeekDistanceKm: number;
    bestWeeklyDistanceKm: number | null;
    currentStreakWeeks: number;
    todayBaseXPEarned: number;
    gamificationState: GamificationState;
}

export interface GamificationState {
    totalXP: number;
    level: number;
    currentStreakWeeks: number;
}

export interface TerritoryStats {
    newCellsCount: number;
    defendedCellsCount: number;
    recapturedCellsCount: number;
    stolenCellsCount: number;
    lastMinuteDefenseCount: number;
}


// ==========================================
// SECTION: BADGE DEFINITIONS & SERVICE
// ==========================================

export type BadgeCategory = "aggressive" | "social" | "training";

export interface BadgeDefinition {
    id: string;
    category: BadgeCategory;
    name: string;
    description: string;
    icon: string; // Emoji key or asset name
}

export const BADGES: BadgeDefinition[] = [
    // --- 1. Aggressive (Territorial) ---
    { id: "shadow_hunter", category: "aggressive", name: "Cazador de Sombras", description: "Robar 5 celdas a un mismo usuario en una sola actividad", icon: "🥷" },
    { id: "chaos_lord", category: "aggressive", name: "Señor del Caos", description: "Robar territorios a 3 usuarios diferentes en un mismo día", icon: "😈" },
    { id: "human_boomerang", category: "aggressive", name: "Búmeran Humano", description: "Reconquistar una celda menos de 1 hora después de haberla perdido", icon: "🪃" },
    { id: "invader_silent", category: "aggressive", name: "Invasor Silencioso", description: "Conquistar 10 celdas de usuarios de nivel superior", icon: "🤫" },
    { id: "takeover", category: "aggressive", name: "Toma de Posesión", description: "Robar una celda defendida hace menos de 24 horas", icon: "🏰" },
    { id: "reconquest_king", category: "aggressive", name: "Rey de la Reconquista", description: "Acumular 100 XP solo reconquistando", icon: "👑" },
    { id: "uninvited", category: "aggressive", name: "Sin Invitación", description: "Robar un territorio en una actividad de >10km", icon: "🚪" },
    { id: "streak_breaker", category: "aggressive", name: "Interrupción de Racha", description: "Robar a un usuario con racha > 4 semanas", icon: "💔" },
    { id: "white_glove", category: "aggressive", name: "Ladrón de Guante Blanco", description: "Robar una celda épica (>30 días)", icon: "🧤" },
    { id: "lightning_counter", category: "aggressive", name: "Contraataque Relámpago", description: "Recuperar territorio perdido inmediatamente", icon: "⚡" },
    { id: "summit_looter", category: "aggressive", name: "Saqueador de Cumbres", description: "Robar en actividad con >200m desnivel", icon: "🏔️" },
    { id: "steel_influencer", category: "social", name: "Influencer de Acero", description: "Recibir 50 reacciones en un post", icon: "📸" },
    { id: "war_correspondent", category: "social", name: "Corresponsal de Guerra", description: "Publicar actividad con 3 robos", icon: "📰" },
    { id: "sports_spirit", category: "social", name: "Espíritu Deportivo", description: "Reaccionar a 10 actividades de rivales", icon: "🤝" },
    { id: "community_voice", category: "social", name: "Voz de la Comunidad", description: "Ser el primero en reaccionar a 20 actividades", icon: "🗣️" },
    { id: "trust_circle", category: "social", name: "Círculo de Confianza", description: "Seguir a 5 usuarios que te sigan", icon: "⭕" },
    { id: "xp_machine", category: "training", name: "Máquina de XP", description: "Cap de 300 XP base 3 días seguidos", icon: "🤖" },
    { id: "early_bird", category: "training", name: "Madrugador", description: "Entrenamiento >5km antes de las 7:00 AM", icon: "🌅" },
    { id: "iron_stamina", category: "training", name: "Resistencia de Hierro", description: "Indoor > 90 minutos", icon: "🏋️" },
    { id: "elite_sprinter", category: "training", name: "Velocista de Élite", description: "Ritmo < 4:30 min/km en 5km", icon: "🐆" },
    { id: "km_eater", category: "training", name: "Devora Kilómetros", description: "Superar récord semanal por >10km", icon: "🍽️" },
    { id: "pure_consistency", category: "training", name: "Constancia Pura", description: "Racha activa de 12 semanas", icon: "📅" },
    { id: "triathlete", category: "training", name: "Triatleta en Ciernes", description: "Registrar Carrera, Ciclismo y Otros en una semana", icon: "🏊" },
    { id: "max_efficiency", category: "training", name: "Eficiencia Máxima", description: "Ganar >500 XP en una actividad", icon: "⚡" },
    { id: "deep_explorer", category: "training", name: "Explorador de Fondo", description: "Conquistar 30 celdas nuevas en >15km", icon: "🧭" },
    { id: "level_10_express", category: "training", name: "Nivel 10 Express", description: "Nivel 10 en <30 días", icon: "🚀" }
];

export class BadgeService {

    static async checkActivityBadges(
        db: admin.firestore.Firestore,
        userId: string,
        activity: any,
        stats: TerritoryStats,
        context: XPContext,
        xpBreakdown: any,
        victimSteals: Map<string, number>,
        existingRemotes: Map<string, any>,
        traversedCells: Map<string, any>
    ): Promise<string[]> {
        const unlockedBadges: string[] = [];

        const userRef = db.collection("users").doc(userId);
        const userDoc = await userRef.get();
        const userData = userDoc.data() || {};
        const existingBadges = new Set(userData.badges || []);

        const earn = (badgeId: string) => {
            if (!existingBadges.has(badgeId)) {
                unlockedBadges.push(badgeId);
                existingBadges.add(badgeId);
                console.log(`🎉 Awarded Badge: ${badgeId}`);
            } else {
                // console.log(`ℹ️ Badge already owned: ${badgeId}`);
            }
        };

        const now = new Date();
        const distanceKm = (activity.distanceMeters || 0) / 1000;

        // Madrugador: >5km before 7 AM
        const startDate = activity.startDate ? activity.startDate.toDate() : new Date();
        const startHour = startDate.getHours();
        if (distanceKm > 5 && startHour < 7) {
            earn("early_bird");
        }

        // Resistencia de Hierro: Indoor > 90 min
        const durationMin = (activity.durationSeconds || 0) / 60;
        if (activity.activityType === "indoor" && durationMin > 90) {
            earn("iron_stamina");
        }

        // Velocista de Élite: < 4:30 min/km in 5km (Run)
        if (activity.activityType === "run" && distanceKm >= 5) {
            const paceSeconds = (activity.durationSeconds || 0) / distanceKm;
            if (paceSeconds < 270) { // 4:30 = 270s
                earn("elite_sprinter");
            }
        }

        // Persist new badges
        if (unlockedBadges.length > 0) {
            await userRef.update({
                badges: FieldValue.arrayUnion(...unlockedBadges),
            });

            // Send Notifications
            for (const badgeId of unlockedBadges) {
                const badgeDef = BADGES.find(b => b.id === badgeId);
                if (badgeDef) {
                    await db.collection("notifications").add({
                        recipientId: userId,
                        type: "achievement",
                        badgeId: badgeId,
                        senderId: "system",
                        senderName: "Adventure Streak",
                        timestamp: FieldValue.serverTimestamp(),
                        isRead: false,
                        message: `¡Has ganado la insignia ${badgeDef.name}!`
                    });
                }
            }
            console.log("💾 Unlocked badges persisted to DB.");
        } else {
            console.log("⏹ No new badges unlocked in this run.");
        }

        return unlockedBadges;
    }
}

// ==========================================
// SECTION: EXECUTION
// ==========================================

async function runSimulation() {
    console.log(`🚀 Running Standalone Badge Simulation for User: ${USER_ID}`);

    // MOCK DATA
    const mockTerritoryStats: TerritoryStats = {
        newCellsCount: 0,
        defendedCellsCount: 0,
        recapturedCellsCount: 0,
        stolenCellsCount: 0,
        lastMinuteDefenseCount: 0
    };

    const mockXPContext: XPContext = {
        userId: USER_ID,
        currentWeekDistanceKm: 10,
        bestWeeklyDistanceKm: 20,
        currentStreakWeeks: 5,
        todayBaseXPEarned: 0,
        gamificationState: { totalXP: 1000, level: 5, currentStreakWeeks: 5 }
    };

    const mockXPBreakdown: XPBreakdown = {
        xpBase: 100, xpTerritory: 0, xpStreak: 0, xpWeeklyRecord: 0, xpBadges: 0, total: 100
    };

    // --- SCENARIO 1: Early Bird ---
    console.log("👉 Simulating 'Early Bird' (Run, 6:15 AM)...");
    const earlyBirdDate = new Date();
    earlyBirdDate.setHours(6, 15, 0, 0); // Today 6:15 AM

    await BadgeService.checkActivityBadges(
        db,
        USER_ID,
        {
            activityType: 'run',
            distanceMeters: 6000,
            startDate: admin.firestore.Timestamp.fromDate(earlyBirdDate),
            durationSeconds: 1800
        },
        mockTerritoryStats,
        mockXPContext,
        mockXPBreakdown,
        new Map(), // victimSteals
        new Map(), // existingRemotes
        new Map()  // traversedCells
    );

    // --- SCENARIO 2: Iron Stamina ---
    console.log("👉 Simulating 'Iron Stamina' (Indoor, 100 min)...");
    await BadgeService.checkActivityBadges(
        db,
        USER_ID,
        {
            activityType: 'indoor',
            distanceMeters: 0,
            startDate: admin.firestore.Timestamp.now(),
            durationSeconds: 100 * 60 // 100 min
        },
        mockTerritoryStats,
        mockXPContext,
        mockXPBreakdown,
        new Map(),
        new Map(),
        new Map()
    );

    // --- SCENARIO 3: Elite Sprinter ---
    console.log("👉 Simulating 'Elite Sprinter' (Run, 5km, 4:00/km)...");
    // Pace 4:00/km = 240 sec/km. 5km = 1200 sec (20 min).
    await BadgeService.checkActivityBadges(
        db,
        USER_ID,
        {
            activityType: 'run',
            distanceMeters: 5000,
            startDate: admin.firestore.Timestamp.now(),
            durationSeconds: 20 * 60 // 20 min
        },
        mockTerritoryStats,
        mockXPContext,
        mockXPBreakdown,
        new Map(),
        new Map(),
        new Map()
    );

    console.log("✅ Simulation Complete.");
}

runSimulation();
