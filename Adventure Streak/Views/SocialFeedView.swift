import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import MapKit

struct SocialFeedView: View {
    @StateObject var viewModel = SocialViewModel()
    @State private var selectedStory: UserStory? = nil
    @State private var showStoryPlayer = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                NeonBackgroundView(scrollOffset: scrollOffset)
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if viewModel.posts.isEmpty && viewModel.stories.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            StoriesBarView(stories: viewModel.stories) { story in
                                selectedStory = story
                                showStoryPlayer = true
                            }
                            .padding(.bottom, 10)
                            
                            ForEach(viewModel.displayPosts) { post in
                                NavigationLink {
                                    SocialPostDetailView(post: post)
                                } label: {
                                    ActivityCardView(
                                        activity: post,
                                        reactionState: viewModel.reactionState(for: post),
                                        onReaction: { viewModel.react(to: post, with: $0) }
                                    )
                                    .glowPulse(isActive: isMostRecent(post), color: .orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = -value
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showStoryPlayer) {
             StoryContainerView(
                 stories: viewModel.stories,
                 selectedStory: $selectedStory,
                 isPresented: $showStoryPlayer
             )
        }
    }
    
    // Check if it's the top post AND recent (<1 hour)
    func isMostRecent(_ post: SocialPost) -> Bool {
        guard let firstPost = viewModel.displayPosts.first else { return false }
        guard post.id == firstPost.id else { return false }
        
        // 1 Hour window
        return Date().timeIntervalSince(post.date) < 3600
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
            .font(.system(size: 50))
            .foregroundColor(.gray)
            Text("No hay actividad reciente")
            .font(.headline)
            .foregroundColor(.white)
            Text("Sigue a otros aventureros para ver su progreso aquí.")
            .font(.subheadline)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
    }
}

