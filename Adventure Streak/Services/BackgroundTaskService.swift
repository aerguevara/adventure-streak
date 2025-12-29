import Foundation
import BackgroundTasks

/// Gestiona el registro y la programación de tareas en background.
final class BackgroundTaskService: Sendable {
    static let shared = BackgroundTaskService()
    
    private let refreshIdentifier = "com.adventurestreak.refreshHealth"
    
    private init() {}
    
    func registerTasks() {
        print("📲 [BackgroundTaskService] Registering BGTask: \(refreshIdentifier)")
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            print("🔋 [BackgroundTaskService] Running background task: \(task.identifier)")
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleRefresh(task: refreshTask)
        }
    }
    
    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        // Programamos próximo intento en ~1 hora para no saturar; iOS ajusta según heurísticas
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 [BackgroundTaskService] Task scheduled: \(refreshIdentifier)")
        } catch {
            print("❌ No se pudo programar BGTask: \(error)")
        }
    }
    
    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh() // vuelve a programar para el futuro

        let completionLock = NSLock()
        var completed = false
        let complete: (Bool) -> Void = { success in
            completionLock.lock()
            if completed {
                completionLock.unlock()
                return
            }
            completed = true
            completionLock.unlock()
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            complete(false)
        }

        HealthKitManager.shared.startBackgroundObserversInBackground()
        HealthKitManager.shared.checkForNewWorkoutsInBackground {
            complete(true)
        }
    }
}
