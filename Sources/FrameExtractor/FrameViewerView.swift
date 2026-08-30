import SwiftUI
import AppKit

struct FrameViewerView: View {
    let folderURL: URL

    @State private var frameURLs: [URL] = []
    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if frameURLs.isEmpty {
                Text("No frames found in \(folderURL.lastPathComponent)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let image = NSImage(contentsOf: frameURLs[index]) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none) // scrubbing a UI recording — keep pixels crisp, no smoothing
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                // A plain, separate footer — not layered over the image —
                // so the filename is its own selectable text, not baked
                // into the picture.
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(frameURLs[index].lastPathComponent)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .textSelection(.enabled)

                        Button {
                            copyFrameWithLabelBurntIn()
                        } label: {
                            Label("Copy frame", systemImage: "doc.on.doc")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .help("Copy this frame as an image, with its filename burnt into the corner — paste it anywhere and the name travels with it")
                    }

                    HStack(spacing: 12) {
                        Button {
                            step(-1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .keyboardShortcut(.leftArrow, modifiers: [])

                        Slider(value: Binding(
                            get: { Double(index) },
                            set: { index = Int($0.rounded()) }
                        ), in: 0...Double(max(frameURLs.count - 1, 0)), step: 1)

                        Button {
                            step(1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .keyboardShortcut(.rightArrow, modifiers: [])

                        Text("\(index + 1) / \(frameURLs.count)")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .trailing)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .navigationTitle(folderURL.lastPathComponent)
        .onAppear(perform: loadFrames)
    }

    private func step(_ delta: Int) {
        guard !frameURLs.isEmpty else { return }
        index = min(max(index + delta, 0), frameURLs.count - 1)
    }

    private func loadFrames() {
        let contents = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        frameURLs = contents
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // Composites the filename into the bottom-left corner of the frame
    // itself, then puts the RESULT (not the original) on the clipboard —
    // Goran pastes straight into chat, so the label needs to travel
    // WITH the picture rather than depending on him typing it separately.
    //
    // Built on `CGContext` at the source image's real PIXEL dimensions,
    // not `NSImage.lockFocus()` — `lockFocus` draws at the SCREEN's
    // backing scale (e.g. 2x on a Retina Mac) regardless of the source
    // PNG's own pixel size, and `NSImage.writeObjects` hands off a TIFF
    // representation of that mismatched bitmap. A recording captured at
    // 3x (this Simulator's own scale) came out corrupted/unreadable to
    // whatever decoded it on paste ("failed to convert image") — going
    // through `CGImage` directly sidesteps display scale entirely, and
    // writing explicit PNG bytes is a format every paste target reads.
    private func copyFrameWithLabelBurntIn() {
        guard !frameURLs.isEmpty,
              let data = try? Data(contentsOf: frameURLs[index]),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
        let label = frameURLs[index].lastPathComponent

        let width = cgImage.width
        let height = cgImage.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // CGContext is bottom-up flipped relative to AppKit text drawing —
        // set up an NSGraphicsContext so `NSString.draw` lands right-side
        // up and where expected (near the bottom-left of the IMAGE, which
        // is the TOP-left of this flipped coordinate space).
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        let fontSize = max(28, CGFloat(height) * 0.03)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let textSize = (label as NSString).size(withAttributes: attributes)
        let padding: CGFloat = fontSize * 0.5
        let badgeRect = CGRect(x: padding, y: padding, width: textSize.width + padding * 2, height: textSize.height + padding)

        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 6, yRadius: 6).fill()
        (label as NSString).draw(at: CGPoint(x: badgeRect.minX + padding, y: badgeRect.minY + padding / 2), withAttributes: attributes)

        NSGraphicsContext.restoreGraphicsState()

        guard let composited = context.makeImage() else { return }
        let rep = NSBitmapImageRep(cgImage: composited)
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
    }
}
