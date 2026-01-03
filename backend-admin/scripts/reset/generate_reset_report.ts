import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import * as fs from 'fs';
import * as path from 'path';

const serviceAccountPath = '/Users/aerguevara/Documents/develop/Adventure Streak/Docs/serviceAccount.json';
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://adventure-streak-pre-default-rtdb.europe-west1.firebasedatabase.app"
});

// Connect to PRO (default)
const db = getFirestore(app);

async function generateReport() {
    try {
        const usersSnap = await db.collection('users').get();
        const users = usersSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        // Sort by XP descending (Leaderboard style)
        users.sort((a: any, b: any) => (b.xp || 0) - (a.xp || 0));

        const now = new Date();
        const dateStr = now.toISOString().replace(/T/, ' ').replace(/\..+/, '');

        let md = `# 🛡️ PRO Reset Status Report\n\n`;
        md += `**Generated At:** ${dateStr}\n`;
        md += `**Environment:** Production (PRO)\n`;
        md += `**Total Users:** ${users.length}\n\n`;

        md += `## 🏆 User Leaderboard (New Era)\n\n`;
        md += `| Rank | User | Level | XP | Territories (C/S/D/R) | Last Active |\n`;
        md += `| :--- | :--- | :---: | :---: | :---: | :--- |\n`;

        users.forEach((u: any, index) => {
            const name = u.displayName || u.userName || "Unknown";
            const level = u.level || 1;
            const xp = u.xp || 0;
            const conq = u.totalConqueredTerritories || 0;
            const stolen = u.totalStolenTerritories || 0;
            const defended = u.totalDefendedTerritories || 0;
            const recaptured = u.totalRecapturedTerritories || 0;

            let lastActive = "N/A";
            if (u.lastActivityDate) {
                const d = u.lastActivityDate.toDate ? u.lastActivityDate.toDate() : new Date(u.lastActivityDate);
                lastActive = d.toLocaleDateString();
            }

            const stats = `${conq}/${stolen}/${defended}/${recaptured}`;
            md += `| ${index + 1} | **${name}**<br>\`${u.id}\` | ${level} | **${xp}** | ${stats} | ${lastActive} |\n`;
        });

        md += `\n\n## 📊 Summary Stats\n`;
        const totalXP = users.reduce((acc, u: any) => acc + (u.xp || 0), 0);
        const totalConquered = users.reduce((acc, u: any) => acc + (u.totalConqueredTerritories || 0), 0);

        md += `- **Global Total XP:** ${totalXP}\n`;
        md += `- **Global Conquered Territories:** ${totalConquered}\n`;

        console.log(md);

    } catch (error) {
        console.error('Error generating report:', error);
    } finally {
        process.exit(0);
    }
}

generateReport();
