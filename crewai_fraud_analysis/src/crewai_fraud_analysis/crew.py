import os
from dotenv import load_dotenv, find_dotenv
load_dotenv(find_dotenv())

# Forzamos que TODO lo que use OpenAI por defecto apunte a Ollama
os.environ["OPENAI_API_BASE"] = "http://localhost:11434"
os.environ["OPENAI_BASE_URL"] = "http://localhost:11434"
os.environ["OPENAI_API_KEY"] = "ollama"
os.environ["OPENAI_MODEL_NAME"] = "ollama/qwen3.5:4b" # Override CrewAI's hardcoded gpt-4o-mini inside UnifiedMemory

from crewai import Agent, Crew, Process, Task, LLM
from crewai.memory.unified_memory import Memory
from crewai.project import CrewBase, agent, crew, task
from crewai_fraud_analysis.tools.firestore_tool import FirestoreTool

# Configuración profesional de LLM local siguiendo las mejores prácticas de CrewAI
local_llm = LLM(
    model="ollama/qwen3.5:4b",
    api_key="ollama",
    base_url="http://localhost:11434"
)

# LLM más ligero para tareas de sistema como memoria/análisis si fuera necesario
# Pero por ahora usamos el mismo para consistencia.

@CrewBase
class CrewaiFraudAnalysis():
    """CrewaiFraudAnalysis crew"""

    @agent
    def workout_speed_analyst(self) -> Agent:
        return Agent(
            config=self.agents_config['workout_speed_analyst'],
            tools=[FirestoreTool()], # Ahora el analista de velocidad es el responsable de buscar datos
            llm=local_llm,
            verbose=True
        )

    @agent
    def spatial_integrity_auditor(self) -> Agent:
        return Agent(
            config=self.agents_config['spatial_integrity_auditor'],
            llm=local_llm,
            verbose=True
        )

    @agent
    def fraud_reporting_officer(self) -> Agent:
        return Agent(
            config=self.agents_config['fraud_reporting_officer'],
            llm=local_llm,
            verbose=True
        )

    @agent
    def adventure_streak_orchestrator(self) -> Agent:
        return Agent(
            config=self.agents_config['adventure_streak_orchestrator'],
            # El manager NO debe tener herramientas en Process.hierarchical
            llm=local_llm,
            verbose=True
        )

    @task
    def fetch_hourly_workouts_task(self) -> Task:
        return Task(
            config=self.tasks_config['fetch_hourly_workouts_task'],
        )

    @task
    def analyze_workout_patterns_task(self) -> Task:
        return Task(
            config=self.tasks_config['analyze_workout_patterns_task'],
        )

    @task
    def generate_fraud_report_task(self) -> Task:
        return Task(
            config=self.tasks_config['generate_fraud_report_task'],
        )

    @task
    def handle_user_request_task(self) -> Task:
        return Task(
            config=self.tasks_config['handle_user_request_task'],
        )

    @crew
    def crew(self) -> Crew:
        """Creates the CrewaiFraudAnalysis crew"""
        # Configuración de embedder local para la memoria (CrewAI 1.X espera 'embedder')
        embedder_config = {
            "provider": "ollama",
            "config": {
                "model_name": "nomic-embed-text",
                "url": "http://localhost:11434/api/embeddings",
            }
        }

        # Definimos los agentes especialistas (excluimos al orquestador de la lista de agentes)
        specialists = [
            self.workout_speed_analyst(),
            self.spatial_integrity_auditor(),
            self.fraud_reporting_officer()
        ]

        # Definimos todas las tareas
        tasks = [
            self.fetch_hourly_workouts_task(),
            self.analyze_workout_patterns_task(),
            self.generate_fraud_report_task(),
            self.handle_user_request_task()
        ]

        manager = self.adventure_streak_orchestrator()

        return Crew(
            agents=specialists,
            tasks=tasks,
            process=Process.hierarchical,
            manager_agent=manager,
            memory=True,
            embedder=embedder_config,
            manager_llm=local_llm,
            verbose=True,
        )

    def crew_for_chat(self) -> Crew:
        """Versión optimizada para chat que permite delegación inteligente"""
        # Configuración de embedder local para la memoria (CrewAI 1.X espera 'embedder')
        embedder_config = {
            "provider": "ollama",
            "config": {
                "model_name": "nomic-embed-text",
                "url": "http://localhost:11434/api/embeddings",
            }
        }

        specialists = [
            self.workout_speed_analyst(),
            self.spatial_integrity_auditor(),
            self.fraud_reporting_officer()
        ]

        # Incluimos todas las tareas para que el manager tenga la "capacidad" de delegarlas
        all_tasks = [
            self.fetch_hourly_workouts_task(),
            self.analyze_workout_patterns_task(),
            self.generate_fraud_report_task(),
            self.handle_user_request_task()
        ]

        manager = self.adventure_streak_orchestrator()

        return Crew(
            agents=specialists,
            tasks=all_tasks,
            process=Process.hierarchical,
            manager_agent=manager,
            memory=True,
            embedder=embedder_config,
            manager_llm=local_llm,
            verbose=True,
        )
