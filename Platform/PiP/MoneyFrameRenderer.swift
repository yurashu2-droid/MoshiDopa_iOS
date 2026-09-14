import UIKit
import AVFoundation

enum MoneyFrameError: Error { case pixelBuffer, context, format(OSStatus), sample(OSStatus) }

final class MoneyFrameRenderer {
    static let width = 640
    static let height = 360
    static let frameInterval: TimeInterval = 0.1

    func sample(record: SessionRecord?, presentationSeconds: TimeInterval, style: String = "paper") throws -> CMSampleBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Self.width, Self.height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey as String: true,
             kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
             kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
             kCVPixelBufferMetalCompatibilityKey as String: true] as CFDictionary,
            &buffer)
        guard status == kCVReturnSuccess, let buffer else { throw MoneyFrameError.pixelBuffer }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Self.width,
            height: Self.height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { throw MoneyFrameError.context }
        let image = self.image(amount: record?.amount ?? 0, style: style)
        guard let cgImage = image.cgImage else { throw MoneyFrameError.context }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(Self.width), height: CGFloat(Self.height)))
        var format: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &format)
        guard formatStatus == noErr, let format else { throw MoneyFrameError.format(formatStatus) }
        var timing = CMSampleTimingInfo(duration: CMTime(seconds: Self.frameInterval, preferredTimescale: 600),
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

    /// Used by both settings previews and the real opaque PiP video canvas.
    func image(amount: Double, style: String, title: String = "対象時間の金額") -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let ink = UIColor(red: 0.09, green: 0.098, blue: 0.106, alpha: 1)
        let paper = UIColor(red: 0.98, green: 0.976, blue: 0.953, alpha: 1)
        let blue = UIColor(red: 0.87, green: 0.92, blue: 0.95, alpha: 1)
        let lime = UIColor(red: 0.824, green: 0.929, blue: 0.439, alpha: 1)
        return UIGraphicsImageRenderer(size: CGSize(width: CGFloat(Self.width), height: CGFloat(Self.height)), format: format).image { renderer in
            blue.setFill()
            renderer.fill(CGRect(x: 0, y: 0, width: CGFloat(Self.width), height: CGFloat(Self.height)))
            let panel = CGRect(x: 28, y: 46, width: 584, height: 268)
            var foreground = ink
            var textX: CGFloat = 58
            var textWidth: CGFloat = 524
            switch style {
            case "ink":
                ink.setFill()
                UIBezierPath(roundedRect: panel, cornerRadius: 30).fill()
                foreground = paper
                let play = UIBezierPath()
                play.move(to: CGPoint(x: 56, y: 151)); play.addLine(to: CGPoint(x: 56, y: 197)); play.addLine(to: CGPoint(x: 89, y: 174)); play.close()
                lime.setFill(); play.fill()
                paper.withAlphaComponent(0.25).setFill()
                renderer.fill(CGRect(x: 112, y: 98, width: 2, height: 164))
                textX = 140; textWidth = 440
            case "frost":
                let colors = [UIColor.white.cgColor, blue.cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                    renderer.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 640, y: 360), options: [])
                }
                UIColor.white.withAlphaComponent(0.78).setFill()
                let glass = UIBezierPath(roundedRect: panel, cornerRadius: 52)
                glass.fill()
                UIColor.white.setStroke(); glass.lineWidth = 3; glass.stroke()
            case "sticker":
                paper.setFill()
                UIBezierPath(roundedRect: panel, cornerRadius: 70).fill()
                UIImage(named: "home_mascot_coin")?.draw(in: CGRect(x: 487, y: 3, width: 124, height: 124))
            default:
                let tag = UIBezierPath()
                tag.move(to: CGPoint(x: panel.minX, y: panel.minY))
                for index in 0...36 {
                    let x = panel.minX + CGFloat(index) * panel.width / 36
                    tag.addLine(to: CGPoint(x: x, y: panel.minY + (index % 2 == 0 ? 0 : 8)))
                }
                tag.addLine(to: CGPoint(x: panel.maxX, y: panel.maxY))
                for index in stride(from: 36, through: 0, by: -1) {
                    let x = panel.minX + CGFloat(index) * panel.width / 36
                    tag.addLine(to: CGPoint(x: x, y: panel.maxY - (index % 2 == 0 ? 0 : 8)))
                }
                tag.close(); paper.setFill(); tag.fill()
            }
            draw(title, rect: CGRect(x: textX, y: 94, width: textWidth, height: 46), font: .systemFont(ofSize: 28, weight: .semibold), color: foreground)
            let money = MoneyActivityFormat.yen(amount)
            var size: CGFloat = 82
            while (money as NSString).size(withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)]).width > textWidth && size > 12 { size -= 2 }
            draw(money, rect: CGRect(x: textX, y: 150, width: textWidth, height: 108), font: .monospacedDigitSystemFont(ofSize: size, weight: .bold), color: foreground)
        }
    }

    private func draw(_ text: String, rect: CGRect, font: UIFont, color: UIColor) {
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color])
    }
}
