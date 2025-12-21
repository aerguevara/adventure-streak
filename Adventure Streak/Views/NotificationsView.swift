import SwiftUI

struct NotificationsView: View {
    @StateObject private var service = NotificationService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Notifications")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if service.unreadCount > 0 {
                        Button("Mark all as read") {
                            service.markAllAsRead()
                        }
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A259FF"))
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                if service.notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No notifications yet")
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(service.notifications) { notification in
                            NotificationRow(notification: notification)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .onAppear {
                                    if !notification.isRead {
                                        service.markAsRead(notification)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar or Icon
            if notification.senderId == "system" {
                Circle().fill(systemColor(for: notification.type).opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: systemIcon(for: notification.type))
                            .foregroundColor(systemColor(for: notification.type))
                    )
            } else if let avatarURL = notification.senderAvatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.senderId == "system" ? "Adventure Streak" : notification.senderName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(messageFor(notification))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(notification.timestamp.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Reaction Emoji
            if let reactionValue = notification.reactionType, 
               let reaction = ReactionType(rawValue: reactionValue) {
                Text(reaction.emoji)
                    .font(.title2)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(notification.isRead ? Color.white.opacity(0.02) : Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.isRead ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func messageFor(_ notification: AppNotification) -> String {
        switch notification.type {
        case .reaction:
            return "reaccionó a tu actividad"
        case .follow:
            return "empezó a seguirte"
        case .achievement:
            return "desbloqueó un nuevo logro"
        case .territory_conquered:
            return "¡Has conquistado nuevos territorios!"
        case .territory_stolen:
            return "¡Cuidado! Alguien te ha robado un territorio"
        case .territory_defended:
            return "Has defendido tus territorios con éxito"
        case .workout_import:
            return "Entrenamiento importado correctamente"
        }
    }
    
    private func systemIcon(for type: NotificationType) -> String {
        switch type {
        case .achievement: return "trophy.fill"
        case .territory_conquered: return "map.fill"
        case .territory_stolen: return "exclamationmark.triangle.fill"
        case .territory_defended: return "shield.fill"
        case .workout_import: return "arrow.down.doc.fill"
        default: return "bell.fill"
        }
    }
    
    private func systemColor(for type: NotificationType) -> Color {
        switch type {
        case .achievement: return .yellow
        case .territory_conquered: return .green
        case .territory_stolen: return .red
        case .territory_defended: return .blue
        case .workout_import: return .purple
        default: return .gray
        }
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
