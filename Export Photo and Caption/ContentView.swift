import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var model = ContentViewModel()
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section("Permission") {
                    Text(permissionText)
                        .foregroundStyle(.secondary)

                    Button("Request Photos Access") {
                        Task { await model.requestPermission() }
                    }
                }

                Section("Select") {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Pick Photos", systemImage: "photo.on.rectangle")
                    }

                    if model.isLoading {
                        ProgressView("Reading selected photos...")
                    } else {
                        Text("Selected: \(model.photos.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Debug / Milestone 1") {
                    if model.photos.isEmpty {
                        Text("Select photos to inspect caption and metadata extraction.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.photos) { photo in
                            NavigationLink {
                                PhotoDetailView(photo: photo)
                            } label: {
                                HStack {
                                    Image(uiImage: photo.sourceImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 54, height: 54)
                                        .clipped()
                                        .cornerRadius(6)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(photo.originalFilename)
                                            .lineLimit(1)
                                        Text(photo.caption ?? "No caption found")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Export") {
                    TextField("Album Name", text: $model.selectedAlbumName)

                    Button("Generate Polaroid Images") {
                        model.generateStyledImages()
                    }
                    .disabled(model.photos.isEmpty)

                    Button("Save To Album") {
                        Task { await model.saveToAlbum() }
                    }
                    .disabled(model.photos.isEmpty || model.isExporting)

                    Button("Share Exported Files") {
                        model.prepareShare()
                    }
                    .disabled(model.photos.isEmpty)
                }
            }
            .navigationTitle("Export Photo + Caption")
            .alert("Error", isPresented: Binding(get: {
                model.lastError != nil
            }, set: { newValue in
                if !newValue { model.lastError = nil }
            }), actions: {
                Button("OK") { model.lastError = nil }
            }, message: {
                Text(model.lastError ?? "Unknown error")
            })
            .sheet(isPresented: $model.showShareSheet) {
                ShareSheet(items: model.shareURLs)
            }
            .sheet(isPresented: $showPicker) {
                PhotoPickerSheet { inputs in
                    model.selectedInputs = inputs
                    Task { await model.loadPickerItems() }
                }
            }
            .task {
                if model.authorizationStatus == .notDetermined {
                    await model.requestPermission()
                }
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
}
