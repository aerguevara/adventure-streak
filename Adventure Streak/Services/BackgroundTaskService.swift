import Foundation
import BackgroundTasks

/// Gestiona el registro y la programación de tareas en background.
final class BackgroundTaskService {
    static let shared = BackgroundTaskService()
    
    private let refreshIdentifier = "com.adventurestreak.refreshHealth"
    
    private init() {}
    
    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
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
        } catch {
            print("No se pudo programar BGTask: \(error)")
        }
    }
    
    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh() // vuelve a programar para el futuro
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        queue.addOperation {
            // Reusar el flujo de observers para disparar notificaciones si hay entrenos nuevos
            HealthKitManager.shared.startBackgroundObservers()
        }
        
        queue.addOperation {
            task.setTaskCompleted(success: true)
        }
    }
}
