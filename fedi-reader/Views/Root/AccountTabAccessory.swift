import SwiftUI

#if os(iOS)
struct AccountTabAccessory: View {
    let account: Account
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.present(sheet: .accountSwitcher)
        } label: {
            HStack(spacing: 8) {
                ProfileAvatarView(url: URL(string: account.avatarURL ?? ""), size: 24)

                Text("@\(account.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
#endif

