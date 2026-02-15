//
//  ProfileDetailView.swift
//  fedi-reader
//
//  Profile view for other users (MastodonAccount).
//

import SwiftUI

struct ProfileDetailView: View {
    let account: MastodonAccount

    var body: some View {
        ScrollView {
            ProfileSummaryView(account: account, fields: account.preferredFields)
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(account.displayName)
                    .font(.roundedHeadline)
            }

            ToolbarItem(placement: .primaryAction) {
                Link(destination: URL(string: account.url)!) {
                    Image(systemName: "safari")
                }
            }
        }
    }
}
