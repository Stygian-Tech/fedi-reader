//
//  StatusDetailView.swift
//  fedi-reader
//
//  Full status detail with thread context (ancestors, replies).
//

import SwiftUI

struct StatusDetailRowView: View {
    let status: Status
    @Environment(AppState.self) private var appState

    @State private var fediverseCreatorName: String?
    @State private var fediverseCreatorURL: URL?

    var displayStatus: Status {
        status.displayStatus
    }

    private var cardURL: URL? {
        guard let card = displayStatus.card, (card.type == .link || card.type == .rich) else { return nil }
        return card.linkURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if status.isReblog {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.roundedCaption)

                    Text("\(status.account.displayName) boosted")
                        .font(.roundedCaption)
                }
                .foregroundStyle(.secondary)
                .padding(.leading, Constants.UI.avatarSize + 10)
            }

            HStack(spacing: 10) {
                Button {
                    appState.navigate(to: .profile(displayStatus.account))
                } label: {
                    ProfileAvatarView(url: displayStatus.account.avatarURL, size: Constants.UI.avatarSize)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(displayStatus.account.displayName)
                            .font(.roundedSubheadline.bold())
                            .lineLimit(1)

                        AccountBadgesView(account: displayStatus.account, size: .small)
                    }
                }

                Spacer()

                Text(TimeFormatter.relativeTimeString(from: displayStatus.createdAt))
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)
            }

            if !displayStatus.spoilerText.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text(displayStatus.spoilerText)
                        .font(.roundedSubheadline.bold())
                }
                .padding()
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if #available(iOS 15.0, macOS 12.0, *) {
                Text(displayStatus.content.htmlToAttributedString)
                    .font(.roundedBody)
            } else {
                Text(displayStatus.content.htmlToPlainText)
                    .font(.roundedBody)
            }

            if !displayStatus.mediaAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayStatus.mediaAttachments) { attachment in
                            AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if let card = displayStatus.card, card.type == .link {
                Button {
                    if let url = card.linkURL {
                        appState.navigate(to: .article(url: url, status: status))
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let imageURL = card.imageURL {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                            .frame(width: 80, height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.roundedSubheadline.bold())
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if !card.description.isEmpty {
                                Text(card.description)
                                    .font(.roundedCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.roundedCaption2)

                                Text(card.providerName ?? HTMLParser.extractDomain(from: URL(string: card.url)!) ?? card.url)
                                    .font(.roundedCaption)
                                    .lineLimit(1)

                                if let authorName = fediverseCreatorName,
                                   let authorURL = fediverseCreatorURL {
                                    Link(destination: authorURL) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.crop.circle")
                                                .font(.roundedCaption2)

                                            Text(authorName)
                                                .font(.roundedCaption)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.tertiarySystemBackground), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                } else if let authorName = fediverseCreatorName {
                                    Text(authorName)
                                        .font(.roundedCaption)
                                        .lineLimit(1)
                                } else if let authorName = card.authorName,
                                          let authorUrlString = card.authorUrl,
                                          let authorURL = URL(string: authorUrlString) {
                                    Link(destination: authorURL) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.crop.circle")
                                                .font(.roundedCaption2)

                                            Text(authorName)
                                                .font(.roundedCaption)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.tertiarySystemBackground), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                } else if let author = card.authorName {
                                    Text(author)
                                        .font(.roundedCaption)
                                        .lineLimit(1)
                                }
                            }
                            .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .task(id: cardURL?.absoluteString) {
                    guard let url = cardURL else { return }
                    let creator = await LinkPreviewService.shared.fetchFediverseCreator(for: url)
                    fediverseCreatorName = creator?.name
                    fediverseCreatorURL = creator?.url
                }
            }

            StatusActionsBar(status: status, size: .detail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
    }
}

struct StatusDetailView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var context: StatusContext?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StatusDetailRowView(status: status)
                    .padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let context = context {
                    if !context.ancestors.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Thread")
                                .font(.roundedHeadline)
                                .padding(.horizontal)
                                .padding(.bottom, 8)

                            ForEach(context.ancestors) { ancestor in
                                StatusDetailRowView(status: ancestor)
                                    .padding(.horizontal)
                                Divider()
                            }
                        }
                    }

                    if !context.descendants.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Replies")
                                .font(.roundedHeadline)
                                .padding(.horizontal)
                                .padding(.vertical, 8)

                            ForEach(context.descendants) { descendant in
                                StatusDetailRowView(status: descendant)
                                    .padding(.horizontal)
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContext()
        }
    }

    private func loadContext() async {
        guard let service = timelineWrapper.service else {
            isLoading = false
            return
        }

        do {
            context = try await service.getStatusContext(for: status)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
