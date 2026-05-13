import Foundation
import Combine

/// Watches a `.collab.json` sidecar file for external changes (e.g. OneDrive sync).
/// On change: reloads, merges with in-memory state, and publishes the merged document.
@MainActor
public final class CollabFileWatcher {
    private let engine: CollabEngine
    private var sidecarURL: URL?
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceWorkItem: DispatchWorkItem?

    /// Published whenever the sidecar is updated externally and merged.
    public let documentDidChange = PassthroughSubject<CollabDocument, Never>()

    public init(engine: CollabEngine) {
        self.engine = engine
    }

    deinit {
        debounceWorkItem?.cancel()
        source?.cancel()
    }

    /// Start watching the sidecar for the given markdown file.
    public func watch(for markdownURL: URL) {
        stop()
        let url = CollabEngine.sidecarURL(for: markdownURL)
        sidecarURL = url

        // Ensure the file exists so we can open a descriptor
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: "{}".data(using: .utf8))
        }

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.scheduleReload()
            }
        }

        src.setCancelHandler { [fd = fileDescriptor] in
            close(fd)
        }

        source = src
        src.resume()
    }

    public func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    // MARK: - Private

    private func scheduleReload() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reloadAndMerge()
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func reloadAndMerge() {
        guard let url = sidecarURL else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let remote = try? decoder.decode(CollabDocument.self, from: data) else { return }

        let result = MergeEngine.merge(local: engine.document, remote: remote)
        engine.document = result.merged
        try? engine.save()
        documentDidChange.send(result.merged)
    }
}
