import UIKit
import AVFoundation

enum MoneyFrameError: Error { case pixelBuffer, context, format(OSStatus), sample(OSStatus) }

final class MoneyFrameRenderer {
    static let width = 640
    static let height = 360

    func sample(record: SessionRecord?, presentationSeconds: TimeInterval) throws -> CMSampleBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Self.width, Self.height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true] as CFDictionary,
            &buffer)
        guard status == kCVReturnSuccess, let buffer else { throw MoneyFrameError.pixelBuffer }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Self.width,
            height: Self.height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { throw MoneyFrameError.context }
        let imageFormat = UIGraphicsImageRendererFormat()
        imageFormat.scale = 1
        imageFormat.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(Self.width), height: CGFloat(Self.height)), format: imageFormat).image { drawing in
            UIColor(red: 0.98, green: 0.96, blue: 0.89, alpha: 1).setFill()
            drawing.fill(CGRect(x: 0, y: 0, width: CGFloat(Self.width), height: CGFloat(Self.height)))
            let title = record == nil ? "もしドパ · 計測前" : "働いていたら"
            draw(title, rect: CGRect(x: 32, y: 25, width: 576, height: 48), font: .systemFont(ofSize: 28, weight: .semibold))
            let money = record.map { String(format: "¥%.2f", $0.amount) } ?? "¥0.00"
            // Adapt long amounts to the fixed video canvas; never clip the actual digits.
            var size: CGFloat = 76
            while (money as NSString).size(withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)]).width > 576 && size > 24 { size -= 2 }
            draw(money, rect: CGRect(x: 32, y: 105, width: 576, height: 100), font: .monospacedDigitSystemFont(ofSize: size, weight: .bold))
            let seconds = (record?.elapsedMilliseconds ?? 0) / 1000
            let detail = String(format: "%02lld:%02lld:%02lld · 時給 ¥%.2f", seconds / 3600, seconds / 60 % 60, seconds % 60, record?.hourlyRateAtStart ?? 0)
            var detailSize: CGFloat = 25
            while (detail as NSString).size(withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: detailSize, weight: .medium)]).width > 576 && detailSize > 12 { detailSize -= 1 }
            draw(detail, rect: CGRect(x: 32, y: 250, width: 576, height: 48), font: .monospacedDigitSystemFont(ofSize: detailSize, weight: .medium))
            draw("実機検証用 · 表示を閉じても計測は継続", rect: CGRect(x: 32, y: 312, width: 576, height: 30), font: .systemFont(ofSize: 19))
        }
        guard let cgImage = image.cgImage else { throw MoneyFrameError.context }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(Self.width), height: CGFloat(Self.height)))
        var format: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &format)
        guard formatStatus == noErr, let format else { throw MoneyFrameError.format(formatStatus) }
        var timing = CMSampleTimingInfo(duration: CMTime(seconds: 1, preferredTimescale: 600),
            presentationTimeStamp: CMTime(seconds: presentationSeconds, preferredTimescale: 600), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer,
            formatDescription: format, sampleTiming: &timing, sampleBufferOut: &sample)
        guard sampleStatus == noErr, let sample else { throw MoneyFrameError.sample(sampleStatus) }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(), Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sample
    }

    private func draw(_ text: String, rect: CGRect, font: UIFont) {
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: UIColor(red: 0.16, green: 0.2, blue: 0.17, alpha: 1)])
    }
}

