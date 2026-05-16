import SwiftUI

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var photo: ProcessedPhoto
    @State private var draftCaption: String = ""
    @State private var showSavedConfirmation = false
    @State private var showMoreInfo = false
    @FocusState private var isCaptionFieldFocused: Bool

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
                row("Creation Date", formatted(date: photo.creationDate))
                row("Original Caption", photo.caption ?? "No caption found")
            }

            Section("Caption Override") {
                TextField("Type caption override...", text: $draftCaption, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($isCaptionFieldFocused)
                Text("This only changes export text in the app. Your original photo metadata is unchanged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Save Caption") {
                    let trimmed = draftCaption.trimmingCharacters(in: .whitespacesAndNewlines)
                    photo.captionOverride = trimmed.isEmpty ? nil : draftCaption
                    showSavedConfirmation = true
                    isCaptionFieldFocused = false
                }
                .buttonStyle(.borderedProminent)

                if showSavedConfirmation {
                    Label("Caption saved for this photo.", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                if !(photo.captionOverride?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                    Button("Clear Saved Override", role: .destructive) {
                        photo.captionOverride = nil
                        draftCaption = photo.caption ?? ""
                        showSavedConfirmation = false
                    }
                }
            }

            Section {
                DisclosureGroup("More Photo Information", isExpanded: $showMoreInfo) {
                    VStack(alignment: .leading, spacing: 10) {
                        row("PHAsset Identifier", photo.assetLocalIdentifier ?? "n/a")
                        row("Using For Export", photo.effectiveCaption)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Caption Candidates")
                                .font(.subheadline.weight(.semibold))
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

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Metadata Keys")
                                .font(.subheadline.weight(.semibold))
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
                }
            }
        }
        .navigationTitle("Photo Debug")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            .frame(width: 36, height: 36)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(CircleIconButtonStyle())
                .accessibilityLabel("Close")
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isCaptionFieldFocused = false
                }
            }
        }
        .onAppear {
            draftCaption = photo.captionOverride ?? photo.caption ?? ""
        }
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

private struct CircleIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
