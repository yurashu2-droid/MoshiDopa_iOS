import SwiftUI
import UIKit

/// The production ShareLink and XCTest evidence use the same bitmap output.
/// Rendering stays in memory; callers choose whether to attach or share it.
enum MDShareImageRenderer {
    @MainActor static func render<Content: View>(_ content: Content) -> UIImage? {
        let renderer = ImageRenderer(content: content.frame(width: 430))
        renderer.scale = 3
        return renderer.uiImage
    }
}
