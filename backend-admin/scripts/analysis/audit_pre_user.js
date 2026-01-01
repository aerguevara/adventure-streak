const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = getFirestore('adventure-streak-pre');
const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function auditUser() {
    console.log(`--- Auditoría para usuario: ${userId} ---`);

    // 1. Datos Básicos (XP, Nivel, Reset Flag)
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
        console.log('Error: El usuario no existe en PRE.');
        return;
    }
    const userData = userDoc.data();
    console.log('--- Perfil ---');
    console.log(`XP: ${userData.xp}`);
    console.log(`Nivel: ${userData.level}`);
    console.log(`¿Reset Aceptado?: ${userData.hasAcknowledgedDecReset || false}`);

    // 2. Conteo de Actividades
    const activitiesSnapshot = await db.collection('activities')
        .where('userId', '==', userId)
        .get();
    console.log('\n--- Actividades ---');
    console.log(`Total: ${activitiesSnapshot.size}`);

    // 3. Conteo de Feed
    const feedSnapshot = await db.collection('feed')
        .where('userId', '==', userId)
        .get();
    console.log('\n--- Feed ---');
    console.log(`Total: ${feedSnapshot.size}`);

    process.exit(0);
}

auditUser().catch(err => {
    console.error('Error durante la auditoría:', err);
    process.exit(1);
});
