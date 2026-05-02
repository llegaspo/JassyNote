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
        page.displaysAnnotations = true

        let targetSize = CGSize(
            width: max(1, size.width),
            height: max(1, size.height)
        )

        let image = page.thumbnail(of: targetSize, for: .mediaBox)

        guard image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        if image.size == targetSize {
            return image
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            let drawRect = aspectFitRect(for: image.size, in: targetSize)
            image.draw(in: drawRect)
        }
    }

    private func aspectFitRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )

        return CGRect(origin: origin, size: fittedSize)
    }
}
