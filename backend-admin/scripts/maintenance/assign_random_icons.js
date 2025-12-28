const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");

// 1. Initialize Firebase
const serviceAccount = require("../../secrets/serviceAccount.json");

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// 2. Parse arguments
const args = process.argv.slice(2);
const envArg = args.find(arg => arg.startsWith("--env="));
const env = envArg ? envArg.split("=")[1] : "pro"; // Default to pro if using (default) database or pre if specified

const dbName = env === "pre" ? "adventure-streak-pre" : "(default)";
const db = getFirestore(app, (env === "pre" ? "adventure-streak-pre" : undefined));

console.log(`🚀 Icon Assignment Script started...`);
console.log(`Environment: ${env}`);
console.log(`Database: ${dbName}`);

const ICONS_POOL = [
    "🚩", "🚴‍♂️", "🏃‍♂️", "🚶‍♂️", "🧗‍♂️", "🚣‍♂️", "🏊‍♂️", "🏄‍♂️",
    "⛷", "🏂", "🚵‍♂️", "🥾", "🏹", "🎣", "⛺️", "🏔",
    "🌄", "🔥", "🦅", "🐺", "🐻", "🦄", "🐉", "⚔️",
    "🛡", "🏺", "💎", "🧭", "🗺", "🔭", "🛸", "🚀"
];

async function main() {
    try {
        // 3. Fetch all users
        console.log("Fetching users...");
        const usersSnapshot = await db.collection("users").get();
        const users = usersSnapshot.docs;
        console.log(`Found ${users.length} users.`);

        // 4. Fetch currently reserved icons
        console.log("Fetching reserved icons...");
        const reservedSnapshot = await db.collection("reserved_icons").get();
        const reservedIcons = new Set(reservedSnapshot.docs.map(doc => doc.id));
        console.log(`Found ${reservedIcons.size} reserved icons.`);

        // 5. Identify users needing icons
        const usersToUpdate = users.filter(doc => !doc.data().mapIcon);
        console.log(`${usersToUpdate.length} users need a new icon.`);

        if (usersToUpdate.length === 0) {
            console.log("✅ All users already have icons. Nothing to do.");
            process.exit(0);
        }

        // 6. Calculate available icons
        let availableIcons = ICONS_POOL.filter(icon => !reservedIcons.has(icon));
        console.log(`${availableIcons.length} icons available in the pool.`);

        if (availableIcons.length < usersToUpdate.length) {
            console.error(`❌ Not enough icons in the pool (${availableIcons.length}) for the users needing them (${usersToUpdate.length})!`);
            process.exit(1);
        }

        // 7. Shuffle available icons
        availableIcons = availableIcons.sort(() => Math.random() - 0.5);

        // 8. Update in batches
        console.log("Starting updates...");
        let count = 0;

        for (const userDoc of usersToUpdate) {
            const userId = userDoc.id;
            const icon = availableIcons.pop();

            const batch = db.batch();

            // Update user
            batch.update(db.collection("users").doc(userId), { mapIcon: icon });

            // Reserve icon
            batch.set(db.collection("reserved_icons").doc(icon), {
                userId: userId,
                reservedAt: admin.firestore.FieldValue.serverTimestamp(),
                assignedBy: "automation_script"
            });

            await batch.commit();
            count++;
            console.log(`[${count}/${usersToUpdate.length}] Assigned ${icon} to user ${userId}`);
        }

        console.log("\n✅ DONE. Successfully assigned icons to all users.");
    } catch (error) {
        console.error("❌ Script failed:", error);
    } finally {
        process.exit(0);
    }
}

main();
