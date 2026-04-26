import Foundation

protocol SlideSourceImporter {
    func canImport(url: URL) -> Bool
    func importSlides(from url: URL) async throws -> [SlideImage]
}

enum SlideImportError: LocalizedError, Identifiable {
    case invalidPDF
    case emptyPDF
    case unsupportedPowerPoint
    case unsupportedFileType(String)
    case fileAccessDenied
    case renderFailed(pageIndex: Int)
    case invalidLayout(String)
    case outputGenerationFailed
    case wrapped(Error)

    var id: String {
        localizedDescription
    }

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "The selected PDF could not be opened."
        case .emptyPDF:
            return "The selected PDF has no pages."
        case .unsupportedPowerPoint:
            return "PowerPoint conversion requires a converter. Please export the deck as PDF first for this version."
        case .unsupportedFileType(let type):
            return "The file type \(type) is not supported."
        case .fileAccessDenied:
            return "The app could not access the selected file."
        case .renderFailed(let pageIndex):
            return "Failed to render slide \(pageIndex)."
        case .invalidLayout(let message):
            return message
        case .outputGenerationFailed:
            return "Failed to generate the output PDF."
        case .wrapped(let error):
            return error.localizedDescription
        }
    }
}
