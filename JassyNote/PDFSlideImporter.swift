import Foundation
import PDFKit
import UIKit

struct PDFSlideImporter: SlideSourceImporter {
    private let maxRenderDimension: CGFloat = 2200

    func canImport(url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf"
    }

    func importSlides(from url: URL) async throws -> [SlideImage] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let slides = try loadSlides(from: url)
                    continuation.resume(returning: slides)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadSlides(from url: URL) throws -> [SlideImage] {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url) else {
            throw SlideImportError.invalidPDF
        }

        guard document.pageCount > 0 else {
            throw SlideImportError.emptyPDF
        }

        var slides: [SlideImage] = []
        slides.reserveCapacity(document.pageCount)

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                throw SlideImportError.renderFailed(pageIndex: index + 1)
            }

            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else {
                throw SlideImportError.renderFailed(pageIndex: index + 1)
            }

            let scale = min(maxRenderDimension / max(bounds.width, bounds.height), 4)
            let renderSize = CGSize(
                width: max(1, bounds.width * scale),
                height: max(1, bounds.height * scale)
            )

            guard let renderedImage = renderImage(for: page, bounds: bounds, size: renderSize) else {
                throw SlideImportError.renderFailed(pageIndex: index + 1)
            }

            slides.append(
                SlideImage(
                    index: index,
                    image: renderedImage,
                    originalPageSize: bounds.size
                )
            )
        }

        return slides
    }

    private func renderImage(for page: PDFPage, bounds: CGRect, size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            cgContext.scaleBy(x: size.width / bounds.width, y: size.height / bounds.height)
            cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)

            if let pageRef = page.pageRef {
                cgContext.drawPDFPage(pageRef)
            } else {
                page.draw(with: .mediaBox, to: cgContext)
            }

            cgContext.restoreGState()
        }

        return image
    }
}
