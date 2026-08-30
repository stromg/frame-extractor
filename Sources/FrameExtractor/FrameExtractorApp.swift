import SwiftUI

@main
struct FrameExtractorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Frames", id: "frame-viewer", for: URL.self) { $folderURL in
            if let folderURL {
                FrameViewerView(folderURL: folderURL)
            }
        }
    }
}
