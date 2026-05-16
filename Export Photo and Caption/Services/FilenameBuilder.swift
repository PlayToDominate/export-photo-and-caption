import Foundation

struct FilenameBuilder {
    func buildFilename(for photo: ProcessedPhoto) -> String {
        let datePart = formattedDate(photo.creationDate)
        let captionPart = slug(photo.captionForExportSlug)

        if !captionPart.isEmpty {
            return "\(datePart)-\(captionPart).jpg"
        }

        let originalStem = slug((photo.originalFilename as NSString).deletingPathExtension)
        if !originalStem.isEmpty {
            return "\(datePart)-\(originalStem).jpg"
        }

        return "\(datePart)-photo-\(photo.sourceIndex + 1).jpg"
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "unknown-date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func slug(_ value: String?) -> String {
        let raw = (value ?? "").lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let filtered = raw.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(filtered))
        let words = cleaned
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .prefix(6)
            .map(String.init)

        return words.joined(separator: "-")
    }
}
