import CoreGraphics
import Foundation

struct SlidePlacement: Identifiable {
    let id = UUID()
    let slideIndex: Int
    let slotFrame: CGRect
    let imageFrame: CGRect
}

struct GeneratedPageLayout: Identifiable {
    let id = UUID()
    let pageIndex: Int
    let placements: [SlidePlacement]
}
