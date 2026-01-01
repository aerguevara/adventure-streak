const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const TARGET_USER_ID = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function cleanupNov30Workout() {
    console.log(`🔍 Searching for Nov 30th workouts for user: ${TARGET_USER_ID}`);

    try {
        // Range for Nov 30, 2025
        const startOfNov30 = new Date('2025-11-30T00:00:00Z');
        const endOfNov30 = new Date('2025-11-30T23:59:59Z');

        const activitiesSnapshot = await db.collection('activities')
            .where('userId', '==', TARGET_USER_ID)
            .get();

        const filteredActivities = activitiesSnapshot.docs.filter(doc => {
            const startDate = doc.data().startDate.toDate();
            return startDate >= startOfNov30 && startDate <= endOfNov30;
        });

        if (filteredActivities.length === 0) {
            console.log('❌ No activities found for Nov 30th.');
            return;
        }

        console.log(`✅ Found ${filteredActivities.length} activities to delete.`);

        let totalXPToRevert = 0;
        const activityIds = [];

        filteredActivities.forEach(doc => {
            const data = doc.data();
            const xpBreakdown = data.xpBreakdown || {};
            const activityTotalXP = xpBreakdown.total || 0;

            totalXPToRevert += activityTotalXP;
            activityIds.push(doc.id);

            console.log(`- Activity ${doc.id} (${data.startDate.toDate().toISOString()}): ${activityTotalXP} XP`);
        });

        console.log(`💰 Total XP to revert: ${totalXPToRevert}`);

        // Find related feed items
        const feedSnapshot = await db.collection('feed')
            .where('activityId', 'in', activityIds)
            .get();
        console.log(`📰 Found ${feedSnapshot.size} feed items to delete.`);

        const batch = db.batch();

        // Delete activities
        activitiesSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        // Delete feed items
        feedSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        // Update User XP
        const userRef = db.collection('users').doc(TARGET_USER_ID);
        batch.update(userRef, {
            xp: admin.firestore.FieldValue.increment(-totalXPToRevert)
        });

        await batch.commit();
        console.log('🚀 Batch delete and XP update committed.');

        // Clean up subcollections
        for (const activityId of activityIds) {
            const activityRef = db.collection('activities').doc(activityId);
            const subcollections = ['routes', 'territories'];

            for (const sub of subcollections) {
                const docs = await activityRef.collection(sub).listDocuments();
                for (const subDoc of docs) {
                    await subDoc.delete();
                }
                if (docs.length > 0) console.log(`   - Deleted ${docs.length} docs from subcollection ${sub} for ${activityId}`);
            }
        }

        console.log('🎉 Cleanup of Nov 30th workout complete.');

    } catch (error) {
        console.error('💥 Error during cleanup:', error);
    }
}

cleanupNov30Workout();
