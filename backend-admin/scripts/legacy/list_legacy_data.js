const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = getFirestore('adventure-streak-pre');
const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
const cutoffDate = new Date('2025-12-01T00:00:00Z');

async function listLegacyData() {
    console.log(`--- Buscando datos legacy (< ${cutoffDate.toISOString()}) para el usuario: ${userId} ---`);

    // 1. Actividades Legacy
    const activitiesSnapshot = await db.collection('activities')
        .where('userId', '==', userId)
        .get();

    let legacyActivities = [];
    activitiesSnapshot.forEach(doc => {
        const data = doc.data();
        const date = data.startDate.toDate();
        if (date < cutoffDate) {
            const xp = data.xpBreakdown ? (data.xpBreakdown.totalXP || 0) : (data.xpEarned || data.xp || 0);
            legacyActivities.push({
                id: doc.id,
                date: date,
                xp: xp
            });
        }
    });

    console.log(`\n--- Actividades Legacy Encontradas: ${legacyActivities.length} ---`);
    legacyActivities.sort((a, b) => b.date - a.date).forEach(a => {
        console.log(`- [${a.date.toISOString()}] ID: ${a.id} | XP: ${a.xp}`);
    });

    // 2. Feed Legacy
    const feedSnapshot = await db.collection('feed')
        .where('userId', '==', userId)
        .get();

    let legacyFeed = [];
    feedSnapshot.forEach(doc => {
        const data = doc.data();
        const date = data.date.toDate();
        if (date < cutoffDate) {
            legacyFeed.push({
                id: doc.id,
                date: date
            });
        }
    });

    console.log(`\n--- Elementos de Feed Legacy Encontrados: ${legacyFeed.length} ---`);

    const totalLegacyXP = legacyActivities.reduce((sum, a) => sum + a.xp, 0);
    console.log(`\nTOTAL XP A REVERTIR: ${totalLegacyXP}`);
    console.log(`TOTAL ACTIVIDADES A BORRAR: ${legacyActivities.length}`);
    console.log(`TOTAL FEED A BORRAR: ${legacyFeed.length}`);

    process.exit(0);
}

listLegacyData().catch(err => {
    console.error('Error al listar datos legacy:', err);
    process.exit(1);
});
