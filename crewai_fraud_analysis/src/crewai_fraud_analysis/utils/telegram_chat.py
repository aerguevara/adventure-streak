import os
import time
import requests
import threading
from dotenv import load_dotenv, find_dotenv
load_dotenv(find_dotenv())

# Imports de CrewAI
from crewai_fraud_analysis.crew import CrewaiFraudAnalysis
# Aunque usamos CrewAI, mantenemos HumanMessage/SystemMessage por si acaso, 
# pero el core será la Crew.
from langchain_core.messages import HumanMessage, SystemMessage

# load_dotenv ya se llamó arriba

class TelegramChat:
    def __init__(self):
        self.token = os.getenv("TELEGRAM_BOT_TOKEN")
        self.chat_id = os.getenv("TELEGRAM_CHAT_ID")
        self.base_url = f"https://api.telegram.org/bot{self.token}"
        self.last_update_id = 0
        
        # Inicializamos la Crew de Adventure Streak como motor de inteligencia
        self.crew_instance = CrewaiFraudAnalysis().crew()
        
        # Persona para mensajes directos de sistema (opcional)
        self.system_prompt = "Eres el asistente orquestador de Adventure Streak."

    def get_updates(self):
        url = f"{self.base_url}/getUpdates"
        params = {"offset": self.last_update_id + 1, "timeout": 30}
        try:
            response = requests.get(url, params=params)
            if response.status_code == 200:
                data = response.json()
                return data.get("result", [])
        except Exception as e:
            print(f"Error al obtener actualizaciones: {e}")
        return []

    def send_chat_action(self, stop_event):
        """Mantiene el estado 'typing' cada 4 segundos hasta que el evento lo pare."""
        url = f"{self.base_url}/sendChatAction"
        payload = {"chat_id": self.chat_id, "action": "typing"}
        while not stop_event.is_set():
            try:
                requests.post(url, json=payload, timeout=5)
            except Exception as e:
                print(f"Error al enviar acción: {e}")
            time.sleep(4)

    def send_message(self, text):
        url = f"{self.base_url}/sendMessage"
        # Escapado básico para evitar errores de parseo en Telegram si el LLM devuelve Markdown mal formado
        # En una implementación más robusta usaríamos una librería de escapado.
        payload = {"chat_id": self.chat_id, "text": text, "parse_mode": "Markdown"}
        try:
            response = requests.post(url, json=payload, timeout=15)
            if response.status_code != 200:
                print(f"Error de Telegram ({response.status_code}): {response.text}")
                # Reintento sin Markdown si falla por parseo
                if "can't parse" in response.text:
                    payload["parse_mode"] = ""
                    requests.post(url, json=payload, timeout=10)
        except Exception as e:
            print(f"Error al enviar mensaje: {e}")

    def chat_with_model(self, user_text):
        print(f"Invocando CrewAI Orchestrator optimizado para chat...")
        
        # Indicativo de escritura
        stop_typing = threading.Event()
        typing_thread = threading.Thread(target=self.send_chat_action, args=(stop_typing,))
        typing_thread.daemon = True
        typing_thread.start()
        
        try:
            # Usamos la versión optimizada que solo tiene la tarea de chat
            # pero el manager puede delegar si es necesario.
            crew_instance = CrewaiFraudAnalysis().crew_for_chat()
            result = crew_instance.kickoff(inputs={"user_input": user_text})
            
            print(f"DEBUG: Resultado de la Crew: {result}")
            
            ai_content = str(result)
            # Limpieza de tokens
            ai_content = ai_content.replace("<|im_start|>", "").replace("<|im_end|>", "")
            
            return ai_content
        except Exception as e:
            print(f"Error en el chat de CrewAI: {e}")
            return f"He tenido un pequeño problema técnico con mis agentes: {str(e)}. ¿Podemos intentarlo de nuevo?"
        finally:
            stop_typing.set()
            typing_thread.join(timeout=0.5)

    def run(self):
        print("🤖 Bot Multi-Agente (CrewAI Orchestrator) iniciado...")
        
        # Sincronizar el offset inicial para ignorar mensajes antiguos acumulados
        print("Sincronizando mensajes antiguos...")
        updates = self.get_updates()
        if updates:
            self.last_update_id = updates[-1]["update_id"]
            print(f"Ignorando {len(updates)} mensajes antiguos acumulados.")

        while True:
            updates = self.get_updates()
            for update in updates:
                self.last_update_id = update["update_id"]
                message = update.get("message", {})
                
                if str(message.get("chat", {}).get("id")) == str(self.chat_id) and "text" in message:
                    user_text = message["text"]
                    
                    if user_text.startswith('/'):
                        if user_text == '/start':
                            self.send_message("¡Buenas! Soy tu asistente de Adventure Streak. Ahora cuento con un equipo de agentes especializados para ayudarte. ¿Qué quieres analizar?")
                        elif user_text == '/clear':
                            # CrewAI gestiona su memoria, por ahora solo confirmamos reinicio visual
                            self.send_message("🧹 He despejado la mesa. (Nota: La memoria de CrewAI persiste según configuración).")
                        continue

                    response = self.chat_with_model(user_text)
                    self.send_message(response)
            time.sleep(1)

if __name__ == "__main__":
    chat = TelegramChat()
    chat.run()
