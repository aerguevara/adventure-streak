import * as admin from 'firebase-admin';
import * as path from 'path';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// Initialize Firebase Admin
const serviceAccountPath = path.resolve(__dirname, '../../secrets/serviceAccount.json');

// Initialize with specific project ID to avoid ambiguity
admin.initializeApp({
    credential: admin.credential.cert(require(serviceAccountPath)),
    projectId: "adventure-streak"
});

async function migrateUser(oldUid: string, newUid: string, databaseId: string = '(default)') {
    if (!oldUid || !newUid) {
        console.error('Usage: ts-node migrate_user_uid.ts --oldUid=<OLD_UID> --newUid=<NEW_UID> [--db=<DATABASE_ID>]');
        process.exit(1);
    }

    if (oldUid === newUid) {
        console.error('Old UID and New UID cannot be the same.');
        process.exit(1);
    }

    const db = getFirestore(databaseId);
    console.log(`Starting COMPLETE migration from ${oldUid} to ${newUid} in database: ${databaseId}`);

    try {
        // A. Pre-fetch Data needed for Cross-Ref Updates (Before Profile Deletion)
        console.log(`Reading old user profile for lists...`);
        const oldUserRef = db.collection('users').doc(oldUid);
        const oldUserSnap = await oldUserRef.get();

        if (!oldUserSnap.exists) {
            console.error(`User document ${oldUid} does not exist. Cannot proceed seamlessly.`);
            process.exit(1);
        }

        const oldUserData = oldUserSnap.data() || {};
        const recentTheftVictims = oldUserData.recentTheftVictims || []; // I stole from them -> They have me in recentThieves
        const recentThieves = oldUserData.recentThieves || []; // They stole from me -> They have me in recentTheftVictims

        // 1. Migrate User Profile
        const newUserRef = db.collection('users').doc(newUid);
        console.log(`Migrating user profile...`);

        // Copy user data
        await newUserRef.set({
            ...oldUserData,
            uid: newUid,
            migratedFrom: oldUid,
            migratedAt: FieldValue.serverTimestamp()
        }, { merge: true });

        // Migrate Subcollections & Handle Reciprocal Follows
        const subcollections = await oldUserRef.listCollections();
        for (const subcol of subcollections) {
            console.log(`  Migrating subcollection: ${subcol.id}`);
            const docs = await subcol.get();
            for (const doc of docs.docs) {
                const newDocRef = newUserRef.collection(subcol.id).doc(doc.id);
                await newDocRef.set(doc.data());

                // --- RECIPROCAL UPDATES ---
                if (subcol.id === 'followers') {
                    // doc.id is the FOLLOWER'S ID. 
                    // We must go to users/{followerId}/following/{oldUid} and move it to .../following/{newUid}
                    const followerId = doc.id;
                    const theirFollowingRefOld = db.collection('users').doc(followerId).collection('following').doc(oldUid);
                    const theirFollowingRefNew = db.collection('users').doc(followerId).collection('following').doc(newUid);

                    const tfSnap = await theirFollowingRefOld.get();
                    if (tfSnap.exists) {
                        await theirFollowingRefNew.set(tfSnap.data()!);
                        await theirFollowingRefOld.delete();
                    }
                }

                if (subcol.id === 'following') {
                    // doc.id is the ID of user I AM FOLLOWING.
                    // We must go to users/{followingId}/followers/{oldUid} and move it to .../followers/{newUid}
                    const followingId = doc.id;
                    const theirFollowerRefOld = db.collection('users').doc(followingId).collection('followers').doc(oldUid);
                    const theirFollowerRefNew = db.collection('users').doc(followingId).collection('followers').doc(newUid);

                    const tfSnap = await theirFollowerRefOld.get();
                    if (tfSnap.exists) {
                        await theirFollowerRefNew.set(tfSnap.data()!);
                        await theirFollowerRefOld.delete();
                    }
                }
            }
        }

        // 2. Update 'activities' AND embedded 'missions'
        console.log(`Updating 'activities' and embedded 'missions'...`);
        const activitiesQuery = await db.collection('activities').where('userId', '==', oldUid).get();
        let batch = db.batch();
        let count = 0;

        for (const doc of activitiesQuery.docs) {
            const data = doc.data();
            let updateData: any = { userId: newUid };

            // Check Missions
            if (data.missions && Array.isArray(data.missions)) {
                const updatedMissions = data.missions.map((m: any) => {
                    if (m.userId === oldUid) {
                        return { ...m, userId: newUid };
                    }
                    return m;
                });
                updateData.missions = updatedMissions;
            }

            batch.update(doc.ref, updateData);
            count++;
            if (count >= 400) {
                await batch.commit();
                batch = db.batch();
                count = 0;
            }
        }
        if (count > 0) await batch.commit();
        console.log(`  Updated ${activitiesQuery.size} activities.`);

        // 3. Update 'remote_territories' (Ownership)
        console.log(`Updating 'remote_territories' (ownership)...`);
        const terrQuery = await db.collection('remote_territories').where('userId', '==', oldUid).get();
        batch = db.batch();
        count = 0;
        for (const doc of terrQuery.docs) {
            batch.update(doc.ref, { userId: newUid });
            count++;
            if (count >= 400) {
                await batch.commit();
                batch = db.batch();
                count = 0;
            }
        }
        if (count > 0) await batch.commit();
        console.log(`  Updated ${terrQuery.size} territories.`);

        // 4. Update 'feed'
        console.log(`Updating 'feed'...`);
        const feedQuery = await db.collection('feed').where('userId', '==', oldUid).get();
        batch = db.batch();
        count = 0;
        for (const doc of feedQuery.docs) {
            batch.update(doc.ref, { userId: newUid });
            count++;
            if (count >= 400) {
                await batch.commit();
                batch = db.batch();
                count = 0;
            }
        }
        if (count > 0) await batch.commit();
        console.log(`  Updated ${feedQuery.size} feed items.`);

        // 5. Update 'notifications' (Recipient & Sender)
        console.log(`Updating 'notifications'...`);
        const notifRecipientQuery = await db.collection('notifications').where('recipientId', '==', oldUid).get();
        batch = db.batch();
        count = 0;
        for (const doc of notifRecipientQuery.docs) {
            batch.update(doc.ref, { recipientId: newUid });
            count++;
            if (count >= 400) { await batch.commit(); batch = db.batch(); count = 0; }
        }
        if (count > 0) await batch.commit();
        console.log(`  Updated ${notifRecipientQuery.size} notifications (recipient).`);

        const notifSenderQuery = await db.collection('notifications').where('senderId', '==', oldUid).get();
        batch = db.batch();
        count = 0;
        for (const doc of notifSenderQuery.docs) {
            batch.update(doc.ref, { senderId: newUid });
            count++;
            if (count >= 400) { await batch.commit(); batch = db.batch(); count = 0; }
        }
        if (count > 0) await batch.commit();
        console.log(`  Updated ${notifSenderQuery.size} notifications (sender).`);

        // 6. Update 'activity_reactions'
        console.log(`Updating 'activity_reactions'...`);
        const reactionsQuery = await db.collection('activity_reactions').where('reactedUserId', '==', oldUid).get();
        batch = db.batch();
        count = 0;
        for (const doc of reactionsQuery.docs) {
            batch.update(doc.ref, { reactedUserId: newUid });
            count++;
            if (count >= 400) {
                await batch.commit();
                batch = db.batch();
                count = 0;
            }
        }
        if (count > 0) await batch.commit();
        console.log(`  Updated ${reactionsQuery.size} reactions.`);

        // 7. Update 'reserved_icons'
        console.log(`Updating 'reserved_icons'...`);
        const iconsQuery = await db.collection('reserved_icons').where('userId', '==', oldUid).get();
        batch = db.batch();
        count = 0;
        for (const doc of iconsQuery.docs) {
            batch.update(doc.ref, { userId: newUid });
            count++;
            if (count >= 400) {
                await batch.commit();
                batch = db.batch();
                count = 0;
            }
        }
        if (count > 0) await batch.commit();
        console.log(`  Updated ${iconsQuery.size} reserved icons.`);

        // 8. (Previously Vengeance Targets - Removed to avoid index. Moved to 9a)

        // 9. Cross-Update Recent Lists (Thieves & Victims)
        console.log(`Updating Cross-Referenced Lists & Vengeance Targets...`);

        // 9a. Update Victims' "recentThieves" AND their "vengeance_targets"
        // I am 'oldUid'. I appear in 'recentThieves' of people in MY 'recentTheftVictims' list.
        for (const victim of recentTheftVictims) {
            if (!victim.userId) continue;
            const victimRef = db.collection('users').doc(victim.userId);
            const victimDoc = await victimRef.get();
            if (victimDoc.exists) {
                const vData = victimDoc.data() || {};

                // Update recentThieves
                const theirThieves = vData.recentThieves || [];
                let changed = false;
                const updatedThieves = theirThieves.map((t: any) => {
                    if (t.userId === oldUid) {
                        changed = true;
                        return { ...t, userId: newUid };
                    }
                    return t;
                });

                if (changed) {
                    await victimRef.update({ recentThieves: updatedThieves });
                }

                // Update vengeance_targets (Targeted update inside specific user subcollection)
                const vTargetsQuery = await victimRef.collection('vengeance_targets').where('thiefId', '==', oldUid).get();
                if (!vTargetsQuery.empty) {
                    const vBatch = db.batch();
                    vTargetsQuery.docs.forEach(doc => {
                        vBatch.update(doc.ref, { thiefId: newUid });
                    });
                    await vBatch.commit();
                }
            }
        }

        // 9b. Update Thieves' "recentTheftVictims"
        // I am 'oldUid'. I appear in 'recentTheftVictims' of people in MY 'recentThieves' list.
        for (const thief of recentThieves) {
            if (!thief.userId) continue;
            const thiefRef = db.collection('users').doc(thief.userId);
            const thiefDoc = await thiefRef.get();
            if (thiefDoc.exists) {
                const tData = thiefDoc.data() || {};
                const theirVictims = tData.recentTheftVictims || [];
                let changed = false;
                const updatedVictims = theirVictims.map((v: any) => {
                    if (v.userId === oldUid) {
                        changed = true;
                        return { ...v, userId: newUid };
                    }
                    return v;
                });

                if (changed) {
                    await thiefRef.update({ recentTheftVictims: updatedVictims });
                }
            }
        }
        console.log(`  Cross-referenced lists updated.`);


        // 10. Update 'remote_territories/{id}/history' (Manual Scan)
        console.log(`Scanning 'remote_territories' for history migration...`);
        // Using manual scan 
        const allTerritoriesSnap = await db.collection('remote_territories').select().get();

        batch = db.batch();
        count = 0;
        let historyCount = 0;
        let historyPrevCount = 0;

        const CHUNK_SIZE = 50;
        const territoryDocs = allTerritoriesSnap.docs;

        for (let i = 0; i < territoryDocs.length; i += CHUNK_SIZE) {
            const chunk = territoryDocs.slice(i, i + CHUNK_SIZE);
            const promises = chunk.map(async (terrDoc) => {
                const historyRef = terrDoc.ref.collection('history');
                const [userIdSnap, prevOwnerSnap] = await Promise.all([
                    historyRef.where('userId', '==', oldUid).get(),
                    historyRef.where('previousOwnerId', '==', oldUid).get()
                ]);
                return { userIdSnap, prevOwnerSnap };
            });

            const results = await Promise.all(promises);

            for (const res of results) {
                for (const doc of res.userIdSnap.docs) {
                    batch.update(doc.ref, { userId: newUid });
                    count++; historyCount++;
                }
                for (const doc of res.prevOwnerSnap.docs) {
                    batch.update(doc.ref, { previousOwnerId: newUid });
                    count++; historyPrevCount++;
                }
            }

            if (count >= 400) {
                await batch.commit();
                batch = db.batch();
                count = 0;
                process.stdout.write('.');
            }
        }

        if (count > 0) await batch.commit();
        console.log(`\n  Updated ${historyCount} history entries (userId).`);
        console.log(`  Updated ${historyPrevCount} history entries (previousOwnerId).`);


        // 11. Update Ranking/Leaderboard Config
        console.log(`Checking 'config/ranking'...`);
        const rankingRef = db.collection('config').doc('ranking');
        const rankingDoc = await rankingRef.get();
        if (rankingDoc.exists) {
            const rankingData = rankingDoc.data();
            if (rankingData?.userId === oldUid) {
                await rankingRef.update({ userId: newUid });
            }
        }

        // 12. Cleanup Old User Profile
        console.log(`Cleaning up old user profile...`);
        for (const subcol of subcollections) {
            const docs = await subcol.get();
            batch = db.batch();
            count = 0;
            for (const doc of docs.docs) {
                batch.delete(doc.ref);
                count++;
                if (count >= 400) { await batch.commit(); batch = db.batch(); count = 0; }
            }
            if (count > 0) await batch.commit();
        }
        await oldUserRef.delete();
        console.log(`Migration completed successfully!`);

    } catch (error) {
        console.error('Migration failed:', error);
        process.exit(1);
    }
}

// Parse arguments
const args = process.argv.slice(2);
const getArg = (name: string) => {
    const arg = args.find(a => a.startsWith(`--${name}=`));
    return arg ? arg.split('=')[1] : null;
};

const oldUid = getArg('oldUid');
const newUid = getArg('newUid');
const dbId = getArg('db') || '(default)';

migrateUser(oldUid!, newUid!, dbId);
