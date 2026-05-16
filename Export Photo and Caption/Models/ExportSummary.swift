import Foundation

struct ExportSummary {
    var generatedCount: Int = 0
    var savedCount: Int = 0
    var skippedCount: Int = 0

    var hasData: Bool {
        generatedCount > 0 || savedCount > 0 || skippedCount > 0
    }
}
