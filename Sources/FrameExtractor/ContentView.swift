import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var runner = JobRunner()
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            dropZone
            Divider()
            jobList
        }
        .frame(width: 460, height: 520)
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Drop a screen recording here")
                .font(.headline)
            Text("fps=12 · duplicate frames dropped · resized to 390pt wide")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        )
        .padding(16)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var jobList: some View {
        Group {
            if runner.jobs.isEmpty {
                Spacer()
                Text("Processed videos show up here")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(runner.jobs) { job in
                    JobRow(job: job)
                }
                .listStyle(.inset)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    runner.enqueue(url)
                }
            }
            accepted = true
        }
        return accepted
    }
}

private struct JobRow: View {
    @ObservedObject var job: Job

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon
            VStack(alignment: .leading, spacing: 3) {
                Text(job.sourceURL.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusText
            }
            Spacer()
            if case .done(let outDir, _) = job.status {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([outDir])
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var statusIcon: some View {
        switch job.status {
        case .running:
            ProgressView().controlSize(.small).frame(width: 16, height: 16)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    @ViewBuilder private var statusText: some View {
        switch job.status {
        case .running:
            Text("extracting…").font(.caption).foregroundStyle(.secondary)
        case .done(let outDir, let count):
            Text("\(count) frames → \(outDir.lastPathComponent)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(3)
        }
    }
}
