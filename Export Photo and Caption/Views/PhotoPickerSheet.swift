import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PhotoPickerSheet: UIViewControllerRepresentable {
    let onComplete: ([SelectedPhotoInput]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: ([SelectedPhotoInput]) -> Void

        init(onComplete: @escaping ([SelectedPhotoInput]) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                onComplete([])
                return
            }

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
                let type = UTType.image.identifier

                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                        guard let data else {
                            continuation.resume(returning: nil)
                            return
                        }
                        continuation.resume(returning: SelectedPhotoInput(localIdentifier: result.assetIdentifier, imageData: data))
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
