import * as admin from 'firebase-admin';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../secrets/serviceAccount.json');

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(require(serviceAccountPath)),
        projectId: "adventure-streak"
    });
}

const db = admin.firestore();

async function debugActivity(activityId: string) {
    console.log(`\n🔍 DEEP DEBUG: Actividad ${activityId}`);
    const doc = await db.collection("activities").doc(activityId).get();
    if (!doc.exists) {
        console.log("❌ No existe.");
        return;
    }
    const data = doc.data();
    console.log("-----------------------------------------");
    console.log("Field 'locationLabel' type:", typeof data?.locationLabel);
    console.log("Field 'locationLabel' value:", data?.locationLabel);
    console.log("All keys:", Object.keys(data || {}));
    console.log("-----------------------------------------");

    // Check if there are any other fields with undefined values (shouldn't be possible in Firestore but let's check what we get)
    for (const key in data) {
        if (data[key] === undefined) {
            console.log(`⚠️  FOUND UNDEFINED FIELD: ${key}`);
        }
    }

    console.log("\n🛤️  Checking remote_territories in the area...");
    // We'll just look for a few around the area if possible, or check if we have any recently updated by this user
    const userTerritories = await db.collection("remote_territories")
        .where("userId", "==", data?.userId)
        .limit(10)
        .get();

    console.log(`Found ${userTerritories.size} territories for this user.`);
    userTerritories.docs.forEach(d => {
        const tData = d.data();
        console.log(`Cell ${d.id}: locationLabel=${tData.locationLabel} (type: ${typeof tData.locationLabel})`);
    });
    // --- UPDATE STATUS TO TRIGGER REPROCESSING ---
    if (data?.processingStatus === 'completed') {
        console.log("Activity already completed. No action taken.");
        return;
    }

    console.log("\n⚡ UPDATING STATUS TO 'pending' TO TRIGGER FUNCTION...");
    try {
        await db.collection("activities").doc(activityId).update({
            processingStatus: "pending",
            processingError: admin.firestore.FieldValue.delete(), // Clear previous errors
            lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log("✅ Successfully set status to 'pending'. Watch the logs!");
    } catch (e) {
        console.error("Failed to update status:", e);
    }
}

debugActivity("CD824B46-F0F1-4455-9BA6-9FE784A24748").catch(console.error);
