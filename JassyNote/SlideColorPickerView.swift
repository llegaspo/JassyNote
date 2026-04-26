import SwiftUI
import UIKit

struct SlideColorPickerView: View {
    let slides: [SlideImage]
    @Binding var selectedColor: UIColor
    let onDone: () -> Void

    @State private var selectedSlideIndex = 0

    var body: some View {
        NavigationStack {
            Group {
                if slides.isEmpty {
                    ContentUnavailableView(
                        "No Slides",
                        systemImage: "drop",
                        description: Text("Import a PDF before sampling a paper color.")
                    )
                } else {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Slide")
                            Spacer()
                            Text("\(selectedSlideIndex + 1) / \(slides.count)")
                                .foregroundStyle(.secondary)
                        }

                        Stepper(value: $selectedSlideIndex, in: 0...(slides.count - 1)) {
                            Text("Choose Slide")
                        }

                        SlideColorSamplingCanvas(
                            image: slides[selectedSlideIndex].image,
                            selectedColor: $selectedColor
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        HStack {
                            Text("Selected Color")
                            Spacer()
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: selectedColor))
                                .frame(width: 52, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pick Paper Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }
}

private struct SlideColorSamplingCanvas: View {
    let image: UIImage
    @Binding var selectedColor: UIColor
    @State private var samplePoint: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let imageSize = image.size
            let drawRect = aspectFitRect(for: imageSize, in: proxy.size)
            let markerPosition = markerPoint(in: drawRect)

            ZStack {
                Color(uiColor: .secondarySystemBackground)

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if let markerPosition {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .background(Circle().fill(Color(uiColor: selectedColor)))
                        .frame(width: 24, height: 24)
                        .position(markerPosition)
                        .shadow(radius: 2)
                }
            }
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard drawRect.contains(value.location) else {
                            return
                        }

                        samplePoint = value.location
                        let imagePoint = convertToImagePoint(
                            location: value.location,
                            drawRect: drawRect,
                            imageSize: imageSize
                        )

                        if let color = image.sampledColor(at: imagePoint) {
                            selectedColor = color
                        }
                    }
            )
        }
    }

    private func markerPoint(in drawRect: CGRect) -> CGPoint? {
        if let samplePoint, drawRect.contains(samplePoint) {
            return samplePoint
        }

        guard drawRect != .zero else {
            return nil
        }

        return CGPoint(x: drawRect.minX + 24, y: drawRect.minY + 24)
    }

    private func aspectFitRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )
        return CGRect(origin: origin, size: fittedSize)
    }

    private func convertToImagePoint(location: CGPoint, drawRect: CGRect, imageSize: CGSize) -> CGPoint {
        let normalizedX = (location.x - drawRect.minX) / drawRect.width
        let normalizedY = (location.y - drawRect.minY) / drawRect.height
        return CGPoint(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height
        )
    }
}

private extension UIImage {
    func sampledColor(at point: CGPoint) -> UIColor? {
        guard let cgImage else {
            return nil
        }

        let x = max(0, min(Int(point.x.rounded(.down)), cgImage.width - 1))
        let y = max(0, min(Int(point.y.rounded(.down)), cgImage.height - 1))

        guard let dataProvider = cgImage.dataProvider, let data = dataProvider.data else {
            return nil
        }

        let ptr = CFDataGetBytePtr(data)
        let length = CFDataGetLength(data)
        guard let bytes = ptr, length > 0 else {
            return nil
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        guard bytesPerPixel >= 4 else {
            return nil
        }

        let offset = y * bytesPerRow + x * bytesPerPixel
        guard offset + 3 < length else {
            return nil
        }

        let alphaInfo = cgImage.alphaInfo
        let isAlphaFirst = alphaInfo == .first || alphaInfo == .premultipliedFirst || alphaInfo == .noneSkipFirst
        let isLittleEndian = cgImage.bitmapInfo.contains(.byteOrder32Little)

        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8

        if isLittleEndian && isAlphaFirst {
            blue = bytes[offset]
            green = bytes[offset + 1]
            red = bytes[offset + 2]
            alpha = bytes[offset + 3]
        } else {
            red = bytes[offset]
            green = bytes[offset + 1]
            blue = bytes[offset + 2]
            alpha = bytes[offset + 3]
        }

        return UIColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }
}
