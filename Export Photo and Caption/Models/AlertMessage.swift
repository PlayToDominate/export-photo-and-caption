import Foundation

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
