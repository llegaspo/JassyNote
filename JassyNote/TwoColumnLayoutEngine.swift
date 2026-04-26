import CoreGraphics

struct TwoColumnLayoutEngine {
    func generateLayout(for slides: [SlideImage], settings: LayoutSettings) throws -> [GeneratedPageLayout] {
        guard !slides.isEmpty else {
            return []
        }

        let pageSize = settings.outputPageSize
        let totalGutterWidth = CGFloat(max(settings.columns - 1, 0)) * settings.columnGutter
        let usableWidth = pageSize.width - settings.pageMargins.leading - settings.pageMargins.trailing - totalGutterWidth
        let columnWidth = usableWidth / CGFloat(settings.columns)
        let columnHeight = pageSize.height - settings.pageMargins.top - settings.pageMargins.bottom

        guard settings.columns > 0, columnWidth > 0, columnHeight > 0 else {
            throw SlideImportError.invalidLayout("Layout settings produce a non-printable page area.")
        }

        var pages: [GeneratedPageLayout] = []
        var nextSlideIndex = 0
        var currentPageIndex = 0

        while nextSlideIndex < slides.count {
            var placements: [SlidePlacement] = []

            for column in 0..<settings.columns {
                guard nextSlideIndex < slides.count else {
                    break
                }

                let columnX = settings.pageMargins.leading + CGFloat(column) * (columnWidth + settings.columnGutter)
                let result = try makeColumnPlacements(
                    slides: slides,
                    startIndex: nextSlideIndex,
                    columnX: columnX,
                    topY: settings.pageMargins.top,
                    columnWidth: columnWidth,
                    columnHeight: columnHeight,
                    settings: settings
                )

                placements.append(contentsOf: result.placements)
                nextSlideIndex = result.nextIndex
            }

            guard !placements.isEmpty else {
                break
            }

            pages.append(
                GeneratedPageLayout(
                    pageIndex: currentPageIndex,
                    placements: placements
                )
            )
            currentPageIndex += 1
        }

        return pages
    }

    private func makeColumnPlacements(
        slides: [SlideImage],
        startIndex: Int,
        columnX: CGFloat,
        topY: CGFloat,
        columnWidth: CGFloat,
        columnHeight: CGFloat,
        settings: LayoutSettings
    ) throws -> ColumnLayoutResult {
        var currentY = topY
        var placements: [SlidePlacement] = []
        var nextIndex = startIndex

        while nextIndex < slides.count {
            let metric = try naturalMetric(
                for: slides[nextIndex],
                arrayIndex: nextIndex,
                columnWidth: columnWidth,
                columnHeight: columnHeight
            )

            let wouldOverflow = currentY > topY && currentY + metric.height > topY + columnHeight
            if wouldOverflow {
                break
            }

            let imageX = columnX + (columnWidth - metric.width) / 2
            let imageFrame = CGRect(x: imageX, y: currentY, width: metric.width, height: metric.height).integral
            placements.append(
                SlidePlacement(
                    slideIndex: metric.arrayIndex,
                    slotFrame: CGRect(x: columnX, y: currentY, width: columnWidth, height: metric.height).integral,
                    imageFrame: imageFrame
                )
            )

            currentY += metric.height + settings.verticalSpacing
            nextIndex += 1
        }

        if placements.isEmpty {
            let metric = try naturalMetric(
                for: slides[startIndex],
                arrayIndex: startIndex,
                columnWidth: columnWidth,
                columnHeight: columnHeight
            )
            let imageX = columnX + (columnWidth - metric.width) / 2
            let imageFrame = CGRect(x: imageX, y: topY, width: metric.width, height: metric.height).integral
            placements.append(
                SlidePlacement(
                    slideIndex: metric.arrayIndex,
                    slotFrame: CGRect(x: columnX, y: topY, width: columnWidth, height: metric.height).integral,
                    imageFrame: imageFrame
                )
            )
            nextIndex = startIndex + 1
        }

        return ColumnLayoutResult(placements: placements, nextIndex: nextIndex)
    }

    private func naturalMetric(
        for slide: SlideImage,
        arrayIndex: Int,
        columnWidth: CGFloat,
        columnHeight: CGFloat
    ) throws -> SlideMetric {
        let pageSize = slide.resolvedPageSize
        guard pageSize.width > 0, pageSize.height > 0 else {
            throw SlideImportError.renderFailed(pageIndex: slide.index + 1)
        }

        let widthScale = columnWidth / pageSize.width
        var drawWidth = columnWidth
        var drawHeight = pageSize.height * widthScale

        if drawHeight > columnHeight {
            let heightScale = columnHeight / pageSize.height
            drawWidth = pageSize.width * heightScale
            drawHeight = columnHeight
        }

        return SlideMetric(
            arrayIndex: arrayIndex,
            width: drawWidth,
            height: drawHeight
        )
    }
}

private struct SlideMetric {
    let arrayIndex: Int
    let width: CGFloat
    let height: CGFloat
}

private struct ColumnLayoutResult {
    let placements: [SlidePlacement]
    let nextIndex: Int
}
