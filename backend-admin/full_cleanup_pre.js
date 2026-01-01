const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = getFirestore('adventure-streak-pre');
const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';
const legacyIds = [
    'AB1E9C16-8767-416D-A7F3-061CE84E568B',
    'A68DDB9B-50B8-4226-ADED-57260CB37555',
    'B2C51686-0A35-4E42-A822-3921B0E839C8',
    'EA4E2C43-2D17-4A5A-B972-E4ACE0B4E6E5',
    '91301775-5C1D-4226-B720-06D931B16C68',
    'DACB5FBA-B63C-43C2-A700-731AFC1DF84F',
    '35C6E952-3F40-4912-BFE0-904166196308'
];

async function fullCleanup() {
    console.log(`--- Iniciando limpieza profunda para usuario: ${userId} ---`);

    // 1. Borrar Actividades Legacy
    for (const id of legacyIds) {
        await db.collection('activities').doc(id).delete();
        console.log(`🗑️ Actividad borrada: ${id}`);
    }

    // 2. Borrar Feed Legacy (basado en el userId y fecha < 01-Dic)
    const cutoffDate = new Date('2025-12-01T00:00:00Z');
    const feedSnapshot = await db.collection('feed')
        .where('userId', '==', userId)
        .get();

    let feedDeleted = 0;
    for (const doc of feedSnapshot.docs) {
        const date = doc.data().date.toDate();
        if (date < cutoffDate) {
            await doc.ref.delete();
            feedDeleted++;
        }
    }
    console.log(`🗑️ Elementos de Feed borrados: ${feedDeleted}`);

    // 3. Resetear Flag de Usuario
    await db.collection('users').doc(userId).update({
        hasAcknowledgedDecReset: false
    });
    console.log('🔄 Flag hasAcknowledgedDecReset reseteado a false.');

    console.log('\n--- LIMPIEZA COMPLETADA ---');
    process.exit(0);
}

fullCleanup().catch(err => {
    console.error('Error durante la limpieza:', err);
    process.exit(1);
});
