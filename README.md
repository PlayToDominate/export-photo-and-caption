# Captioned Photos

Native iOS SwiftUI app that lets users select photos, detect available caption/description metadata, and generate captioned photo exports with the caption text rendered directly into the new image.

Original photos are never modified.

## Status

Current stage: **working V1 with guided 3-step flow**.

The app is focused on simple, local processing:

1. permissions
2. photo selection
3. caption style + generate/save

## Core Features

- Native iOS SwiftUI app (no backend, no third-party processing SDKs).
- Multi-photo pick flow from Photos.
- Metadata extraction per selected photo:
  - creation date
  - original filename fallback chain
  - caption/description candidates from metadata
- Captioned image renderer using `UIGraphicsImageRenderer`:
  - white print-style frame
  - larger bottom caption area
  - caption text baked into the exported image
- Caption font selector (including script option) with preview.
- One-tap generate + save flow (`Generate Captioned Photos`).
- Save to Photos album (default: `Captioned Export`).
- Share exported files via iOS share sheet.
- Export summary section (generated/saved/skipped counts).
- Launch screen storyboard + custom app icon integrated.

## Current App Flow

The app uses a simple step UI with page dots and back/next controls:

1. **Permission**
- Request photo access when needed.

2. **Select Photos**
- Pick one or more photos.
- Remove selected photos via swipe delete.
- Open system settings with `Update Photo Access` if needed.

3. **Style + Generate**
- Choose caption font.
- See text preview style.
- Generate and save captioned photos in one action.
- Optional share export.
- Start over/reset session.

## Project Structure

- `Export Photo and Caption.xcodeproj`: native Xcode project.
- `Export Photo and Caption/ExportPhotoAndCaptionApp.swift`: app entrypoint.
- `Export Photo and Caption/ContentView.swift`: 3-step wizard UI and navigation.
- `Export Photo and Caption/Models/ProcessedPhoto.swift`: selected/processed photo model.
- `Export Photo and Caption/Models/SelectedPhotoInput.swift`: picker input payload.
- `Export Photo and Caption/Models/CaptionFontOption.swift`: font options and preview styles.
- `Export Photo and Caption/Models/ExportSummary.swift`: generated/saved/skipped summary.
- `Export Photo and Caption/Models/AlertMessage.swift`: typed alert model.
- `Export Photo and Caption/ViewModels/ContentViewModel.swift`: orchestration/state management.
- `Export Photo and Caption/Services/PhotoMetadataService.swift`: data loading + metadata extraction.
- `Export Photo and Caption/Services/CaptionedPhotoRenderer.swift`: styled image renderer.
- `Export Photo and Caption/Services/FilenameBuilder.swift`: safe output filename generation.
- `Export Photo and Caption/Views/PhotoDetailView.swift`: metadata detail/debug screen.
- `Export Photo and Caption/Views/PhotoPickerSheet.swift`: PHPicker bridge.
- `Export Photo and Caption/Views/ShareSheet.swift`: UIKit share wrapper.
- `Export Photo and Caption/LaunchScreen.storyboard`: splash screen.
- `Export Photo and Caption/Info.plist`: app display name + permission strings.

## Run Locally (Xcode)

1. Open `Export Photo and Caption.xcodeproj` in Xcode.
2. Set your Apple Developer Team in **Signing & Capabilities**.
3. Update bundle identifier if needed.
4. Build and run on iPhone.

Notes:

- Real device is recommended for realistic Photos behavior.
- The app now displays as **Captioned Photos** (`CFBundleDisplayName`).

## Permissions Notes

The app uses Photos permission primarily for:

- richer `PHAsset` metadata access
- creating/using save album in Photos
- saving generated assets back to library

Photo picking itself uses iOS picker flow and may still show broader user-selectable choices depending on iOS behavior.

## Caption Metadata Caveat

iOS user-entered Photos captions are not always exposed as file metadata through public APIs for every asset.

When caption metadata is unavailable, the app falls back gracefully and still generates captioned output with fallback text.

## Output Naming Strategy

Primary format:

- `YYYY-MM-DD-caption-slug.jpg`

Fallback order:

1. creation date + caption slug
2. creation date + original filename stem
3. `unknown-date-photo-{index}.jpg`

## Known Limitations

- Cannot reliably deep-link directly into a specific album or specific newly saved asset inside Apple Photos using public APIs.
- Caption metadata availability varies by source photo and iOS behavior.

## Changelog (Recent)

### 2026-05-15

- Renamed user-facing app branding to **Captioned Photos**.
- Introduced 3-step wizard flow with back/next and page dots.
- Added script font option + styled font selector preview.
- Combined generate + save into single primary action.
- Added export summary counters (generated/saved/skipped).
- Added launch screen storyboard and integrated custom app icon set.
- Added stronger `Start Over` reset behavior and load-token safety for async picker race conditions.
- Switched to typed alert model for cleaner error handling.
- Renamed renderer to `CaptionedPhotoRenderer`.

## License

TBD
