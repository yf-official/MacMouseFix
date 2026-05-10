import AppKit
import Darwin

final class BackgroundAgentManager {
    static let shared = BackgroundAgentManager()

    private init() {}

    func ensureRunning() {
        guard PermissionManager.isAccessibilityTrusted else { return }
        guard let executableURL = Bundle.main.executableURL else { return }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--helper", "--parent-pid", String(getpid())]
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
        } catch {
            NSLog("MacMouseFixPro helper launch failed: \(error.localizedDescription)")
        }
    }

    func stopRunning() {
        let directory = SettingsStore.settingsURL.deletingLastPathComponent()
        let stopURL = directory.appendingPathComponent("helper.stop")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? "stop".data(using: .utf8)?.write(to: stopURL, options: .atomic)

        let pidURL = directory.appendingPathComponent("helper.pid")
        guard
            let raw = try? String(contentsOf: pidURL, encoding: .utf8),
            let pid = Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
            pid > 0
        else { return }

        kill(pid, SIGTERM)
    }
}
