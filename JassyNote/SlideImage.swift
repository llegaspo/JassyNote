import CoreGraphics
import UIKit

struct SlideImage: Identifiable {
    let id = UUID()
    let index: Int
    let image: UIImage
    let originalPageSize: CGSize

    var resolvedPageSize: CGSize {
        guard originalPageSize.width > 0, originalPageSize.height > 0 else {
            return image.size
        }
        return originalPageSize
    }
}
