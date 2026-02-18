import Foundation

struct MediaConfiguration: Codable, Sendable {
    let supportedMimeTypes: [String]?
    let imageSizeLimit: Int?
    let imageMatrixLimit: Int?
    let videoSizeLimit: Int?
    let videoFrameRateLimit: Int?
    let videoMatrixLimit: Int?
    
    enum CodingKeys: String, CodingKey {
        case supportedMimeTypes = "supported_mime_types"
        case imageSizeLimit = "image_size_limit"
        case imageMatrixLimit = "image_matrix_limit"
        case videoSizeLimit = "video_size_limit"
        case videoFrameRateLimit = "video_frame_rate_limit"
        case videoMatrixLimit = "video_matrix_limit"
    }
}


