import AppKit
import Darwin

final class BackgroundAgentManager {
    static let shared = BackgroundAgentManager()

    private var helperProcess: Process?
    private var isStopping = false

    private init() {}

    func ensureRunning() {
        guard PermissionManager.isAccessibilityTrusted else { return }
        guard let executableURL = Bundle.main.executableURL else { return }
        guard helperProcess?.isRunning != true else { return }

        isStopping = false

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--helper", "--parent-pid", String(getpid())]
        process.standardOutput = nil
        process.standardError = nil
        process.terminationHandler = { [weak self, weak process] _ in
            DispatchQueue.main.async {
                guard let self, self.helperProcess === process else { return }
                self.helperProcess = nil
                guard !self.isStopping, NSApp.isRunning else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.ensureRunning()
                }
            }
        }

        do {
            try process.run()
            helperProcess = process
        } catch {
            NSLog("MacMouseFixPro helper launch failed: \(error.localizedDescription)")
        }
    }

    func stopRunning() {
        isStopping = true
        let directory = SettingsStore.settingsURL.deletingLastPathComponent()
        let stopURL = directory.appendingPathComponent("helper.stop")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? "stop".data(using: .utf8)?.write(to: stopURL, options: .atomic)

        let pidURL = directory.appendingPathComponent("helper.pid")
        if helperProcess?.isRunning == true {
            helperProcess?.terminate()
        }

        guard
            let raw = try? String(contentsOf: pidURL, encoding: .utf8),
            let pid = Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
            pid > 0
        else { return }

        kill(pid, SIGTERM)
    }
}
