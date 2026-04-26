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
                        let slide = slides[placement.slideIndex]
                        slide.image.draw(in: placement.imageFrame)

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
