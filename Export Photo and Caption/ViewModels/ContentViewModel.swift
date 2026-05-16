import Foundation
import Photos
import UIKit

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var selectedInputs: [SelectedPhotoInput] = []
    @Published var photos: [ProcessedPhoto] = []
    @Published var selectedAlbumName = "Captioned Export"
    @Published var isLoading = false
    @Published var isExporting = false
    @Published var alertMessage: AlertMessage?
    @Published var showShareSheet = false
    @Published var shareURLs: [URL] = []
    @Published var generationStatusMessage: String?
    @Published var saveStatusMessage: String?
    @Published var captionFont: CaptionFontOption = .system
    @Published var exportSummary = ExportSummary()
    @Published var loadProgressProcessed: Int = 0
    @Published var loadProgressTotal: Int = 0

    private let metadataService = PhotoMetadataService()
    private let renderer = CaptionedPhotoRenderer()
    private let filenameBuilder = FilenameBuilder()
    private var activeLoadToken = UUID()

    func requestPermission() async {
        authorizationStatus = await metadataService.requestPhotoAuthorization()
    }

    func beginPickerProcessing(expectedCount: Int) {
        isLoading = true
        loadProgressTotal = max(expectedCount, 1)
        loadProgressProcessed = 0
    }

    func loadPickerItems() async {
        let loadToken = UUID()
        activeLoadToken = loadToken

        let batchSize = 12

        guard !selectedInputs.isEmpty else {
            photos = []
            generationStatusMessage = nil
            saveStatusMessage = nil
            loadProgressProcessed = 0
            loadProgressTotal = 0
            return
        }

        isLoading = true
        loadProgressTotal = selectedInputs.count
        loadProgressProcessed = 0
        defer {
            isLoading = false
            loadProgressProcessed = 0
            loadProgressTotal = 0
        }

        var loaded: [ProcessedPhoto] = []
        var skippedFromExportAlbum = 0

        for chunkStart in stride(from: 0, to: selectedInputs.count, by: batchSize) {
            let chunkEnd = min(chunkStart + batchSize, selectedInputs.count)
            let chunk = Array(selectedInputs[chunkStart..<chunkEnd])

            for (offset, input) in chunk.enumerated() {
                let index = chunkStart + offset

                if isInputFromExportAlbum(input) {
                    skippedFromExportAlbum += 1
                    loadProgressProcessed += 1
                    continue
                }

                do {
                    let photo = try await metadataService.loadPhoto(from: input, index: index)
                    loaded.append(photo)
                } catch {
                    presentError(error.localizedDescription)
                }

                loadProgressProcessed += 1
            }

            if loadToken != activeLoadToken { return }
            await Task.yield()
        }

        guard loadToken == activeLoadToken else { return }

        photos = loaded
        generationStatusMessage = nil
        saveStatusMessage = nil
        exportSummary = ExportSummary(skippedCount: skippedFromExportAlbum)

        if loaded.isEmpty {
            presentError("No selected photos could be loaded. Try selecting a different photo format or expanding Photos access.")
        }

        if skippedFromExportAlbum > 0 {
            presentError("Skipped \(skippedFromExportAlbum) photo\(skippedFromExportAlbum == 1 ? "" : "s") from the Captioned Export album to avoid re-processing exports.")
        }
    }

    func generateStyledImages() {
        guard !photos.isEmpty else {
            generationStatusMessage = "No photos selected to generate."
            return
        }

        var updated: [ProcessedPhoto] = []
        for var photo in photos {
            let rendered = renderer.render(image: photo.sourceImage, caption: photo.effectiveCaption, captionFont: captionFont)
            photo.renderedImage = rendered
            photo.renderedFilename = filenameBuilder.buildFilename(for: photo)
            updated.append(photo)
        }
        photos = updated
        generationStatusMessage = "Generated \(updated.count) captioned photo\(updated.count == 1 ? "" : "s")."
        exportSummary.generatedCount = updated.count
    }

    func generateAndSaveToAlbum() async {
        guard !photos.isEmpty else {
            generationStatusMessage = "No photos selected to generate."
            return
        }

        generateStyledImages()
        await saveToAlbum()
    }

    func removePhoto(_ photo: ProcessedPhoto) {
        photos.removeAll { $0.id == photo.id }
        selectedInputs.removeAll { $0.localIdentifier == photo.assetLocalIdentifier }

        if photos.isEmpty {
            generationStatusMessage = nil
            saveStatusMessage = nil
        }
    }

    func clearSelectedPhotos() {
        activeLoadToken = UUID()
        photos = []
        selectedInputs = []
        shareURLs = []
        showShareSheet = false
        isLoading = false
        isExporting = false
        generationStatusMessage = nil
        saveStatusMessage = nil
        exportSummary = ExportSummary()
        alertMessage = nil
    }

    func saveToAlbum() async {
        guard !photos.isEmpty else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let album = try await createOrFetchAlbum(named: selectedAlbumName)
            let savedCount = try await saveRenderedImages(to: album)
            saveStatusMessage = "Photo\(savedCount == 1 ? "" : "s") saved to album \"\(selectedAlbumName)\"."
            exportSummary.savedCount = savedCount
        } catch {
            presentError(error.localizedDescription)
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
            presentError(error.localizedDescription)
        }
    }

    private func presentError(_ message: String) {
        alertMessage = AlertMessage(title: "Error", message: message)
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

    private func isInputFromExportAlbum(_ input: SelectedPhotoInput) -> Bool {
        guard let localIdentifier = input.localIdentifier else { return false }
        guard let exportAlbum = fetchAlbum(named: selectedAlbumName) else { return false }

        let target = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = target.firstObject else { return false }

        let albumAssets = PHAsset.fetchAssets(in: exportAlbum, options: nil)
        var found = false
        albumAssets.enumerateObjects { item, _, stop in
            if item.localIdentifier == asset.localIdentifier {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    private func saveRenderedImages(to album: PHAssetCollection) async throws -> Int {
        var savedCount = 0
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

            savedCount = placeholders.count

            albumChange.addAssets(placeholders as NSFastEnumeration)
        }
        return savedCount
    }
}
