const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = getFirestore('adventure-streak-pre');
const legacyIds = [
    'AB1E9C16-8767-416D-A7F3-061CE84E568B',
    'A68DDB9B-50B8-4226-ADED-57260CB37555',
    'B2C51686-0A35-4E42-A822-3921B0E839C8',
    'EA4E2C43-2D17-4A5A-B972-E4ACE0B4E6E5',
    '91301775-5C1D-4226-B720-06D931B16C68',
    'DACB5FBA-B63C-43C2-A700-731AFC1DF84F',
    '35C6E952-3F40-4912-BFE0-904166196308'
];

async function inspectLegacy() {
    for (const id of legacyIds) {
        const doc = await db.collection('activities').doc(id).get();
        if (doc.exists) {
            console.log(`\nDoc ID: ${id}`);
            const data = doc.data();
            console.log('Fields:', Object.keys(data));
            console.log('xpEarned:', data.xpEarned);
            if (data.xpBreakdown) console.log('xpBreakdown.totalXP:', data.xpBreakdown.totalXP);
        }
    }
    process.exit(0);
}

inspectLegacy();
