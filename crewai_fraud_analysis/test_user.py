import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

load_dotenv()
cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)
db = firestore.client()

user_id = "fR0Kt85lznOnzoMgn17Nxow6QHS2"

print("Checking 'user' collection...")
doc1 = db.collection("user").document(user_id).get()
if doc1.exists:
    print(f"Found in 'user': {doc1.to_dict().keys()}")
    print(doc1.to_dict())

print("\nChecking 'users' collection...")
doc2 = db.collection("users").document(user_id).get()
if doc2.exists:
    print(f"Found in 'users': {doc2.to_dict().keys()}")
    print(doc2.to_dict())
