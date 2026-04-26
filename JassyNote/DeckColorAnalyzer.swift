import CoreGraphics
import UIKit

struct DeckColorAnalyzer {
    func dominantPaperColor(from slides: [SlideImage]) -> UIColor {
        let sampleSlides = Array(slides.prefix(8))
        guard !sampleSlides.isEmpty else {
            return .white
        }

        var histogram: [ColorBucket: Int] = [:]
        var weightedRed = CGFloat.zero
        var weightedGreen = CGFloat.zero
        var weightedBlue = CGFloat.zero
        var totalWeight = CGFloat.zero

        for slide in sampleSlides {
            guard let cgImage = makeThumbnail(from: slide.image, maxDimension: 56)?.cgImage else {
                continue
            }

            guard let dataProvider = cgImage.dataProvider, let data = dataProvider.data else {
                continue
            }

            let bytePtr = CFDataGetBytePtr(data)
            let length = CFDataGetLength(data)
            guard let bytes = bytePtr, length > 0 else {
                continue
            }

            let bytesPerPixel = cgImage.bitsPerPixel / 8
            let bytesPerRow = cgImage.bytesPerRow
            guard bytesPerPixel >= 4 else {
                continue
            }

            for y in stride(from: 0, to: cgImage.height, by: 2) {
                for x in stride(from: 0, to: cgImage.width, by: 2) {
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    guard offset + 3 < length else {
                        continue
                    }

                    let red = CGFloat(bytes[offset]) / 255
                    let green = CGFloat(bytes[offset + 1]) / 255
                    let blue = CGFloat(bytes[offset + 2]) / 255
                    let alpha = CGFloat(bytes[offset + 3]) / 255

                    guard alpha > 0.8 else {
                        continue
                    }

                    var hue = CGFloat.zero
                    var saturation = CGFloat.zero
                    var brightness = CGFloat.zero
                    UIColor(red: red, green: green, blue: blue, alpha: alpha).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

                    if brightness > 0.97 && saturation < 0.08 {
                        continue
                    }

                    let weight = max(0.15, saturation) * alpha
                    let bucket = ColorBucket(red: red, green: green, blue: blue)
                    histogram[bucket, default: 0] += Int(weight * 10)

                    weightedRed += red * weight
                    weightedGreen += green * weight
                    weightedBlue += blue * weight
                    totalWeight += weight
                }
            }
        }

        if let dominantBucket = histogram.max(by: { $0.value < $1.value })?.key {
            return dominantBucket.color.lightened(by: 0.12)
        }

        guard totalWeight > 0 else {
            return .white
        }

        return UIColor(
            red: weightedRed / totalWeight,
            green: weightedGreen / totalWeight,
            blue: weightedBlue / totalWeight,
            alpha: 1
        ).lightened(by: 0.12)
    }

    private func makeThumbnail(from image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return nil
        }

        let scale = min(maxDimension / max(originalSize.width, originalSize.height), 1)
        let targetSize = CGSize(
            width: max(1, floor(originalSize.width * scale)),
            height: max(1, floor(originalSize.height * scale))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private struct ColorBucket: Hashable {
    let red: Int
    let green: Int
    let blue: Int

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = Self.quantize(red)
        self.green = Self.quantize(green)
        self.blue = Self.quantize(blue)
    }

    var color: UIColor {
        UIColor(
            red: CGFloat(red) / 15,
            green: CGFloat(green) / 15,
            blue: CGFloat(blue) / 15,
            alpha: 1
        )
    }

    private static func quantize(_ value: CGFloat) -> Int {
        max(0, min(15, Int((value * 15).rounded())))
    }
}

private extension UIColor {
    func lightened(by amount: CGFloat) -> UIColor {
        var red = CGFloat.zero
        var green = CGFloat.zero
        var blue = CGFloat.zero
        var alpha = CGFloat.zero

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return self
        }

        return UIColor(
            red: red + (1 - red) * amount,
            green: green + (1 - green) * amount,
            blue: blue + (1 - blue) * amount,
            alpha: alpha
        )
    }
}
