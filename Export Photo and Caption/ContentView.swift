import SwiftUI
import Photos
import UIKit

struct ContentView: View {
    private enum NavigationDirection {
        case forward
        case backward
    }

    private struct DetailSelection: Identifiable {
        let id: UUID
    }

    @StateObject private var model = ContentViewModel()
    @State private var showPicker = false
    @State private var step: Int = {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return 1
        default:
            return 0
        }
    }()
    @State private var selectedDetailSelection: DetailSelection?
    @State private var navigationDirection: NavigationDirection = .forward
    private let maxStep = 2

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                goBack()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Circle()
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .accessibilityLabel("Back")
                            }
                            .buttonStyle(CircleBackButtonStyle())
                            .opacity(step == 0 ? 0 : 1)
                            .disabled(step == 0)

                            Spacer()
                        }

                        HStack {
                            Text("Captioned Photos")
                                .font(.title2.weight(.semibold))
                            Spacer()
                            Text("Step \(step + 1)/3")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    ZStack {
                        if step == 0 {
                            permissionPage
                                .transition(stepTransition)
                        } else if step == 1 {
                            selectPage
                                .transition(stepTransition)
                        } else {
                            styleGeneratePage
                                .transition(stepTransition)
                        }
                    }
                    .id(step)
                    .animation(.easeInOut(duration: 0.28), value: step)

                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(index == step ? Color.white : Color.white.opacity(0.35))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 18)
                        .contentShape(Rectangle())
                        .gesture(stepSwipeGesture)

                    Spacer()

                    Color.clear
                        .frame(height: 14)
                        .contentShape(Rectangle())
                        .gesture(stepSwipeGesture)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
            }
            .alert(item: $model.alertMessage) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $model.showShareSheet) {
                ShareSheet(items: model.shareURLs)
            }
            .sheet(isPresented: $showPicker) {
                PhotoPickerSheet(onProcessingStart: { count in
                    model.beginPickerProcessing(expectedCount: count)
                }, onComplete: { inputs in
                    guard !inputs.isEmpty else { return }

                    var merged = model.selectedInputs
                    for input in inputs {
                        let exists = merged.contains { existing in
                            if let a = existing.localIdentifier, let b = input.localIdentifier {
                                return a == b
                            }
                            return existing.imageData == input.imageData
                        }
                        if !exists {
                            merged.append(input)
                        }
                    }

                    model.selectedInputs = merged
                    Task { await model.loadPickerItems() }
                })
            }
            .sheet(item: $selectedDetailSelection) { selection in
                if let index = model.photos.firstIndex(where: { $0.id == selection.id }) {
                    NavigationStack {
                        PhotoDetailView(photo: $model.photos[index])
                    }
                } else {
                    NavigationStack {
                        Text("Photo not found")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: model.authorizationStatus) { _ in
                if isAuthorized, step == 0 {
                    setStep(1)
                }
            }
        }
    }

    private var permissionPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allow photo access to read metadata and save generated captioned photos to your album.")
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: permissionIcon)
                    .foregroundStyle(permissionIconColor)
                Text(permissionText)
                    .foregroundStyle(.secondary)
            }

            if isAuthorized {
                Label("Permission granted", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Button("Next") {
                    setStep(1)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Request Photos Access") {
                    Task { await model.requestPermission() }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick one or more photos to process.")
                .foregroundStyle(.secondary)

            Button {
                showPicker = true
            } label: {
                Label("Pick Photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)

            Button("Update Photo Access") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(.footnote)

            if model.isLoading {
                ProgressView(value: Double(model.loadProgressProcessed), total: Double(max(model.loadProgressTotal, 1))) {
                    Text("Reading selected photos...")
                } currentValueLabel: {
                    Text("Loaded \(model.loadProgressProcessed) of \(model.loadProgressTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Selected: \(model.photos.count)")
                    .foregroundStyle(.secondary)
            }

            List {
                if model.photos.isEmpty {
                    if model.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Working...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No photos selected yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(model.photos) { photo in
                        HStack {
                            Image(uiImage: photo.sourceImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipped()
                                .cornerRadius(6)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(photo.originalFilename).lineLimit(1)
                                Group {
                                    if photo.effectiveCaption.isEmpty {
                                        Text("No caption found")
                                            .italic()
                                    } else {
                                        Text(photo.effectiveCaption)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDetailSelection = DetailSelection(id: photo.id)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                model.removePhoto(photo)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)

            Button("Next") {
                setStep(2)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.photos.isEmpty)

        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var styleGeneratePage: some View {
        let hasGeneratedImages = model.photos.contains { $0.renderedImage != nil }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Choose caption font, preview style, then generate and save.")
                .foregroundStyle(.secondary)

            Menu {
                ForEach(CaptionFontOption.allCases) { option in
                    Button {
                        model.captionFont = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                                .font(option.previewFont)
                            if option == model.captionFont {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Caption Font")
                    Spacer()
                    Text(model.captionFont.rawValue)
                        .font(model.captionFont.previewFont)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Preview: The quick brown fox jumps over the lazy dog")
                .font(model.captionFont.previewFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button(model.isExporting ? "Generating + Saving..." : "Generate Captioned Photos") {
                Task { await model.generateAndSaveToAlbum() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(model.photos.isEmpty || model.isExporting)

            if let status = model.generationStatusMessage {
                Label(status, systemImage: "checkmark.seal")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let saveStatus = model.saveStatusMessage {
                Label(saveStatus, systemImage: "photo.on.rectangle.angled")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if model.exportSummary.hasData {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Export Summary")
                        .font(.headline)
                    Text("Generated: \(model.exportSummary.generatedCount)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Saved: \(model.exportSummary.savedCount)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.exportSummary.skippedCount > 0 {
                        Text("Skipped: \(model.exportSummary.skippedCount) (already in export album)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }

            HStack {
                Button("Start Over", role: .destructive) {
                    model.clearSelectedPhotos()
                    setStep(isAuthorized ? 1 : 0)
                }
                .buttonStyle(.bordered)
                .disabled(model.photos.isEmpty)

                Spacer()

                Button("Share Exported Files") {
                    model.prepareShare()
                }
                .buttonStyle(.bordered)
                .disabled(!hasGeneratedImages || model.isExporting)
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var isAuthorized: Bool {
        model.authorizationStatus == .authorized || model.authorizationStatus == .limited
    }

    private func goBack() {
        setStep(step - 1)
    }

    private func goNext() {
        setStep(step + 1)
    }

    private var stepTransition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private func setStep(_ target: Int) {
        let clamped = min(max(target, 0), maxStep)
        guard clamped != step else { return }
        navigationDirection = clamped > step ? .forward : .backward
        withAnimation(.easeInOut(duration: 0.28)) {
            step = clamped
        }
    }

    private var stepSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -40 {
                    goNext()
                } else if value.translation.width > 40 {
                    goBack()
                }
            }
    }

    private var permissionText: String {
        switch model.authorizationStatus {
        case .authorized, .limited:
            return "Photos access granted"
        case .denied, .restricted:
            return "Photos access denied/restricted"
        case .notDetermined:
            return "Photos permission not requested yet"
        @unknown default:
            return "Unknown authorization status"
        }
    }

    private var permissionIcon: String {
        switch model.authorizationStatus {
        case .authorized, .limited:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }

    private var permissionIconColor: Color {
        switch model.authorizationStatus {
        case .authorized, .limited:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .orange
        }
    }
}

private struct CircleBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
