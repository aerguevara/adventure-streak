import sys
import os
import json

# Ensure the src directory is in the python path
sys.path.append(os.path.join(os.path.dirname(__file__), "src"))

from crewai_fraud_analysis.tools.firestore_tool import FirestoreTool

def test_tool():
    print("Iniciando test de FirestoreTool...")
    tool = FirestoreTool()
    
    # Test with default limit of 5
    print("\nEjecutando _run() con valores por defecto (days_back=1, limit=5)...")
    try:
        result_json = tool._run(days_back=1, limit=5)
        
        if result_json.startswith("Error") or result_json.startswith("No activities"):
            print(f"Resultado: {result_json}")
        else:
            data = json.loads(result_json)
            print(f"\n¡Éxito! Se han recuperado {len(data)} entrenos.")
            
            for i, activity in enumerate(data):
                activity_id = activity.get('activityId')
                metrics = activity.get('route_metrics', {})
                activity_data = activity.get('data', {})
                print(f"  - Entreno {i+1}: ID {activity_id} | Metrics: {metrics}")
                
    except Exception as e:
        print(f"\nError durante la ejecución: {e}")

if __name__ == "__main__":
    test_tool()
