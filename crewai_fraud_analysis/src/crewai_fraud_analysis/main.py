#!/usr/bin/env python
import sys
import warnings
import os
from dotenv import load_dotenv, find_dotenv
load_dotenv(find_dotenv())

from datetime import datetime

from crewai_fraud_analysis.crew import CrewaiFraudAnalysis

warnings.filterwarnings("ignore", category=SyntaxWarning, module="pysbd")

# This main file is intended to be a way for you to run your
# crew locally, so refrain from adding unnecessary logic into this file.
# Replace with inputs you want to test with, it will automatically
# interpolate any tasks and agents information

import time
from crewai_fraud_analysis.utils.telegram_notifier import TelegramNotifier

def run():
    """
    Run the crew for the last hour once and send to Telegram.
    """
    notifier = TelegramNotifier()
    inputs = {
        'hours_back': 1
    }

    try:
        result = CrewaiFraudAnalysis().crew().kickoff(inputs=inputs)
        report_text = str(result).replace("<|im_start|>", "").replace("<|im_end|>", "")
        notifier.send_message(report_text)
        return result
    except Exception as e:
        raise Exception(f"An error occurred while running the crew: {e}")

def run_hourly():
    """
    Run the crew every hour and send the result to Telegram.
    """
    notifier = TelegramNotifier()
    print("Iniciando planificador horario de CrewAI Fraud Analysis...")
    
    while True:
        try:
            print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Iniciando ejecución horaria...")
            
            inputs = {
                'hours_back': 1
            }
            
            result = CrewaiFraudAnalysis().crew().kickoff(inputs=inputs)
            
            # Enviar el reporte a Telegram
            report_text = str(result)
            # Limpieza básica de tokens residuales si los hubiera
            report_text = report_text.replace("<|im_start|>", "").replace("<|im_end|>", "")
            
            success = notifier.send_message(report_text)
            if success:
                print("Reporte enviado exitosamente a Telegram.")
            else:
                print("Fallo al enviar el reporte a Telegram. Revisa el archivo .env.")
                
            print(f"Ejecución completada. Esperando 1 hora...")
            time.sleep(3600)
            
        except Exception as e:
            print(f"Error en la ejecución horaria: {e}")
            print("Reintentando en 60 segundos...")
            time.sleep(60)

def train():
    """
    Train the crew for a given number of iterations.
    """
    inputs = {
        'days_back': 1
    }
    try:
        CrewaiFraudAnalysis().crew().train(n_iterations=int(sys.argv[1]), filename=sys.argv[2], inputs=inputs)

    except Exception as e:
        raise Exception(f"An error occurred while training the crew: {e}")

def replay():
    """
    Replay the crew execution from a specific task.
    """
    try:
        CrewaiFraudAnalysis().crew().replay(task_id=sys.argv[1])

    except Exception as e:
        raise Exception(f"An error occurred while replaying the crew: {e}")

def test():
    """
    Test the crew execution and returns the results.
    """
    inputs = {
        "days_back": 1
    }

    try:
        CrewaiFraudAnalysis().crew().test(n_iterations=int(sys.argv[1]), eval_llm=sys.argv[2], inputs=inputs)

    except Exception as e:
        raise Exception(f"An error occurred while testing the crew: {e}")

def run_chat():
    """
    Run the interactive Telegram chat service.
    """
    try:
        from crewai_fraud_analysis.utils.telegram_chat import TelegramChat
        chat = TelegramChat()
        chat.run()
    except Exception as e:
        raise Exception(f"An error occurred while running the chat service: {e}")

def run_with_trigger():
    """
    Run the crew with trigger payload.
    """
    import json

    if len(sys.argv) < 2:
        raise Exception("No trigger payload provided. Please provide JSON payload as argument.")

    try:
        trigger_payload = json.loads(sys.argv[1])
    except json.JSONDecodeError:
        raise Exception("Invalid JSON payload provided as argument")

    inputs = {
        "crewai_trigger_payload": trigger_payload,
        "topic": "",
        "current_year": ""
    }

    try:
        result = CrewaiFraudAnalysis().crew().kickoff(inputs=inputs)
        return result
    except Exception as e:
        raise Exception(f"An error occurred while running the crew with trigger: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "run":
            run()
        elif command == "run_hourly":
            run_hourly()
        elif command == "run_chat":
            run_chat()
        elif command == "train":
            train()
        elif command == "replay":
            replay()
        elif command == "test":
            test()
        elif command == "run_with_trigger":
            run_with_trigger()
        else:
            print(f"Comando desconocido: {command}")
    else:
        print("Uso: python -m crewai_fraud_analysis.main [run|run_hourly|run_chat|train|replay|test]")
