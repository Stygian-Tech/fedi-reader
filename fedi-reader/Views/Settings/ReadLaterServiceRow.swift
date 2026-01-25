//
//  ReadLaterServiceRow.swift
//  fedi-reader
//
//  Row view for a configured read-later service.
//

import SwiftUI
import SwiftData

struct ReadLaterServiceRow: View {
    let config: ReadLaterConfig
    let serviceType: ReadLaterServiceType
    let isPrimary: Bool

    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            Label(serviceType.displayName, systemImage: serviceType.iconName)

            Spacer()

            if isPrimary {
                Text("Primary")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.clear, in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            if !isPrimary {
                Button {
                    readLaterManager.setPrimaryService(config, modelContext: modelContext)
                } label: {
                    Label("Set as Primary", systemImage: "star")
                }
            }

            Button(role: .destructive) {
                Task {
                    try? await readLaterManager.removeService(config, modelContext: modelContext)
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}
