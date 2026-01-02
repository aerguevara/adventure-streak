import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync } from "fs";

async function checkArchive() {
    const serviceAccountPath = "/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json";
    if (getApps().length === 0) {
        const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
        initializeApp({
            credential: cert(serviceAccount),
            projectId: "adventure-streak"
        });
    }

    const db = getFirestore("(default)");
    const ids = [
        "59D5ACDB-FA74-47CB-8890-004E1E6CA691",
        "D6535315-1C2A-4DA7-B867-30A32C4A147E",
        "0CAE1A88-EC81-4079-B53A-2D04B7AFCEFB",
        "25FC309A-0B7B-4690-9937-17A635353260",
        "89E13171-69D9-4BAD-B53E-462CF98BE669",
        "8485B781-FAC3-4AC3-8D92-E17D9AAF96B2",
        "4DAF5F44-9C4B-4477-B58E-48ABDCF3AC43",
        "EFE5547E-9DF0-442C-9EAE-A7AF2850AAE8",
        "DFE90ABC-D3B3-409D-B831-20AFF473FF06",
        "C7B01B7A-BCFB-494D-A212-B7708C202E46",
        "1046E702-93B4-43A4-8046-67C8BBCC61EC"
    ];

    console.log("Checking activities_archive...");
    for (const id of ids) {
        const doc = await db.collection("activities_archive").doc(id).get();
        console.log(`- ID: ${id} exists in archive: ${doc.exists}`);
    }
}

checkArchive().catch(console.error);
