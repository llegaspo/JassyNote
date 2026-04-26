import Foundation

struct PowerPointSlideImporter: SlideSourceImporter {
    func canImport(url: URL) -> Bool {
        ["ppt", "pptx"].contains(url.pathExtension.lowercased())
    }

    func importSlides(from url: URL) async throws -> [SlideImage] {
        throw SlideImportError.unsupportedPowerPoint
    }
}
