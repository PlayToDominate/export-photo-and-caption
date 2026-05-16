import SwiftUI
@preconcurrency import PhotosUI
import UniformTypeIdentifiers

struct PhotoPickerSheet: UIViewControllerRepresentable {
    let onProcessingStart: (Int) -> Void
    let onComplete: ([SelectedPhotoInput]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .images
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onProcessingStart: onProcessingStart, onComplete: onComplete)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onProcessingStart: (Int) -> Void
        let onComplete: ([SelectedPhotoInput]) -> Void

        init(onProcessingStart: @escaping (Int) -> Void, onComplete: @escaping ([SelectedPhotoInput]) -> Void) {
            self.onProcessingStart = onProcessingStart
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                onComplete([])
                return
            }

            onProcessingStart(results.count)

            Task {
                var loaded: [SelectedPhotoInput] = []
                for result in results {
                    if let input = await loadInput(from: result) {
                        loaded.append(input)
                    }
                }
                await MainActor.run {
                    onComplete(loaded)
                }
            }
        }

        private func loadInput(from result: PHPickerResult) async -> SelectedPhotoInput? {
            await withCheckedContinuation { continuation in
                let provider = result.itemProvider
                let candidateTypes = [UTType.image.identifier] + provider.registeredTypeIdentifiers
                guard let type = candidateTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                    continuation.resume(returning: nil)
                    return
                }

                provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                    guard let data else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: SelectedPhotoInput(localIdentifier: result.assetIdentifier, imageData: data))
                }
            }
        }
    }
}
