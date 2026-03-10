from crewai_fraud_analysis.utils.telegram_notifier import TelegramNotifier

def test_notifier():
    notifier = TelegramNotifier()
    success = notifier.send_message("Test message from CrewAI Fraud Detection system.")
    if success:
        print("✅ Message sent successfully!")
    else:
        print("❌ Failed to send message.")

if __name__ == "__main__":
    test_notifier()
