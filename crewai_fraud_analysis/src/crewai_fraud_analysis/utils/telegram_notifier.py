import requests
import os
from dotenv import load_dotenv

load_dotenv()

class TelegramNotifier:
    def __init__(self):
        self.token = os.getenv("TELEGRAM_BOT_TOKEN")
        self.chat_id = os.getenv("TELEGRAM_CHAT_ID")
        self.api_url = f"https://api.telegram.org/bot{self.token}/sendMessage"

    def send_message(self, text: str):
        if not self.token or not self.chat_id:
            print("Telegram credentials missing. Skipping notification.")
            return False

        try:
            # Telegram has a limit of 4096 characters per message
            # We truncate if necessary or we could split it, but usually fraud reports are shorter.
            if len(text) > 4000:
                text = text[:4000] + "\n... (Reporte truncado por longitud)"

            payload = {
                "chat_id": self.chat_id,
                "text": text,
                "parse_mode": "Markdown"
            }
            response = requests.post(self.api_url, json=payload)
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"Error sending Telegram message: {e}")
            return False
