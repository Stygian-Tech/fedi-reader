import SwiftUI

struct ProfileTabLabel: View {
    let account: Account?

    var body: some View {
        Label {
            Text("Profile")
        } icon: {
            ProfileAvatarView(
                url: account.flatMap { $0.avatarURL }.flatMap { URL(string: $0) },
                size: 24,
                usePersonIconForFallback: true
            )
        }
    }
}


