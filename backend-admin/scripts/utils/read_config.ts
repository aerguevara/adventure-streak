import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

async function main() {
    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/backend-admin/secrets/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({ credential: cert(serviceAccount), projectId: "adventure-streak" });
    }

    const db = getFirestore("adventure-streak-pre");
    const doc = await db.collection("config").doc("gameplay").get();
    console.log("📄 config/gameplay data:");
    console.log(JSON.stringify(doc.data(), null, 2));
}

main().catch(console.error);
