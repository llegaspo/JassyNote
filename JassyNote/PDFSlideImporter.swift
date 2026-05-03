import Foundation
import PDFKit
import UIKit

struct PDFSlideImporter: SlideSourceImporter {
    private let maxPreviewDimension: CGFloat = 520
    private let rasterizer = PDFPageRasterizer()

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

        guard hasAccess || FileManager.default.isReadableFile(atPath: url.path) else {
            throw SlideImportError.fileAccessDenied
        }

        let sourcePDFURL = try copyToTemporarySourceURL(from: url)

        do {
            guard let document = PDFDocument(url: sourcePDFURL) else {
                throw SlideImportError.invalidPDF
            }

            guard document.pageCount > 0 else {
                throw SlideImportError.emptyPDF
            }

            var slides: [SlideImage] = []
            slides.reserveCapacity(document.pageCount)

            for index in 0..<document.pageCount {
                let slide = try autoreleasepool {
                    try loadSlide(
                        at: index,
                        from: document,
                        sourcePDFURL: sourcePDFURL
                    )
                }
                slides.append(slide)
            }

            return slides
        } catch {
            try? FileManager.default.removeItem(at: sourcePDFURL)
            throw error
        }
    }

    private func loadSlide(at index: Int, from document: PDFDocument, sourcePDFURL: URL) throws -> SlideImage {
        guard let page = document.page(at: index) else {
            throw SlideImportError.renderFailed(pageIndex: index + 1)
        }

        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else {
            throw SlideImportError.renderFailed(pageIndex: index + 1)
        }

        guard let previewImage = rasterizer.render(
            page: page,
            bounds: bounds,
            maxDimension: maxPreviewDimension
        ) else {
            throw SlideImportError.renderFailed(pageIndex: index + 1)
        }

        return SlideImage(
            index: index,
            image: previewImage,
            originalPageSize: bounds.size,
            sourcePDFURL: sourcePDFURL
        )
    }

    private func copyToTemporarySourceURL(from url: URL) throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JassyNote-Source-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        do {
            try FileManager.default.copyItem(at: url, to: outputURL)
        } catch {
            throw SlideImportError.wrapped(error)
        }

        return outputURL
    }
}

struct PDFPageRasterizer {
    func render(page: PDFPage, bounds: CGRect, maxDimension: CGFloat) -> UIImage? {
        guard bounds.width > 0, bounds.height > 0, maxDimension > 0 else {
            return nil
        }

        let scale = min(maxDimension / max(bounds.width, bounds.height), 1)
        let targetSize = CGSize(
            width: max(1, floor(bounds.width * scale)),
            height: max(1, floor(bounds.height * scale))
        )

        return render(page: page, bounds: bounds, targetPixelSize: targetSize)
    }

    func render(page: PDFPage, bounds: CGRect, targetPixelSize: CGSize) -> UIImage? {
        guard bounds.width > 0, bounds.height > 0,
              targetPixelSize.width > 0, targetPixelSize.height > 0 else {
            return nil
        }

        page.displaysAnnotations = true

        let targetSize = CGSize(
            width: max(1, floor(targetPixelSize.width)),
            height: max(1, floor(targetPixelSize.height))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            let drawRect = aspectFitRect(for: bounds.size, in: targetSize)
            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.interpolationQuality = .high
            cgContext.translateBy(x: drawRect.minX, y: drawRect.maxY)
            cgContext.scaleBy(
                x: drawRect.width / bounds.width,
                y: -drawRect.height / bounds.height
            )
            cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: cgContext)
            cgContext.restoreGState()
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
