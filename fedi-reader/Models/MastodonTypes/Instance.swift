import Foundation

struct Instance: Codable, Sendable {
    let uri: String
    let title: String
    let shortDescription: String?
    let description: String
    let email: String?
    let version: String
    let urls: InstanceURLs?
    let stats: InstanceStats?
    let thumbnail: String?
    let languages: [String]?
    let registrations: Bool?
    let approvalRequired: Bool?
    let invitesEnabled: Bool?
    let configuration: InstanceConfiguration?
    let contactAccount: MastodonAccount?
    let rules: [InstanceRule]?
    
    enum CodingKeys: String, CodingKey {
        case uri, title, description, email, version, urls, stats, thumbnail, languages, registrations, configuration, rules
        case shortDescription = "short_description"
        case approvalRequired = "approval_required"
        case invitesEnabled = "invites_enabled"
        case contactAccount = "contact_account"
    }
}


