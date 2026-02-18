import Foundation
import SwiftData

struct InstapaperConfig: Codable, Sendable {
    var username: String
    var oauthToken: String?
    var oauthTokenSecret: String?
}


