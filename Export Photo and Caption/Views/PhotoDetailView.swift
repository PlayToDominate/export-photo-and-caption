import SwiftUI

struct PhotoDetailView: View {
    let photo: ProcessedPhoto

    var body: some View {
        List {
            Section("Preview") {
                Image(uiImage: photo.sourceImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .frame(maxWidth: .infinity)
            }

            Section("Detected Values") {
                row("Filename", photo.originalFilename)
                row("PHAsset Identifier", photo.assetLocalIdentifier ?? "n/a")
                row("Creation Date", formatted(date: photo.creationDate))
                row("Chosen Caption", photo.caption ?? "No caption found")
            }

            Section("Caption Candidates") {
                if photo.discoveredCaptionCandidates.isEmpty {
                    Text("No caption-like metadata fields found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(photo.discoveredCaptionCandidates.keys.sorted(), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key).font(.caption).foregroundStyle(.secondary)
                            Text(photo.discoveredCaptionCandidates[key] ?? "")
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Metadata Keys") {
                if photo.discoveredMetadataKeys.isEmpty {
                    Text("No metadata keys discovered")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(photo.discoveredMetadataKeys, id: \.self) { key in
                        Text(key)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Photo Debug")
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private func formatted(date: Date?) -> String {
        guard let date else { return "n/a" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
