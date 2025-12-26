const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.resolve(__dirname, '../secrets/serviceAccount.json');
const serviceAccount = require(serviceAccountPath);

const { getFirestore } = require('firebase-admin/firestore');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = getFirestore(admin.app(), 'adventure-streak-pre');

async function checkToken() {
    const userId = 'DQN1tyypsEZouksWzmFeSIYip7b2';
    console.log(`Checking token for user: ${userId}`);

    const doc = await db.collection('users').doc(userId).get();
    if (!doc.exists) {
        console.log('User does not exist!');
    } else {
        const data = doc.data();
        console.log('User Found.');
        console.log('FCM Tokens:', data.fcmTokens);
    }
}

checkToken().catch(console.error);
