import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
});

// Allow PRE or PRO argument
const args = process.argv.slice(2);
const envArg = args[0]?.toUpperCase();
const databaseId = envArg === "PRE" ? "adventure-streak-pre" : "(default)";
const db = getFirestore(app, databaseId);

console.log(`🌍 Starting GLOBAL Rivalry Audit on ${databaseId}...`);

async function fixAllRivalries() {
    try {
        const usersSnap = await db.collection('users').get();
        const users = usersSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        const userMap = new Map(users.map(u => [u.id, u]));

        console.log(`   Found ${users.length} users. Scanning for discrepancies...`);

        const processedPairs = new Set<string>(); // Format: "thiefId_victimId"
        const batch = db.batch();
        let totalUpdates = 0;

        for (const userObj of users) {
            const user = userObj as any;
            const userId = user.id;

            // 1. Check relationships where 'user' is the THIEF (User -> Victim)
            const victims = (user.recentTheftVictims || []);
            for (const v of victims) {
                const pairKey = `${userId}_${v.userId}`;
                if (!processedPairs.has(pairKey)) {
                    await checkAndQueueFix(pairKey, userId, v.userId, userMap, batch);
                    processedPairs.add(pairKey);
                    if (totalUpdates > 400) break; // Safety break for batch limit
                }
            }

            // 2. Check relationships where 'user' is the VICTIM (Thief -> User)
            const thieves = (user.recentThieves || []);
            for (const t of thieves) {
                const pairKey = `${t.userId}_${userId}`;
                if (!processedPairs.has(pairKey)) {
                    await checkAndQueueFix(pairKey, t.userId, userId, userMap, batch);
                    processedPairs.add(pairKey);
                    if (totalUpdates > 400) break;
                }
            }
        }

        async function checkAndQueueFix(pairKey: string, thiefId: string, victimId: string, map: Map<string, any>, batch: FirebaseFirestore.WriteBatch) {
            const thiefDoc = map.get(thiefId) as any;
            const victimDoc = map.get(victimId) as any;

            if (!thiefDoc || !victimDoc) return; // User might be deleted/unknown

            // Get counts from both perspectives
            // A. Thief's perspective (How many times I stole from Victim)
            const thiefViewParams = (thiefDoc.recentTheftVictims || []).find((r: any) => r.userId === victimId);
            const countFromThief = thiefViewParams?.count || 0;

            // B. Victim's perspective (How many times Thief stole from Me)
            const victimViewParams = (victimDoc.recentThieves || []).find((r: any) => r.userId === thiefId);
            const countFromVictim = victimViewParams?.count || 0;

            const maxCount = Math.max(countFromThief, countFromVictim);

            if (countFromThief !== countFromVictim) {
                console.log(`   ⚠️ Discrepancy found for Thief [${thiefDoc.displayName}] vs Victim [${victimDoc.displayName}]`);
                console.log(`      - Thief claims: ${countFromThief}`);
                console.log(`      - Victim claims: ${countFromVictim}`);
                console.log(`      => Fixing both to: ${maxCount}`);

                // Ref to documents
                const thiefRef = db.collection('users').doc(thiefId);
                const victimRef = db.collection('users').doc(victimId);

                // Update Thief's list
                let newVictimsList = thiefDoc.recentTheftVictims || [];
                if (!thiefViewParams) {
                    // Add missing entry
                    newVictimsList.push({
                        userId: victimId,
                        displayName: victimDoc.displayName || "Unknown",
                        avatarURL: victimDoc.avatarURL || null,
                        count: maxCount,
                        lastInteractionAt: new Date() // Fallback
                    });
                } else {
                    newVictimsList = newVictimsList.map((r: any) => r.userId === victimId ? { ...r, count: maxCount } : r);
                }
                batch.update(thiefRef, { recentTheftVictims: newVictimsList });
                // Update local map to reflect change if needed later? (Scanning is one pass, so mostly fine)

                // Update Victim's list
                let newThievesList = victimDoc.recentThieves || [];
                if (!victimViewParams) {
                    // Add missing entry
                    newThievesList.push({
                        userId: thiefId,
                        displayName: thiefDoc.displayName || "Unknown",
                        avatarURL: thiefDoc.avatarURL || null,
                        count: maxCount,
                        lastInteractionAt: new Date()
                    });
                } else {
                    newThievesList = newThievesList.map((r: any) => r.userId === thiefId ? { ...r, count: maxCount } : r);
                }
                batch.update(victimRef, { recentThieves: newThievesList });

                totalUpdates += 2; // Roughly 2 writes per fix
            }
        }

        if (totalUpdates > 0) {
            console.log(`\n💾 Committing ${totalUpdates} updates...`);
            await batch.commit();
            console.log("✅ Global Rivalry Audit Complete: Data synchronized.");
        } else {
            console.log("\n✨ System Clean: No rivalry discrepancies found across any users.");
        }

    } catch (error) {
        console.error("❌ Error in global audit:", error);
    } finally {
        process.exit(0);
    }
}

fixAllRivalries();
