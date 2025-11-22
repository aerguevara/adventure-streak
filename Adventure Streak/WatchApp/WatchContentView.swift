import SwiftUI

#if os(watchOS)
struct WatchContentView: View {
    @StateObject private var sessionManager = WatchSessionManager.shared
    
    var body: some View {
        VStack {
            if sessionManager.isRunning {
                VStack(spacing: 10) {
                    Text(formatDuration(sessionManager.duration))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    
                    Text(String(format: "%.2f km", sessionManager.distance / 1000))
                        .font(.headline)
                    
                    Button(action: {
                        sessionManager.stopSession()
                    }) {
                        Text("End")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(20)
                    }
                }
            } else {
                List {
                    Button(action: { sessionManager.startSession(type: .run) }) {
                        Label("Run", systemImage: "figure.run")
                    }
                    Button(action: { sessionManager.startSession(type: .walk) }) {
                        Label("Walk", systemImage: "figure.walk")
                    }
                    Button(action: { sessionManager.startSession(type: .bike) }) {
                        Label("Bike", systemImage: "bicycle")
                    }
                }
                .navigationTitle("Start")
            }
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
}
#endif
