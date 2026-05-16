import Foundation
import UIKit

struct CaptionedPhotoRenderer {
    func render(image: UIImage, caption: String, captionFont: CaptionFontOption, maxWidth: CGFloat = 1800) -> UIImage {
        let aspect = image.size.height / max(image.size.width, 1)
        let photoWidth = min(maxWidth, image.size.width)
        let photoHeight = photoWidth * aspect

        let border: CGFloat = photoWidth * 0.05
        let bottomPadding: CGFloat = photoWidth * 0.22

        let canvasWidth = photoWidth + border * 2
        let canvasHeight = photoHeight + border + bottomPadding

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight), format: format)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: canvasWidth, height: canvasHeight))
            UIColor.white.setFill()
            context.fill(rect)

            let imageFrame = CGRect(x: border, y: border, width: photoWidth, height: photoHeight)
            drawAspectFill(image: image, in: imageFrame)

            let captionRect = CGRect(x: border * 1.2, y: photoHeight + border + 8, width: photoWidth - border * 0.4, height: bottomPadding - 16)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: captionUIFont(for: captionFont, size: max(24, photoWidth * 0.045)),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]

            caption.draw(with: captionRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attrs, context: nil)
        }
    }

    private func captionUIFont(for option: CaptionFontOption, size: CGFloat) -> UIFont {
        switch option {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: .regular)
        case .rounded:
            let base = UIFont.systemFont(ofSize: size, weight: .regular)
            if let descriptor = base.fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        case .serif:
            return UIFont(name: "TimesNewRomanPSMT", size: size) ?? UIFont.systemFont(ofSize: size, weight: .regular)
        case .monospaced:
            return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .marker:
            return UIFont(name: "MarkerFelt-Wide", size: size) ?? UIFont.systemFont(ofSize: size, weight: .regular)
        case .script:
            return UIFont(name: "SnellRoundhand", size: size) ?? UIFont.italicSystemFont(ofSize: size)
        }
    }

    private func drawAspectFill(image: UIImage, in rect: CGRect) {
        let imageAspect = image.size.width / max(image.size.height, 1)
        let rectAspect = rect.width / max(rect.height, 1)

        var drawRect = rect
        if imageAspect > rectAspect {
            let width = rect.height * imageAspect
            drawRect.origin.x -= (width - rect.width) / 2
            drawRect.size.width = width
        } else {
            let height = rect.width / imageAspect
            drawRect.origin.y -= (height - rect.height) / 2
            drawRect.size.height = height
        }

        image.draw(in: drawRect)
    }
}
