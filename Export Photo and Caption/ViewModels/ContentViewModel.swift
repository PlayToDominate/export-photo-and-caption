import Foundation
import Photos
import UIKit

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var selectedInputs: [SelectedPhotoInput] = []
    @Published var photos: [ProcessedPhoto] = []
    @Published var selectedAlbumName = "Captioned Export"
    @Published var isLoading = false
    @Published var isExporting = false
    @Published var lastError: String?
    @Published var showShareSheet = false
    @Published var shareURLs: [URL] = []

    private let metadataService = PhotoMetadataService()
    private let renderer = PolaroidRenderer()
    private let filenameBuilder = FilenameBuilder()

    func requestPermission() async {
        authorizationStatus = await metadataService.requestPhotoAuthorization()
    }

    func loadPickerItems() async {
        isLoading = true
        defer { isLoading = false }

        var loaded: [ProcessedPhoto] = []
        for (index, input) in selectedInputs.enumerated() {
            do {
                let photo = try await metadataService.loadPhoto(from: input, index: index)
                loaded.append(photo)
            } catch {
                lastError = error.localizedDescription
            }
        }

        photos = loaded
    }

    func generateStyledImages() {
        var updated: [ProcessedPhoto] = []
        for var photo in photos {
            let rendered = renderer.render(image: photo.sourceImage, caption: photo.effectiveCaption)
            photo.renderedImage = rendered
            photo.renderedFilename = filenameBuilder.buildFilename(for: photo)
            updated.append(photo)
        }
        photos = updated
    }

    func saveToAlbum() async {
        guard !photos.isEmpty else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let album = try await createOrFetchAlbum(named: selectedAlbumName)
            try await saveRenderedImages(to: album)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func prepareShare() {
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("captioned-export", isDirectory: true)
            if FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.removeItem(at: dir)
            }
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            var urls: [URL] = []
            for (index, photo) in photos.enumerated() {
                let image = photo.renderedImage ?? photo.sourceImage
                let filename = photo.renderedFilename ?? "export-\(index + 1).jpg"
                let fileURL = dir.appendingPathComponent(filename)
                guard let data = image.jpegData(compressionQuality: 0.95) else { continue }
                try data.write(to: fileURL, options: .atomic)
                urls.append(fileURL)
            }

            shareURLs = urls
            showShareSheet = !urls.isEmpty
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func createOrFetchAlbum(named name: String) async throws -> PHAssetCollection {
        if let existing = fetchAlbum(named: name) {
            return existing
        }

        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = request.placeholderForCreatedAssetCollection
        }

        guard let localId = placeholder?.localIdentifier else {
            throw NSError(domain: "Album", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create album"])
        }

        let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localId], options: nil)
        guard let collection = result.firstObject else {
            throw NSError(domain: "Album", code: 2, userInfo: [NSLocalizedDescriptionKey: "Created album not found"])
        }
        return collection
    }

    private func fetchAlbum(named name: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        return albums.firstObject
    }

    private func saveRenderedImages(to album: PHAssetCollection) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            guard let albumChange = PHAssetCollectionChangeRequest(for: album) else { return }

            var placeholders: [PHObjectPlaceholder] = []
            for photo in self.photos {
                let image = photo.renderedImage ?? photo.sourceImage
                guard let data = image.jpegData(compressionQuality: 0.95) else { continue }

                let createRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = photo.renderedFilename
                createRequest.addResource(with: .photo, data: data, options: options)
                if let creationDate = photo.creationDate {
                    createRequest.creationDate = creationDate
                }
                if let ph = createRequest.placeholderForCreatedAsset {
                    placeholders.append(ph)
                }
            }

            albumChange.addAssets(placeholders as NSFastEnumeration)
        }
    }
}
