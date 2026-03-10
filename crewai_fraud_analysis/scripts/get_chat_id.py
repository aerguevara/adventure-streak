import requests
import json
import os
from dotenv import load_dotenv

load_dotenv()

def get_chat_id():
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    if not token:
        print("Error: TELEGRAM_BOT_TOKEN no encontrado en el .env")
        return

    url = f"https://api.telegram.org/bot{token}/getUpdates"
    try:
        response = requests.get(url)
        data = response.json()
        
        if not data.get("ok"):
            print(f"Error de API: {data.get('description')}")
            return

        results = data.get("result", [])
        if not results:
            print("\n--- NO SE ENCONTRARON MENSAJES ---")
            print("1. Abre Telegram y busca a tu bot.")
            print("2. Presiona 'START' o envíale cualquier mensaje.")
            print("3. Vuelve a ejecutar este script.")
            return

        # Sacar el ID del último mensaje recibido
        last_update = results[-1]
        chat_id = last_update.get("message", {}).get("chat", {}).get("id")
        user_name = last_update.get("message", {}).get("from", {}).get("first_name")

        if chat_id:
            print(f"\n✅ ¡ID Encontrado!")
            print(f"Usuario: {user_name}")
            print(f"Chat ID: {chat_id}")
            print(f"\nCopiado este ID en tu .env como TELEGRAM_CHAT_ID={chat_id}")
        else:
            print("No se pudo extraer el Chat ID de la respuesta.")

    except Exception as e:
        print(f"Error al conectar con Telegram: {e}")

if __name__ == "__main__":
    get_chat_id()
