const admin = require('firebase-admin');
const serviceAccount = require('./secrets/serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const TARGET_USER_ID = 'CVZ34x99UuU6fCrOEc8Wg5nPYX82';

async function cleanupLast3Workouts() {
    console.log(`Starting cleanup for user: ${TARGET_USER_ID}`);

    try {
        // 1. Get last 3 activities
        const activitiesSnapshot = await db.collection('activities')
            .where('userId', '==', TARGET_USER_ID)
            .orderBy('startDate', 'desc')
            .limit(3)
            .get();

        if (activitiesSnapshot.empty) {
            console.log('No activities found for this user.');
            return;
        }

        console.log(`Found ${activitiesSnapshot.size} activities to process.`);

        // Calculate total XP to revert
        let totalXPToRevert = 0;
        const activityIds = [];
        const activitiesData = [];

        activitiesSnapshot.forEach(doc => {
            const data = doc.data();
            const xpBreakdown = data.xpBreakdown || {};

            const xpBase = xpBreakdown.xpBase || 0;
            const xpTerritory = xpBreakdown.xpTerritory || 0;
            const xpStreak = xpBreakdown.xpStreak || 0;
            const xpWeeklyRecord = xpBreakdown.xpWeeklyRecord || 0;
            const xpBadges = xpBreakdown.xpBadges || 0;

            const activityTotalXP = xpBase + xpTerritory + xpStreak + xpWeeklyRecord + xpBadges;

            totalXPToRevert += activityTotalXP;
            activityIds.push(doc.id);
            activitiesData.push({ id: doc.id, xp: activityTotalXP, date: data.startDate.toDate() });

            console.log(`- Activity ${doc.id} (${data.startDate.toDate().toISOString()}): ${activityTotalXP} XP`);
        });

        console.log(`Total XP to revert: ${totalXPToRevert}`);

        // 2. Find related feed items
        // Firestore 'in' query supports up to 10 items, which is fine for 3 activities
        let feedSnapshot;
        if (activityIds.length > 0) {
            feedSnapshot = await db.collection('feed')
                .where('activityId', 'in', activityIds)
                .get();
            console.log(`Found ${feedSnapshot.size} feed items to delete.`);
        } else {
            feedSnapshot = { empty: true, docs: [] };
        }

        // 3. Perform updates in a Batch
        const batch = db.batch();

        // Delete activities
        activitiesSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        // Delete feed items
        if (!feedSnapshot.empty) {
            feedSnapshot.docs.forEach(doc => {
                batch.delete(doc.ref);
            });
        }

        // Update User XP
        const userRef = db.collection('users').doc(TARGET_USER_ID);
        batch.update(userRef, {
            xp: admin.firestore.FieldValue.increment(-totalXPToRevert)
        });

        // Commit
        await batch.commit();
        console.log('Successfully executed batch delete and XP update.');

        // 4. (Optional) Recursive delete of subcollections for these activities
        // This requires firebase-tools or recursion. For 3 docs, we can try to list subcollections if we want to be thorough,
        // but standard Admin SDK doesn't do recursive delete easily client-side without a helper.
        // Given the prompt asked for a script, we will do a best-effort subcollection cleanup if we can,
        // but the main data is top-level.
        // 'activities/{id}/routes' and 'activities/{id}/territories'

        console.log('Cleaning up subcollections (routes, territories)...');
        for (const activityId of activityIds) {
            const activityRef = db.collection('activities').doc(activityId);

            // Delete routes
            const routes = await activityRef.collection('routes').listDocuments();
            for (const routeDoc of routes) {
                await routeDoc.delete();
            }

            // Delete territories
            const territories = await activityRef.collection('territories').listDocuments();
            for (const territoryDoc of territories) {
                await territoryDoc.delete();
            }
            console.log(`Subcollections cleaned for ${activityId}`);
        }

        console.log('Cleanup complete.');

    } catch (error) {
        console.error('Error during cleanup:', error);
    }
}

cleanupLast3Workouts();
