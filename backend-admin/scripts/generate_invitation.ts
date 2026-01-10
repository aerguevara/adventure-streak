import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';
import * as path from 'path';

// Parse arguments
const args = process.argv.slice(2);
const help = args.includes('--help') || args.includes('-h');
const codeArg = args.find(arg => arg.startsWith('--code='));
const envArg = args.find(arg => arg.startsWith('--env='));

if (help) {
    console.log(`
Usage: npx ts-node backend-admin/scripts/generate_invitation.ts [options]

Options:
  --code=<CODE>    The invitation code to generate (default: ADVENTURE-TEST-2026)
  --env=<ENV>      The environment to use: 'pre' or 'prod' (default: pre)
  --help, -h       Show this help message
`);
    process.exit(0);
}

const env = envArg ? envArg.split('=')[1] : 'pre';
const code = codeArg ? codeArg.split('=')[1] : 'ADVENTURE-TEST-2026';
const databaseId = env === 'prod' ? 'adventure-streak' : 'adventure-streak-pre';

console.log(`🚀 Generating invitation code "${code}" for environment "${env}" (${databaseId})...`);

const serviceAccountPath = './backend-admin/secrets/serviceAccount.json';

if (!fs.existsSync(serviceAccountPath)) {
    console.error(`❌ Service account not found at: ${serviceAccountPath}`);
    console.error('Please make sure you have the serviceAccount.json file in backend-admin/secrets/');
    process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
}

const db = getFirestore(databaseId);

async function generateInvitation() {
    try {
        const invRef = db.collection('invitations').doc(code);
        const invDoc = await invRef.get();

        if (invDoc.exists) {
            console.log(`⚠️  Invitation code "${code}" already exists.`);
            const data = invDoc.data();
            console.log('Current data:', JSON.stringify(data, null, 2));

            // Optional: Ask to overwrite? For now, just exit or update if needed.
            // Let's update it to ensure it is valid/reset if it was used.
            console.log('🔄 Resetting/Updating existing invitation...');
        } else {
            console.log('✨ Creating new invitation...');
        }

        await invRef.set({
            issuer: "SYSTEM-DEBUG",
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            note: "Generated via script"
        }, { merge: true });

        console.log(`✅ Invitation "${code}" is ready to be used.`);

    } catch (error) {
        console.error('❌ Error generating invitation:', error);
        process.exit(1);
    }
}

generateInvitation().then(() => {
    // Note: admin SDK might keep process open, explicitly exit after a small delay to allow logs to flush
    setTimeout(() => process.exit(0), 500);
});
