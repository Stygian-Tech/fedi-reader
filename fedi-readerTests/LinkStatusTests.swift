import Testing
import Foundation
@testable import fedi_reader

@Suite("Link Status Tests")
struct LinkStatusTests {
    
    @Test("LinkStatus correctly extracts domain")
    func linkStatusExtractsDomain() {
        let status = MockStatusFactory.makeStatus(hasCard: true, cardURL: "https://example.com/article")
        let linkStatus = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com/article")!,
            title: "Test"
        )
        
        #expect(linkStatus.domain == "example.com")
    }
    
    @Test("LinkStatus uses title for displayTitle")
    func linkStatusDisplayTitle() {
        let status = MockStatusFactory.makeStatus()
        let linkStatus = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            title: "My Article"
        )
        
        #expect(linkStatus.displayTitle == "My Article")
    }
    
    @Test("LinkStatus falls back to host for displayTitle")
    func linkStatusDisplayTitleFallback() {
        let status = MockStatusFactory.makeStatus()
        let linkStatus = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            title: nil
        )
        
        #expect(linkStatus.displayTitle == "example.com")
    }
    
    @Test("LinkStatus hasImage property")
    func linkStatusHasImage() {
        let status = MockStatusFactory.makeStatus()
        
        let withImage = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            imageURL: URL(string: "https://example.com/image.jpg")
        )
        
        let withoutImage = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            imageURL: nil
        )
        
        #expect(withImage.hasImage == true)
        #expect(withoutImage.hasImage == false)
    }

    @Test("LinkStatus uses metadata description for displayDescription")
    func linkStatusDisplayDescriptionUsesMetadata() {
        let status = MockStatusFactory.makeStatus(content: "<p>Post body content</p>")
        let linkStatus = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            description: "Preview description"
        )

        #expect(linkStatus.displayDescription == "Preview description")
    }

    @Test("LinkStatus does not fall back to post content for displayDescription")
    func linkStatusDisplayDescriptionNoPostFallback() {
        let status = MockStatusFactory.makeStatus(content: "<p>Post body content</p>")
        let linkStatus = LinkStatus(
            status: status,
            primaryURL: URL(string: "https://example.com")!,
            description: nil
        )

        #expect(linkStatus.displayDescription == nil)
    }
}

