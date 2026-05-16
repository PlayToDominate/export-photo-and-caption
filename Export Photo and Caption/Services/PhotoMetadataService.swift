import Foundation
import Photos
import UIKit
import ImageIO

struct PhotoLoadResult {
    let image: UIImage
    let originalFilename: String
    let creationDate: Date?
    let caption: String?
    let captionCandidates: [String: String]
    let metadataKeys: [String]
}

enum PhotoLoadError: LocalizedError {
    case unableToLoadData
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .unableToLoadData:
            return "Unable to load photo data."
        case .invalidImageData:
            return "Loaded data was not a valid image."
        }
    }
}

final class PhotoMetadataService {
    func requestPhotoAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func loadPhoto(from input: SelectedPhotoInput, index: Int) async throws -> ProcessedPhoto {
        let data = input.imageData
        guard let image = UIImage(data: data) else {
            throw PhotoLoadError.invalidImageData
        }

        let asset = fetchAsset(for: input)
        let metadata = parseMetadata(data: data)

        let originalFilename = asset.flatMap(originalFilename(for:)) ?? metadata.originalFilename ?? "photo-\(index + 1).jpg"
        let creationDate = asset?.creationDate ?? metadata.creationDate

        let captionCandidates = buildCaptionCandidates(metadata: metadata.raw)
        let caption = pickBestCaption(captionCandidates)

        return ProcessedPhoto(
            assetLocalIdentifier: input.localIdentifier,
            sourceIndex: index,
            originalFilename: originalFilename,
            creationDate: creationDate,
            caption: caption,
            discoveredCaptionCandidates: captionCandidates,
            discoveredMetadataKeys: metadata.keys,
            sourceImage: image,
            renderedImage: nil,
            renderedFilename: nil
        )
    }

    private func fetchAsset(for input: SelectedPhotoInput) -> PHAsset? {
        guard let id = input.localIdentifier else { return nil }
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        return results.firstObject
    }

    private func originalFilename(for asset: PHAsset) -> String? {
        PHAssetResource.assetResources(for: asset).first?.originalFilename
    }

    private func buildCaptionCandidates(metadata: [String: Any]) -> [String: String] {
        var candidates: [String: String] = [:]

        if let iptc = metadata[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            captureString(in: iptc, key: kCGImagePropertyIPTCCaptionAbstract as String, label: "IPTC Caption")
            captureString(in: iptc, key: kCGImagePropertyIPTCObjectName as String, label: "IPTC Object Name")
        }

        if let tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            captureString(in: tiff, key: kCGImagePropertyTIFFImageDescription as String, label: "TIFF Image Description")
        }

        if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            captureString(in: exif, key: kCGImagePropertyExifUserComment as String, label: "EXIF User Comment")
        }

        func captureString(in dict: [String: Any], key: String, label: String) {
            if let value = dict[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                candidates[label] = value
            }
        }

        return candidates
    }

    private func pickBestCaption(_ candidates: [String: String]) -> String? {
        let orderedKeys = [
            "IPTC Caption",
            "TIFF Image Description",
            "EXIF User Comment",
            "IPTC Object Name"
        ]

        for key in orderedKeys {
            if let value = candidates[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }

    private func parseMetadata(data: Data) -> (raw: [String: Any], keys: [String], creationDate: Date?, originalFilename: String?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return ([:], [], nil, nil)
        }

        var keys = Array(props.keys)

        if let iptc = props[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            keys.append(contentsOf: iptc.keys.map { "IPTC.\($0)" })
        }
        if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            keys.append(contentsOf: exif.keys.map { "EXIF.\($0)" })
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            keys.append(contentsOf: tiff.keys.map { "TIFF.\($0)" })
        }

        let creationDate = parseCreationDate(from: props)
        let filename = (props[kCGImagePropertyFileContentsDictionary as String] as? [String: Any])?["Filename"] as? String

        return (props, Array(Set(keys)).sorted(), creationDate, filename)
    }

    private func parseCreationDate(from props: [String: Any]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

        if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String,
           let date = formatter.date(from: dateString) {
            return date
        }

        if let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateString = tiff[kCGImagePropertyTIFFDateTime as String] as? String,
           let date = formatter.date(from: dateString) {
            return date
        }

        return nil
    }
}
