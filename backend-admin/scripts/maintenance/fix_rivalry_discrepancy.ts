import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
});

const db = getFirestore(app); // Default is PRO

const USER_A_ID = "CVZ34x99UuU6fCrOEc8Wg5nPYX82"; // Anyelo
const USER_B_ID = "JaSFY1oPRUfJmuIgFf1LUzl6yOp2"; // Albanys

async function fixRivalry() {
    console.log(`🤖 Auditing Rivalry: ${USER_A_ID} <-> ${USER_B_ID}`);

    const docA = await db.collection('users').doc(USER_A_ID).get();
    const docB = await db.collection('users').doc(USER_B_ID).get();

    const dataA = docA.data() || {};
    const dataB = docB.data() || {};

    // 1. Direction: A steals from B
    // A's list of victims should contain B
    // B's list of thieves should contain A
    const aVictimEntry = (dataA.recentTheftVictims || []).find((r: any) => r.userId === USER_B_ID);
    const bThiefEntry = (dataB.recentThieves || []).find((r: any) => r.userId === USER_A_ID);

    const countA_claims_stolen = aVictimEntry?.count || 0;
    const countB_claims_stolen_by = bThiefEntry?.count || 0;
    const maxA = Math.max(countA_claims_stolen, countB_claims_stolen_by);

    console.log(`\n⚔️ Direction: A (Anyelo) steals from B (Albanys)`);
    console.log(`   - Anyelo claims he stole: ${countA_claims_stolen}`);
    console.log(`   - Albanys claims Anyelo stole: ${countB_claims_stolen_by}`);
    console.log(`   => TARGET CORRECT COUNT: ${maxA}`);

    // 2. Direction: B steals from A
    // B's list of victims should contain A
    // A's list of thieves should contain B
    const bVictimEntry = (dataB.recentTheftVictims || []).find((r: any) => r.userId === USER_A_ID);
    const aThiefEntry = (dataA.recentThieves || []).find((r: any) => r.userId === USER_B_ID);

    const countB_claims_stolen = bVictimEntry?.count || 0;
    const countA_claims_stolen_by = aThiefEntry?.count || 0;
    const maxB = Math.max(countB_claims_stolen, countA_claims_stolen_by);

    console.log(`\n⚔️ Direction: B (Albanys) steals from A (Anyelo)`);
    console.log(`   - Albanys claims she stole: ${countB_claims_stolen}`);
    console.log(`   - Anyelo claims Albanys stole: ${countA_claims_stolen_by}`);
    console.log(`   => TARGET CORRECT COUNT: ${maxB}`);

    // FIX
    const batch = db.batch();
    let updates = 0;

    // Fix A -> B
    if (countA_claims_stolen < maxA && aVictimEntry) {
        // Update A's victim list
        const newVictims = dataA.recentTheftVictims.map((r: any) => r.userId === USER_B_ID ? { ...r, count: maxA } : r);
        batch.update(docA.ref, { recentTheftVictims: newVictims });
        updates++;
    }
    if (countB_claims_stolen_by < maxA && bThiefEntry) {
        // Update B's thief list
        const newThieves = dataB.recentThieves.map((r: any) => r.userId === USER_A_ID ? { ...r, count: maxA } : r);
        batch.update(docB.ref, { recentThieves: newThieves });
        updates++;
    }

    // Fix B -> A
    if (countB_claims_stolen < maxB && bVictimEntry) {
        const newVictims = dataB.recentTheftVictims.map((r: any) => r.userId === USER_A_ID ? { ...r, count: maxB } : r);
        batch.update(docB.ref, { recentTheftVictims: newVictims });
        updates++;
    }
    if (countA_claims_stolen_by < maxB && aThiefEntry) {
        const newThieves = dataA.recentThieves.map((r: any) => r.userId === USER_B_ID ? { ...r, count: maxB } : r);
        batch.update(docA.ref, { recentThieves: newThieves });
        updates++;
    }

    if (updates > 0) {
        await batch.commit();
        console.log(`\n✅ Applied ${updates} fixes to synchronize rivalry counts.`);
    } else {
        console.log(`\n✨ No fixes needed (or missing entries preventing sync).`);
    }
}

fixRivalry();
