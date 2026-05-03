import Foundation
import UIKit
import UniformTypeIdentifiers

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class HandoutViewModel: ObservableObject {
    @Published var settings = LayoutSettings()
    @Published var sourceFileName = "No document selected"
    @Published var importedSlides: [SlideImage] = []
    @Published var generatedPDFURL: URL?
    @Published var detectedDeckColor: UIColor = .white
    @Published var pickedPaperColor: UIColor = .white
    @Published var isImporting = false
    @Published var isGenerating = false
    @Published var activeAlert: AlertItem?

    private let pdfImporter = PDFSlideImporter()
    private let powerPointImporter = PowerPointSlideImporter()
    private let layoutEngine = TwoColumnLayoutEngine()
    private var temporarySourceURLs: Set<URL> = []

    var slideCountDescription: String {
        importedSlides.isEmpty ? "No slides loaded" : "\(importedSlides.count) slides loaded"
    }

    var resolvedColumnCount: Int {
        guard !importedSlides.isEmpty else {
            return settings.columns
        }

        return layoutEngine.resolvedColumnCount(for: importedSlides, settings: settings)
    }

    var readabilityStatus: String? {
        guard !importedSlides.isEmpty else {
            return nil
        }

        let effectiveColumns = resolvedColumnCount
        guard effectiveColumns < settings.columns else {
            return nil
        }

        let label = effectiveColumns == 1 ? "column" : "columns"
        return "Using \(effectiveColumns) \(label) to keep slides at least \(Int(settings.minimumReadableSlideHeight)) pt tall."
    }

    var canGenerate: Bool {
        !importedSlides.isEmpty && !isImporting && !isGenerating
    }

    var allowedContentTypes: [UTType] {
        var types: [UTType] = [.pdf]

        if let ppt = UTType(filenameExtension: "ppt") {
            types.append(ppt)
        }

        if let pptx = UTType(filenameExtension: "pptx") {
            types.append(pptx)
        }

        return types
    }

    func importDocument(from url: URL) {
        removeTemporarySourceFiles()
        sourceFileName = url.lastPathComponent
        generatedPDFURL = nil
        importedSlides = []
        isImporting = true

        Task {
            do {
                let importer = try resolveImporter(for: url)
                let slides = try await importer.importSlides(from: url)
                importedSlides = slides
                temporarySourceURLs = Set(slides.compactMap(\.sourcePDFURL))
                detectedDeckColor = DeckColorAnalyzer().dominantPaperColor(from: slides)
                pickedPaperColor = detectedDeckColor
                isImporting = false
                await regenerate()
            } catch {
                isImporting = false
                present(error)
            }
        }
    }

    func regenerate() async {
        guard !importedSlides.isEmpty else {
            return
        }

        isGenerating = true
        let slides = importedSlides
        let settings = settings

        do {
            let generatedURL = try await withCheckedThrowingContinuation { continuation in
                let paperColor = resolvePaperColor()
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let url = try PDFHandoutRenderer().render(
                            slides: slides,
                            settings: settings,
                            paperColor: paperColor
                        )
                        continuation.resume(returning: url)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            generatedPDFURL = generatedURL
            isGenerating = false
        } catch {
            isGenerating = false
            present(error)
        }
    }

    func handleImporterError(_ error: Error) {
        present(error)
    }

    private func resolveImporter(for url: URL) throws -> any SlideSourceImporter {
        if pdfImporter.canImport(url: url) {
            return pdfImporter
        }

        if powerPointImporter.canImport(url: url) {
            return powerPointImporter
        }

        throw SlideImportError.unsupportedFileType(url.pathExtension.isEmpty ? "unknown" : ".\(url.pathExtension)")
    }

    private func present(_ error: Error) {
        let resolvedError: SlideImportError

        if let slideError = error as? SlideImportError {
            resolvedError = slideError
        } else {
            resolvedError = .wrapped(error)
        }

        activeAlert = AlertItem(
            title: "Unable to Process File",
            message: resolvedError.errorDescription ?? "An unknown error occurred."
        )
    }

    private func resolvePaperColor() -> UIColor {
        switch settings.paperColorMode {
        case .white:
            return .white
        case .deckDominant:
            return detectedDeckColor
        case .pickedFromSlide:
            return pickedPaperColor
        }
    }

    private func removeTemporarySourceFiles() {
        for url in temporarySourceURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporarySourceURLs.removeAll()
    }
}
