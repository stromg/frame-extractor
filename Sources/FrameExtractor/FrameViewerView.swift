import SwiftUI
import AppKit

struct FrameViewerView: View {
    let folderURL: URL

    @State private var frameURLs: [URL] = []
    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            if frameURLs.isEmpty {
                Text("No frames found in \(folderURL.lastPathComponent)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    if let image = NSImage(contentsOf: frameURLs[index]) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none) // scrubbing a UI recording — keep pixels crisp, no smoothing
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))

                Text(frameURLs[index].lastPathComponent)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .textSelection(.enabled) // so it can be copy-pasted straight into an annotation
                    .padding(.top, 4)

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
                .padding([.horizontal, .bottom], 12)
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
}
