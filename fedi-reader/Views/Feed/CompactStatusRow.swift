import SwiftUI

struct CompactStatusRow: View {
    let status: Status
    @Environment(AppState.self) private var appState
    
    var displayStatus: Status {
        status.displayStatus
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: displayStatus.account.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.tertiary)
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 4) {
                        EmojiText(text: displayStatus.account.displayName, emojis: displayStatus.account.emojis, font: .roundedSubheadline.bold())
                            .lineLimit(1)
                        
                        AccountBadgesView(account: displayStatus.account, size: .small)
                    }
                    
                    Spacer()
                    
                    Text(displayStatus.createdAt, style: .relative)
                        .font(.roundedCaption)
                        .foregroundStyle(.tertiary)
                }
                
                Text(displayStatus.content.htmlToPlainText)
                    .font(.roundedSubheadline)
                    .lineLimit(3)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Preview would need mock data
            Text("Status Row Preview")
        }
        .padding()
    }
}

