import Foundation
import UIKit

struct ProcessedPhoto: Identifiable {
    let id = UUID()
    let assetLocalIdentifier: String?
    let sourceIndex: Int

    var originalFilename: String
    var creationDate: Date?
    var caption: String?
    var discoveredCaptionCandidates: [String: String]
    var discoveredMetadataKeys: [String]

    var sourceImage: UIImage
    var renderedImage: UIImage?
    var renderedFilename: String?

    var effectiveCaption: String {
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "No caption found" : trimmed
    }
}
