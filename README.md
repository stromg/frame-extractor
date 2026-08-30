# frame-extractor

Drop a screen recording onto the window; it runs ffmpeg (`fps=12,mpdecimate,scale=390:-1` + `-fps_mode vfr`) and writes deduplicated, resized PNG frames to a `<name>_frames/` folder next to the source file.

Native SwiftUI macOS app, built as a Swift Package — no Xcode project needed:

```
swift run
```

Requires ffmpeg (`brew install ffmpeg`).
