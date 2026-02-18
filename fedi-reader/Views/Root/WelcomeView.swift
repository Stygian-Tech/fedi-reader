import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon and title
            VStack(spacing: 16) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)

                Text("Fedi Reader")
                    .font(.roundedLargeTitle.bold())

                Text("Your link-focused Mastodon feed")
                    .font(.roundedTitle3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "link",
                    title: "Link-Focused Feed",
                    description: "See only posts with interesting links"
                )

                FeatureRow(
                    icon: "bookmark",
                    title: "Read Later Integration",
                    description: "Save to Pocket, Instapaper, and more"
                )

                FeatureRow(
                    icon: "globe",
                    title: "Explore Trending",
                    description: "Discover what's popular on your instance"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Login button
            Button {
                appState.present(sheet: .login)
            } label: {
                Text("Connect Mastodon Account")
                    .font(.roundedHeadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.liquidGlass)
            .accessibilityLabel("Connect Mastodon Account")
            .accessibilityHint("Opens login to connect your Mastodon account")
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background {
            GradientBackground()
        }
    }
}


