//
//  ReadLaterSettingsView.swift
//  fedi-reader
//
//  Read Later service configuration view.
//

import SwiftUI
import SwiftData

struct ReadLaterSettingsView: View {
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            if !readLaterManager.configuredServices.isEmpty {
                Section("Configured Services") {
                    ForEach(readLaterManager.configuredServices, id: \.id) { config in
                        if let serviceType = config.service {
                            ReadLaterServiceRow(
                                config: config,
                                serviceType: serviceType,
                                isPrimary: config.isPrimary
                            )
                        }
                    }
                    .onDelete(perform: removeServices)
                }
            }

            Section("Add Service") {
                ForEach(ReadLaterServiceType.allCases) { serviceType in
                    if !isServiceConfigured(serviceType) {
                        Button {
                            appState.present(sheet: .readLaterLogin(serviceType))
                        } label: {
                            Label(serviceType.displayName, systemImage: serviceType.iconName)
                        }
                    }
                }
            }

            Section {
                Text("Read-later services let you save articles for later reading. Configure your preferred service to enable quick-save from the link feed.")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Read Later")
    }

    private func isServiceConfigured(_ serviceType: ReadLaterServiceType) -> Bool {
        readLaterManager.configuredServices.contains { $0.service == serviceType }
    }

    private func removeServices(at offsets: IndexSet) {
        for index in offsets {
            let config = readLaterManager.configuredServices[index]
            Task {
                try? await readLaterManager.removeService(config, modelContext: modelContext)
            }
        }
    }
}
