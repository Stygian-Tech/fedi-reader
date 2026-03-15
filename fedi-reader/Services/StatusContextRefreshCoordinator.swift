import Foundation
import os

actor StatusContextRefreshCoordinator {
    typealias PublishUpdate = @Sendable (StatusContextUpdatePayload) async -> Void

    private struct ScheduledRefresh {
        let id: UUID
        let task: Task<Void, Never>
    }

    private static let logger = Logger(subsystem: "app.fedi-reader", category: "StatusContextRefreshCoordinator")

    private let client: MastodonClient
    private let authService: AuthService
    private let remoteReplyService: RemoteReplyService
    private var scheduledRefreshes: [String: ScheduledRefresh] = [:]

    init(client: MastodonClient, authService: AuthService, remoteReplyService: RemoteReplyService) {
        self.client = client
        self.authService = authService
        self.remoteReplyService = remoteReplyService
    }

    func scheduleAsyncRefreshPolling(
        for status: Status,
        header: AsyncRefreshHeader,
        instance: String,
        token: String,
        publish: @escaping PublishUpdate
    ) {
        scheduleRefresh(forStatusId: status.id) { [weak self] refreshID in
            guard let self else { return }
            await self.runAsyncRefreshPolling(
                refreshID: refreshID,
                status: status,
                header: header,
                instance: instance,
                token: token,
                publish: publish
            )
        }
    }

    func scheduleFallbackRemoteReplyFetch(
        for status: Status,
        context: StatusContext,
        publish: @escaping PublishUpdate
    ) {
        scheduleRefresh(forStatusId: status.id) { [weak self] refreshID in
            guard let self else { return }
            await self.runFallbackRemoteReplyFetch(
                refreshID: refreshID,
                status: status,
                context: context,
                publish: publish
            )
        }
    }

    func cancelRefresh(forStatusId statusId: String) {
        scheduledRefreshes[statusId]?.task.cancel()
        scheduledRefreshes.removeValue(forKey: statusId)
    }

    private func scheduleRefresh(
        forStatusId statusId: String,
        operation: @escaping @Sendable (UUID) async -> Void
    ) {
        cancelRefresh(forStatusId: statusId)

        let refreshID = UUID()
        let task = Task(priority: .utility) {
            await operation(refreshID)
        }
        scheduledRefreshes[statusId] = ScheduledRefresh(id: refreshID, task: task)
    }

    private func runAsyncRefreshPolling(
        refreshID: UUID,
        status: Status,
        header: AsyncRefreshHeader,
        instance: String,
        token: String,
        publish: @escaping PublishUpdate
    ) async {
        defer { finishRefresh(refreshID: refreshID, forStatusId: status.id) }

        var attempts = 0
        let maxAttempts = Constants.RemoteReplies.asyncRefreshMaxPollAttempts

        while !Task.isCancelled, attempts < maxAttempts {
            do {
                let refresh = try await client.getAsyncRefreshInBackground(
                    instance: instance,
                    accessToken: token,
                    id: header.id
                )
                if refresh.status == "finished" {
                    Self.logger.info("Async refresh finished for status \(status.id.prefix(8), privacy: .public)")
                    break
                }
            } catch let error as FediReaderError {
                if case .serverError(404, _) = error {
                    Self.logger.debug("Async refresh 404 for id \(header.id.prefix(12), privacy: .public), stopping poll")
                    break
                }
                Self.logger.debug("Async refresh poll error: \(error.localizedDescription)")
            } catch {
                Self.logger.debug("Async refresh poll error: \(error.localizedDescription)")
            }

            attempts += 1
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: UInt64(header.retrySeconds) * 1_000_000_000)
        }

        if Task.isCancelled { return }

        do {
            guard let session = await authService.activeSessionSnapshot() else { return }
            let contextWithRefresh = try await client.getStatusContextWithRefreshInBackground(
                instance: session.instance,
                accessToken: session.accessToken,
                id: status.id
            )
            if Task.isCancelled { return }
            await publish(
                StatusContextUpdatePayload(statusId: status.id, context: contextWithRefresh.context)
            )
        } catch {
            Self.logger.error("Failed to re-fetch context after async refresh: \(error.localizedDescription)")
        }
    }

    private func runFallbackRemoteReplyFetch(
        refreshID: UUID,
        status: Status,
        context: StatusContext,
        publish: @escaping PublishUpdate
    ) async {
        defer { finishRefresh(refreshID: refreshID, forStatusId: status.id) }

        guard let updatedContext = await remoteReplyService.fetchRemoteReplyContext(
            for: status,
            initialContext: context
        ) else {
            return
        }

        if Task.isCancelled { return }
        await publish(StatusContextUpdatePayload(statusId: status.id, context: updatedContext))
    }

    private func finishRefresh(refreshID: UUID, forStatusId statusId: String) {
        guard scheduledRefreshes[statusId]?.id == refreshID else {
            return
        }
        scheduledRefreshes.removeValue(forKey: statusId)
    }
}
