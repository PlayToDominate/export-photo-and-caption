# Export Photo and Caption

Native iOS SwiftUI app that lets users select photos, detect available caption/description metadata, and generate new Polaroid-style exported images with caption text burned into the output image.

Original photos are never modified.

## Status

Current stage: **V1 scaffold with debug-first caption verification**.

The first milestone is intentionally focused on proving what caption metadata is actually readable from iOS Photos assets on-device.

## V1 Goals

- Native iOS SwiftUI app.
- Request Photos library permission.
- Select multiple photos from Photos library.
- For each selected photo:
  - Load best available image data.
  - Read creation date (`PHAsset.creationDate`, metadata fallback).
  - Attempt caption/description extraction from available metadata.
  - Render a new Polaroid-like image with caption area.
  - Generate safe export filename (`yyyy-MM-dd-caption-slug.jpg` style).
- Save generated images into a user-named Photos album (default: `Captioned Export`).
- Offer iOS share sheet export (Files, AirDrop, etc.).
- Show per-photo debug/details screen for caption/metadata inspection.

## Current Features Implemented

- `PhotosPicker` multi-select flow.
- `PHPhotoLibrary` permission request (`.readWrite`).
- Metadata extraction pipeline:
  - filename discovery
  - creation date discovery
  - caption candidate extraction from IPTC/TIFF/EXIF + selected asset KVC candidates
  - metadata key listing for diagnostics
- Debug detail view for each selected photo.
- Polaroid renderer (`UIGraphicsImageRenderer`) with:
  - white border
  - enlarged bottom caption strip
  - proportional centered crop (aspect-fill)
  - caption text drawn into image
- Filename builder with robust fallback chain.
- Save-to-album export via PhotoKit.
- Share-sheet export of generated files to temporary directory.

## Project Structure

- `Export Photo and Caption.xcodeproj`: native Xcode project (open directly).
- `Export Photo and Caption/ExportPhotoAndCaptionApp.swift`: app entrypoint.
- `Export Photo and Caption/ContentView.swift`: main UI and flows.
- `Export Photo and Caption/Models/ProcessedPhoto.swift`: processed photo model.
- `Export Photo and Caption/ViewModels/ContentViewModel.swift`: app state + orchestration.
- `Export Photo and Caption/Services/PhotoMetadataService.swift`: photo load + metadata/caption discovery.
- `Export Photo and Caption/Services/PolaroidRenderer.swift`: styled image renderer.
- `Export Photo and Caption/Services/FilenameBuilder.swift`: safe filename generation.
- `Export Photo and Caption/Views/PhotoDetailView.swift`: debug screen.
- `Export Photo and Caption/Views/ShareSheet.swift`: UIKit share-sheet wrapper.
- `Export Photo and Caption/Info.plist`: iOS permissions text.

## Run Locally (Xcode)

1. Open `Export Photo and Caption.xcodeproj` in Xcode.
2. Set your Apple Developer Team in **Signing & Capabilities**.
3. Update bundle identifier if needed (default is `com.example.ExportPhotoAndCaption`).
4. Select an iPhone device target.
5. Build and Run.

Notes:

- Real device is recommended for reliable Photos metadata behavior.
- The project already includes required photo permissions in `Info.plist`.

## Permissions

The app requests:

- Photo library read access (to select and inspect photos).
- Photo library add access (to save newly generated exports).

## Caption Metadata Caveat

iOS Photos user-entered captions are not guaranteed to be embedded into every file’s exportable metadata representation.

That is why milestone one emphasizes the debug screen: it shows exactly which candidate caption fields and metadata keys are discoverable for each selected asset on the current iOS/device combination.

## Export Naming Strategy

Filename format target:

- `YYYY-MM-DD-caption-slug.jpg`

Fallback order:

1. creation date + caption slug
2. creation date + original filename stem
3. `unknown-date-photo-{index}.jpg`

## Screenshots

Coming soon. Planned captures:

- Main screen with multi-photo selection.
- Per-photo debug metadata details.
- Rendered Polaroid preview/export examples.

## Changelog

### 2026-05-13

- Initial SwiftUI app scaffold committed.
- Added Photos permission + multi-select flow.
- Added debug-first caption/metadata inspection screen.
- Added Polaroid rendering pipeline.
- Added filename strategy + album save + share sheet export.
- Added native `.xcodeproj` and shared scheme.

## Known Issues

- Caption availability depends on what iOS/Photos actually exposes per asset.
- Some selected assets may provide limited metadata depending on source/edit history.
- Current caption extraction includes KVC-based candidate checks for diagnostics; behavior may vary by iOS version.
- UI/visual polish is intentionally minimal in this milestone.

## Non-Goals (for now)

- No backend service.
- No third-party metadata/processing SDKs.
- No in-place edits to source Photos assets.

## Roadmap (Living)

Planned next iterations:

- Improve caption typography/theme options.
- Add export quality/size controls.
- Add progress UI for large batch exports.
- Add stronger metadata diagnostics and optional raw dump view.
- Add tests for filename/caption fallback behavior.

## Contributing Notes

- Keep architecture simple and local-first.
- Prioritize reliability of caption detection and debug visibility over visual polish.
- Preserve originals always; generated output must be new assets/files.

## License

TBD
