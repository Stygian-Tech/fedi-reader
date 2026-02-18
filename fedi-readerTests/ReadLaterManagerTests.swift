import Testing
import Foundation
@testable import fedi_reader

@Suite("Read Later Manager Tests")
@MainActor
struct ReadLaterManagerTests {
    @Test("save posts failure notification when service is not configured")
    func savePostsFailureNotificationWhenServiceMissing() async {
        let manager = ReadLaterManager()
        let articleURL = URL(string: "https://example.com/article")!
        let resultStore = NotificationResultStore()
        
        let observer = NotificationCenter.default.addObserver(
            forName: .readLaterDidSave,
            object: nil,
            queue: nil
        ) { notification in
            resultStore.set(notification.object as? ReadLaterSaveResult)
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        do {
            try await manager.save(url: articleURL, title: "Example", to: .instapaper)
            Issue.record("Expected save to throw when Instapaper is not configured")
        } catch {
            // Expected path
        }
        
        let receivedResult = resultStore.get()
        #expect(receivedResult != nil)
        #expect(receivedResult?.success == false)
        #expect(receivedResult?.serviceType == .instapaper)
        #expect(receivedResult?.url == articleURL)
    }
}


