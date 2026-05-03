import CoreGraphics
import Foundation
import UIKit

struct SlideImage: Identifiable {
    let id = UUID()
    let index: Int
    let image: UIImage
    let originalPageSize: CGSize
    let sourcePDFURL: URL?

    init(index: Int, image: UIImage, originalPageSize: CGSize, sourcePDFURL: URL? = nil) {
        self.index = index
        self.image = image
        self.originalPageSize = originalPageSize
        self.sourcePDFURL = sourcePDFURL
    }

    var resolvedPageSize: CGSize {
        guard originalPageSize.width > 0, originalPageSize.height > 0 else {
            return image.size
        }
        return originalPageSize
    }
}
