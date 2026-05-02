import CoreGraphics
import Foundation
import UIKit

struct PDFHandoutRenderer {
    func render(slides: [SlideImage], settings: LayoutSettings, paperColor: UIColor) throws -> URL {
        guard !slides.isEmpty else {
            throw SlideImportError.emptyPDF
        }

        let layouts = try TwoColumnLayoutEngine().generateLayout(for: slides, settings: settings)
        guard !layouts.isEmpty else {
            throw SlideImportError.outputGenerationFailed
        }

        let preparedSlides = prepareSlides(slides: slides, layouts: layouts, settings: settings)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JassyNote-Handout-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        let pageBounds = CGRect(origin: .zero, size: settings.outputPageSize)
        let rendererFormat = UIGraphicsPDFRendererFormat()
        rendererFormat.documentInfo = [
            kCGPDFContextCreator as String: "JassyNote",
            kCGPDFContextAuthor as String: "OpenAI Codex",
            kCGPDFContextTitle as String: "Paper Notes Handout"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: rendererFormat)

        do {
            try renderer.writePDF(to: outputURL) { context in
                for layout in layouts {
                    context.beginPage()
                    let cgContext = context.cgContext
                    drawBackground(
                        style: settings.backgroundStyle,
                        in: pageBounds,
                        margins: settings.pageMargins,
                        paperColor: paperColor,
                        context: cgContext
                    )

                    for placement in layout.placements {
                        let slideImage = preparedSlides[placement.slideIndex] ?? slides[placement.slideIndex].image
                        cgContext.interpolationQuality = .high
                        slideImage.draw(in: placement.imageFrame)

                        if settings.showsSlideBorder {
                            cgContext.saveGState()
                            cgContext.setStrokeColor(UIColor.secondaryLabel.withAlphaComponent(0.35).cgColor)
                            cgContext.setLineWidth(1)
                            cgContext.stroke(placement.imageFrame.insetBy(dx: -0.5, dy: -0.5))
                            cgContext.restoreGState()
                        }
                    }
                }
            }
        } catch {
            throw SlideImportError.wrapped(error)
        }

        return outputURL
    }

    private func prepareSlides(
        slides: [SlideImage],
        layouts: [GeneratedPageLayout],
        settings: LayoutSettings
    ) -> [Int: UIImage] {
        let pixelsPerPoint = settings.outputQuality.targetDPI / 72
        var largestPlacementBySlideIndex: [Int: CGSize] = [:]

        for placement in layouts.flatMap(\.placements) {
            let targetSize = CGSize(
                width: max(1, placement.imageFrame.width * pixelsPerPoint),
                height: max(1, placement.imageFrame.height * pixelsPerPoint)
            )

            if let existingSize = largestPlacementBySlideIndex[placement.slideIndex] {
                largestPlacementBySlideIndex[placement.slideIndex] = CGSize(
                    width: max(existingSize.width, targetSize.width),
                    height: max(existingSize.height, targetSize.height)
                )
            } else {
                largestPlacementBySlideIndex[placement.slideIndex] = targetSize
            }
        }

        var preparedSlides: [Int: UIImage] = [:]
        preparedSlides.reserveCapacity(slides.count)

        for (slideIndex, targetSize) in largestPlacementBySlideIndex {
            let sourceImage = slides[slideIndex].image
            preparedSlides[slideIndex] = compressedImage(
                from: sourceImage,
                targetPixelSize: targetSize,
                jpegQuality: settings.outputQuality.pdfJPEGCompressionQuality
            )
        }

        return preparedSlides
    }

    private func compressedImage(from image: UIImage, targetPixelSize: CGSize, jpegQuality: CGFloat) -> UIImage {
        let sourcePixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )

        guard sourcePixelSize.width > 0, sourcePixelSize.height > 0 else {
            return image
        }

        let widthRatio = targetPixelSize.width / sourcePixelSize.width
        let heightRatio = targetPixelSize.height / sourcePixelSize.height
        let scaleRatio = min(widthRatio, heightRatio)

        let resizedImage: UIImage

        if scaleRatio < 0.98 {
            let destinationSize = CGSize(
                width: max(1, floor(sourcePixelSize.width * scaleRatio)),
                height: max(1, floor(sourcePixelSize.height * scaleRatio))
            )

            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true

            let renderer = UIGraphicsImageRenderer(size: destinationSize, format: format)
            resizedImage = renderer.image { context in
                context.cgContext.interpolationQuality = .high
                image.draw(in: CGRect(origin: .zero, size: destinationSize))
            }
        } else {
            resizedImage = image
        }

        guard let jpegData = resizedImage.jpegData(compressionQuality: jpegQuality),
              let compressedImage = UIImage(data: jpegData, scale: 1) else {
            return resizedImage
        }

        return compressedImage
    }

    private func drawBackground(
        style: PageBackgroundStyle,
        in pageBounds: CGRect,
        margins: PageMargins,
        paperColor: UIColor,
        context: CGContext
    ) {
        context.saveGState()
        context.setFillColor(paperColor.cgColor)
        context.fill(pageBounds)

        guard style != .none else {
            context.restoreGState()
            return
        }

        let contentRect = CGRect(
            x: margins.leading,
            y: margins.top,
            width: pageBounds.width - margins.leading - margins.trailing,
            height: pageBounds.height - margins.top - margins.bottom
        )

        context.setStrokeColor(UIColor.systemGray4.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(0.5)

        switch style {
        case .none:
            break
        case .grid:
            let spacing: CGFloat = 18
            var x = contentRect.minX
            while x <= contentRect.maxX {
                context.move(to: CGPoint(x: x, y: contentRect.minY))
                context.addLine(to: CGPoint(x: x, y: contentRect.maxY))
                x += spacing
            }

            var y = contentRect.minY
            while y <= contentRect.maxY {
                context.move(to: CGPoint(x: contentRect.minX, y: y))
                context.addLine(to: CGPoint(x: contentRect.maxX, y: y))
                y += spacing
            }

            context.strokePath()
        case .ruled:
            let spacing: CGFloat = 24
            var y = contentRect.minY
            while y <= contentRect.maxY {
                context.move(to: CGPoint(x: contentRect.minX, y: y))
                context.addLine(to: CGPoint(x: contentRect.maxX, y: y))
                y += spacing
            }

            context.strokePath()
        }

        context.restoreGState()
    }
}
