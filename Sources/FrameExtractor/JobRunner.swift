import Foundation

@MainActor
final class Job: ObservableObject, Identifiable {
    let id = UUID()
    let sourceURL: URL
    @Published var status: Status = .running
    @Published var frameCount: Int = 0

    enum Status: Equatable {
        case running
        case done(outputDir: URL, frameCount: Int)
        case failed(String)
    }

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }
}

@MainActor
final class JobRunner: ObservableObject {
    // Shared across the app-icon/Dock drop path (AppDelegate) and the
    // in-window drop zone (ContentView) — both need to land jobs in the
    // SAME list, so this can't be a plain per-view @StateObject.
    static let shared = JobRunner()

    @Published var jobs: [Job] = []

    // fps=12 + mpdecimate drops near-duplicate frames (long-held still
    // screens collapse to one frame instead of a dozen identical ones);
    // scale=390 matches an iPhone's point width so frames are already
    // sized for reading, not full device-pixel resolution.
    private let filterGraph = "fps=12,mpdecimate,scale=390:-1"
    private let ffmpegCandidates = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]

    func enqueue(_ url: URL) {
        let job = Job(sourceURL: url)
        jobs.insert(job, at: 0)
        Task { await run(job) }
    }

    private func resolvedFfmpegPath() -> String? {
        ffmpegCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func run(_ job: Job) async {
        guard let ffmpeg = resolvedFfmpegPath() else {
            job.status = .failed("ffmpeg not found (checked \(ffmpegCandidates.joined(separator: ", ")))")
            return
        }

        let sourceDir = job.sourceURL.deletingLastPathComponent()
        let baseName = job.sourceURL.deletingPathExtension().lastPathComponent
        let outDir = sourceDir.appendingPathComponent("\(baseName)_frames")

        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        } catch {
            job.status = .failed("couldn't create \(outDir.path): \(error.localizedDescription)")
            return
        }

        let outputPattern = outDir.appendingPathComponent("frame_%05d.png").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = [
            "-y", "-i", job.sourceURL.path,
            "-vf", filterGraph,
            "-fps_mode", "vfr",
            outputPattern
        ]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            job.status = .failed("couldn't launch ffmpeg: \(error.localizedDescription)")
            return
        }

        let stderrData = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data)
            }
        }
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let message = String(data: stderrData, encoding: .utf8) ?? "ffmpeg exited \(process.terminationStatus)"
            job.status = .failed(message.split(separator: "\n").suffix(4).joined(separator: "\n"))
            return
        }

        let frameCount = (try? FileManager.default.contentsOfDirectory(atPath: outDir.path))?
            .filter { $0.hasSuffix(".png") }.count ?? 0
        job.status = .done(outputDir: outDir, frameCount: frameCount)
    }
}
