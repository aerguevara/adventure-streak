from crewai import Agent, Crew, Process, Task
from crewai.project import CrewBase, agent, crew, task
from crewai_fraud_analysis.tools.firestore_tool import FirestoreTool
# If you want to run a snippet of code before or after the crew starts,
# you can use the @before_kickoff and @after_kickoff decorators
# https://docs.crewai.com/concepts/crews#example-crew-class-with-decorators

@CrewBase
class CrewaiFraudAnalysis():
    """CrewaiFraudAnalysis crew"""

    # Learn more about YAML configuration files here:
    # Agents: https://docs.crewai.com/concepts/agents#yaml-configuration-recommended
    # Tasks: https://docs.crewai.com/concepts/tasks#yaml-configuration-recommended
    
    # If you would like to add tools to your agents, you can learn more about it here:
    # https://docs.crewai.com/concepts/agents#agent-tools
    @agent
    def workout_speed_analyst(self) -> Agent:
        return Agent(
            config=self.agents_config['workout_speed_analyst'],
            tools=[FirestoreTool()],
            verbose=True
        )

    @agent
    def spatial_integrity_auditor(self) -> Agent:
        return Agent(
            config=self.agents_config['spatial_integrity_auditor'],
            verbose=True
        )

    @agent
    def fraud_reporting_officer(self) -> Agent:
        return Agent(
            config=self.agents_config['fraud_reporting_officer'],
            verbose=True
        )

    @task
    def fetch_daily_workouts_task(self) -> Task:
        return Task(
            config=self.tasks_config['fetch_daily_workouts_task'],
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
            output_file='fraud_report.md'
        )

    @crew
    def crew(self) -> Crew:
        """Creates the CrewaiFraudAnalysis crew"""
        # To learn how to add knowledge sources to your crew, check out the documentation:
        # https://docs.crewai.com/concepts/knowledge#what-is-knowledge

        return Crew(
            agents=self.agents, # Automatically created by the @agent decorator
            tasks=self.tasks, # Automatically created by the @task decorator
            process=Process.sequential,
            verbose=True,
            # process=Process.hierarchical, # In case you wanna use that instead https://docs.crewai.com/how-to/Hierarchical/
        )
