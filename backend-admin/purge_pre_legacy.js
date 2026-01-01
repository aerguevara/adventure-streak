const admin = require('firebase-admin');

const serviceAccount = require('/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json');

const { getFirestore } = require('firebase-admin/firestore');

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'adventure-streak'
    });
}

async function purgeLegacy() {
    const firestore = getFirestore('adventure-streak-pre');
    const userId = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

    // Lista de IDs a purgar (Noviembre)
    const targetActivityIds = [
        '35C6E952-3F40-4912-BFE0-904166196308',
        '91301775-5C1D-4226-B720-06D931B16C68',
        'DACB5FBA-B63C-43C2-A700-731AFC1DF84F',
        'EA4E2C43-2D17-4A5A-B972-E4ACE0B4E6E5',
        'A68DDB9B-50B8-4226-ADED-57260CB37555',
        'B2C51686-0A35-4E42-A822-3921B0E839C8',
        'AB1E9C16-8767-416D-A7F3-061CE84E568B',
        '50704C62-EFB7-4BDC-8782-AB087C546273',
        '7E7E4B83-AB87-48EB-BA2E-BD0F4B4778CC'
    ];

    console.log(`🚀 Iniciando purga de ${targetActivityIds.length} actividades legacy en PRE...`);

    for (const id of targetActivityIds) {
        // 1. Borrar Actividad
        console.log(`   🗑️ Borrando actividad: ${id}`);
        await firestore.collection('activities').doc(id).delete();

        // 2. Borrar del Feed (si existe)
        const feedDocs = await firestore.collection('feed')
            .where('userId', '==', userId)
            .where('activityId', '==', id)
            .get();

        if (!feedDocs.empty) {
            console.log(`      ✨ Borrando ${feedDocs.size} entradas de feed para esta actividad.`);
            for (const doc of feedDocs.docs) {
                await doc.ref.delete();
            }
        }
    }

    console.log('🏁 Purga completada. PRE está limpio de Noviembre.');
}

purgeLegacy().catch(console.error);
