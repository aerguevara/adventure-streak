import SwiftUI

// NEW: Added for multiplayer conquest feature
struct ActivityFeedView: View {
    @StateObject private var repository = FeedRepository.shared
    
    var body: some View {
        List(repository.events) { event in
            HStack {
                Image(systemName: iconFor(type: event.type))
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(event.message)
                        .font(.body)
                    Text(event.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Community Feed")
        .overlay {
            if repository.events.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No events yet")
                        .font(.headline)
                    Text("Connect to Firebase to see multiplayer activity.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Debug info
                    #if canImport(FirebaseCore)
                    Text("Firebase SDK: Detected")
                        .font(.caption2)
                        .foregroundColor(.green)
                    #else
                    Text("Firebase SDK: Not Detected")
                        .font(.caption2)
                        .foregroundColor(.red)
                    #endif
                }
            }
        }
        .onAppear {
            repository.observeFeed()
        }
    }
    
    private func iconFor(type: String) -> String {
        switch type {
        case "conquest": return "flag.fill"
        case "streak": return "flame.fill"
        case "badge": return "medal.fill"
        default: return "bell.fill"
        }
    }
}
