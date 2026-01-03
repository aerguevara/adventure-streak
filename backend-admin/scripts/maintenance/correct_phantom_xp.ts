
import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { readFileSync } from "fs";

const USER_ID = "i1CEf9eU4MhEOabFGrv2ymPSMFH3";
const EXACT_PHANTOM_XP = 771;

async function main() {
    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({ credential: cert(serviceAccount), projectId: "adventure-streak" });
    }

    const db = getFirestore();
    console.log(`Resetting XP for user: ${USER_ID}`);

    const userRef = db.collection("users").doc(USER_ID);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        console.error("User not found");
        return;
    }

    const currentXP = userDoc.data()?.xp || 0;
    const correctXP = currentXP - EXACT_PHANTOM_XP;

    console.log(`Current XP: ${currentXP}`);
    console.log(`Detected Phantom XP from Nov activities (256+269+246): ${EXACT_PHANTOM_XP}`);
    console.log(`New Correct XP: ${correctXP}`);

    await userRef.update({
        xp: correctXP
    });

    console.log("✅ User XP corrected.");
}

main().catch(console.error);
