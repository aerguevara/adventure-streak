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
        // Enviar a una cola de background para no bloquear y dar un pequeño respiro al sistema en el arranque
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
            let request = BGAppRefreshTaskRequest(identifier: self.refreshIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
            do {
                try BGTaskScheduler.shared.submit(request)
                print("📅 [BackgroundTaskService] Task scheduled: \(self.refreshIdentifier)")
            } catch {
                // Silenciamos el log si el error es "unavailable" (Code 1) durante el arranque/foreground,
                // ya que iOS lo auto-gestionará cuando sea apropiado.
                let nsError = error as NSError
                if nsError.domain == BGTaskScheduler.errorDomain && nsError.code == 1 {
                    // No imprimimos error ruidoso para Code 1 si estamos en foreground activo
                    return
                }
                print("❌ No se pudo programar BGTask: \(error)")
            }
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
