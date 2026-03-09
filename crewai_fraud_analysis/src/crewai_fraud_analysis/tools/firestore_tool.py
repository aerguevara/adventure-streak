from crewai.tools import BaseTool
from typing import Type, List, Dict, Any
from pydantic import BaseModel, Field
import os
import json
import math
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

load_dotenv()

def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate the great circle distance in meters between two points on the earth."""
    R = 6371000  # radius of Earth in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def parse_firestore_timestamp(ts):
    if isinstance(ts, datetime):
        return ts
    if hasattr(ts, 'timestamp'):  # Firestore DatetimeWithNanoseconds
        return datetime.fromtimestamp(ts.timestamp())
    if isinstance(ts, str):
        try: return datetime.fromisoformat(ts.replace('Z', '+00:00'))
        except: return None
    return None

def compute_route_metrics(routes):
    if not routes or len(routes) < 2:
        return {
            "total_distance_m": 0,
            "gps_jumps_over_300m": 0,
            "point_count": len(routes) if routes else 0
        }
    
    total_distance_m = 0
    jumps_over_300m = 0
    
    for i in range(1, len(routes)):
        p1 = routes[i-1]
        p2 = routes[i]
        
        lat1, lon1 = p1.get("latitude"), p1.get("longitude")
        lat2, lon2 = p2.get("latitude"), p2.get("longitude")
        
        if lat1 is None or lon1 is None or lat2 is None or lon2 is None:
            continue
            
        dist = haversine_distance(lat1, lon1, lat2, lon2)
        total_distance_m += dist
        
        if dist > 300:
            jumps_over_300m += 1
            
    return {
        "total_distance_m": round(total_distance_m, 2),
        "gps_jumps_over_300m": jumps_over_300m,
        "point_count": len(routes)
    }


class FirestoreToolInput(BaseModel):
    """Input schema for FirestoreTool."""
    days_back: int = Field(default=1, description="Number of days back to fetch workouts from.")
    limit: int = Field(default=5, description="Maximum number of workouts to fetch for analysis to save API quota.")

class FirestoreTool(BaseTool):
    name: str = "Firestore Workout Fetcher"
    description: str = (
        "Fetches workout activities from Firestore. "
        "Computes detailed route metrics like average speed from total duration, and GPS jumps locally "
        "to save LLM tokens, returning a JSON string of activities and metrics."
    )
    args_schema: Type[BaseModel] = FirestoreToolInput

    def _run(self, days_back: int = 1, limit: int = 5) -> str:
        try:
            if not firebase_admin._apps:
                cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
                if not cred_path:
                    return "Error: GOOGLE_APPLICATION_CREDENTIALS environment variable not set."
                
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)

            db = firestore.client()
            
            now = datetime.now()
            start_date = now - timedelta(days=days_back)
            
            print(f"Fetching activities since {start_date.isoformat()}...")

            activities_ref = db.collection("activities")
            query = activities_ref.where("endDate", ">=", start_date).order_by("endDate", direction=firestore.Query.DESCENDING).limit(limit)
            docs = query.stream()

            results = []
            for doc in docs:
                activity_data = doc.to_dict()
                activity_id = doc.id
                
                routes = []
                routes_ref = db.collection(f"activities/{activity_id}/routes").order_by("order", direction=firestore.Query.ASCENDING)
                route_docs = routes_ref.stream()
                
                for r_doc in route_docs:
                    r_data = r_doc.to_dict()
                    if "points" in r_data:
                        routes.extend(r_data["points"])

                # Fetch user name
                user_id = activity_data.get("userId")
                user_name = "Desconocido"
                if user_id:
                    try:
                        user_doc = db.collection("users").document(user_id).get()
                        if user_doc.exists:
                            user_name = user_doc.to_dict().get("displayName", "Desconocido")
                    except Exception as e:
                        print(f"Error fetching user {user_id}: {e}")
                
                activity_data["userName"] = user_name

                # Compute metrics locally in Python to save LLM tokens
                route_metrics = compute_route_metrics(routes)
                
                duration_sec = activity_data.get("durationSeconds", 0)
                if duration_sec > 0:
                    route_metrics["average_speed_kmh"] = round((route_metrics["total_distance_m"] / duration_sec) * 3.6, 2)
                else:
                    route_metrics["average_speed_kmh"] = 0

                # Convert timestamps to strings for JSON serialization
                for key, value in activity_data.items():
                    if isinstance(value, datetime):
                        activity_data[key] = value.isoformat()
                    elif hasattr(value, 'isoformat'):
                        activity_data[key] = value.isoformat()

                results.append({
                    "activityId": activity_id,
                    "data": activity_data,
                    "route_metrics": route_metrics
                })

            if not results:
                return f"No activities found in the last {days_back} day(s)."

            return json.dumps(results, indent=2, default=str)

        except Exception as e:
            return f"Error fetching from Firestore: {str(e)}"
