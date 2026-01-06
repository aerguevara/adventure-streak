import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
    projectId: "adventure-streak",
    appId: "1:1038217224208:web:495f24d3c778d5c4a9aa95",
    storageBucket: "adventure-streak.firebasestorage.app",
    apiKey: "AIzaSyCWtEHhRa1GktZOa4G3O4VN5DNcBIgmjrc",
    authDomain: "adventure-streak.firebaseapp.com",
    messagingSenderId: "1038217224208",
    measurementId: "G-CK25B43HJL"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
