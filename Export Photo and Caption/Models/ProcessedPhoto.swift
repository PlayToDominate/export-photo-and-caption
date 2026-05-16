import Foundation
import UIKit

struct ProcessedPhoto: Identifiable {
    let id = UUID()
    let assetLocalIdentifier: String?
    let sourceIndex: Int

    var originalFilename: String
    var creationDate: Date?
    var caption: String?
    var captionOverride: String?
    var discoveredCaptionCandidates: [String: String]
    var discoveredMetadataKeys: [String]

    var sourceImage: UIImage
    var renderedImage: UIImage?
    var renderedFilename: String?
    var renderedFileURL: URL?

    var effectiveCaption: String {
        let overrideTrimmed = captionOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !overrideTrimmed.isEmpty { return overrideTrimmed }

        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed
    }

    var captionForExportSlug: String? {
        let overrideTrimmed = captionOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !overrideTrimmed.isEmpty { return overrideTrimmed }

        let detectedTrimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return detectedTrimmed.isEmpty ? nil : detectedTrimmed
    }
}
