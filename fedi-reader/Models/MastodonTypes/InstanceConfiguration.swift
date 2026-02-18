import Foundation

struct InstanceConfiguration: Codable, Sendable {
    let statuses: StatusConfiguration?
    let mediaAttachments: MediaConfiguration?
    let polls: PollConfiguration?
}


