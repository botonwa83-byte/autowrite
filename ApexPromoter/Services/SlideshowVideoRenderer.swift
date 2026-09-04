import AVFoundation
import UIKit

enum SlideshowVideoError: LocalizedError {
    case noImages, cannotCreateWriter, cannotEncode
    var errorDescription: String? {
        switch self { case .noImages: "请先添加图片素材"; case .cannotCreateWriter: "无法创建视频文件"; case .cannotEncode: "视频编码失败" }
    }
}

enum SlideshowVideoRenderer {
    static let size = CGSize(width: 1080, height: 1920)

    static func render(images: [UIImage], title: String, secondsPerImage: Double = 2.5) async throws -> URL {
        guard !images.isEmpty else { throw SlideshowVideoError.noImages }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("promotion-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height)]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height)]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw SlideshowVideoError.cannotCreateWriter }
        writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let framesPerImage = Int(secondsPerImage * Double(fps))
        for (imageIndex, image) in images.enumerated() {
            let rendered = frame(image: image, title: title, index: imageIndex + 1, total: images.count)
            guard let buffer = pixelBuffer(from: rendered, pool: adaptor.pixelBufferPool) else { throw SlideshowVideoError.cannotEncode }
            for frameIndex in 0..<framesPerImage {
                while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(10)) }
                let frameNumber = imageIndex * framesPerImage + frameIndex
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frameNumber), timescale: fps)) else { throw SlideshowVideoError.cannotEncode }
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? SlideshowVideoError.cannotEncode }
        return url
    }

    private static func frame(image: UIImage, title: String, index: Int, total: Int) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill(); context.fill(CGRect(origin: .zero, size: size))
            let scale = min(size.width / image.size.width, 1450 / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (size.width - drawSize.width) / 2, y: 180 + (1450 - drawSize.height) / 2, width: drawSize.width, height: drawSize.height))
            let style = NSMutableParagraphStyle(); style.alignment = .center
            (title as NSString).draw(in: CGRect(x: 70, y: 55, width: 940, height: 110), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 54), .foregroundColor: UIColor.white, .paragraphStyle: style])
            ("\(index) / \(total)" as NSString).draw(in: CGRect(x: 70, y: 1690, width: 940, height: 80), withAttributes: [.font: UIFont.systemFont(ofSize: 36), .foregroundColor: UIColor.white, .paragraphStyle: style])
        }
    }

    private static func pixelBuffer(from image: UIImage, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue), let cgImage = image.cgImage else { return nil }
        // UIKit's rendered image is already top-left oriented; applying another
        // vertical transform here would produce an upside-down exported video.
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
