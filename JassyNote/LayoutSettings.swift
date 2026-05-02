import CoreGraphics

enum PaperSizeOption: String, CaseIterable, Identifiable {
    case a4 = "A4"
    case letter = "Letter"

    var id: String { rawValue }

    var baseSize: CGSize {
        switch self {
        case .a4:
            return CGSize(width: 595.28, height: 841.89)
        case .letter:
            return CGSize(width: 612, height: 792)
        }
    }
}

enum PageOrientationOption: String, CaseIterable, Identifiable {
    case portrait = "Portrait"
    case landscape = "Landscape"

    var id: String { rawValue }
}

enum PageBackgroundStyle: String, CaseIterable, Identifiable {
    case none = "Off"
    case grid = "Grid"
    case ruled = "Ruled"

    var id: String { rawValue }
}

enum OutputQualityOption: String, CaseIterable, Identifiable {
    case best = "Best"
    case balanced = "Balanced"
    case compact = "Compact"

    var id: String { rawValue }

    var targetDPI: CGFloat {
        switch self {
        case .best:
            return 220
        case .balanced:
            return 160
        case .compact:
            return 110
        }
    }

    var pdfJPEGCompressionQuality: CGFloat {
        switch self {
        case .best:
            return 0.9
        case .balanced:
            return 0.68
        case .compact:
            return 0.48
        }
    }
}

enum PaperColorMode: String, CaseIterable, Identifiable {
    case white = "White"
    case deckDominant = "Match Deck"
    case pickedFromSlide = "Pick from Slide"

    var id: String { rawValue }
}

struct PageMargins: Equatable {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat

    static let standard = PageMargins(top: 16, leading: 16, bottom: 16, trailing: 16)
}

struct LayoutSettings: Equatable {
    var paperSize: PaperSizeOption = .a4
    var orientation: PageOrientationOption = .portrait
    var columns: Int = 2
    var pageMargins: PageMargins = .standard
    var columnGutter: CGFloat = 12
    var verticalSpacing: CGFloat = 0
    var minimumReadableSlideHeight: CGFloat = 120
    var showsSlideBorder = false
    var paperColorMode: PaperColorMode = .white
    var backgroundStyle: PageBackgroundStyle = .none
    var outputQuality: OutputQualityOption = .balanced

    var outputPageSize: CGSize {
        let size = paperSize.baseSize
        switch orientation {
        case .portrait:
            return size
        case .landscape:
            return CGSize(width: size.height, height: size.width)
        }
    }
}
