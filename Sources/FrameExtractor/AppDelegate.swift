import AppKit

// Lets Finder route "Open With → Frame Extractor" and a drop onto the
// Dock/app icon to the same job queue the in-window drop zone uses —
// without this, dropping a file on the app ICON (not the window) does
// nothing, since SwiftUI's `.onDrop` only covers drops onto a view
// that's already on screen.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            JobRunner.shared.enqueue(url)
        }
    }
}
