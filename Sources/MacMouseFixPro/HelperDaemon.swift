import ApplicationServices
import Darwin
import Foundation

enum HelperDaemon {
    private static var lockDescriptor: Int32 = -1
    private static var parentPID: Int32?

    static func run() {
        parentPID = parseParentPID()
        guard acquireLock() else {
            exit(0)
        }
        removeStopFile()
        writePID()

        let store = SettingsStore.shared
        let engine = MouseEngine.shared
        engine.onStatusChange = { status in
            FileLogger.write(status)
        }

        guard PermissionManager.isAccessibilityTrusted else {
            FileLogger.write("后台代理缺少辅助功能权限，无法启动鼠标引擎。")
            exit(1)
        }

        engine.start(with: store.settings)

        let timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            if shouldStop() || parentProcessEnded() {
                engine.stop()
                cleanupFiles()
                exit(0)
            }
            if store.reloadFromDisk() {
                engine.update(settings: store.settings)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.run()
    }

    private static func parseParentPID() -> Int32? {
        let arguments = CommandLine.arguments
        guard
            let index = arguments.firstIndex(of: "--parent-pid"),
            arguments.indices.contains(index + 1),
            let pid = Int32(arguments[index + 1])
        else { return nil }
        return pid
    }

    private static func acquireLock() -> Bool {
        let directory = SettingsStore.settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = directory.appendingPathComponent("helper.lock")
        lockDescriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockDescriptor >= 0 else { return false }
        return flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0
    }

    private static var directory: URL {
        SettingsStore.settingsURL.deletingLastPathComponent()
    }

    private static var pidURL: URL {
        directory.appendingPathComponent("helper.pid")
    }

    private static var stopURL: URL {
        directory.appendingPathComponent("helper.stop")
    }

    private static func writePID() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pid = String(getpid())
        try? pid.data(using: .utf8)?.write(to: pidURL, options: .atomic)
    }

    private static func shouldStop() -> Bool {
        FileManager.default.fileExists(atPath: stopURL.path)
    }

    private static func parentProcessEnded() -> Bool {
        guard let parentPID, parentPID > 1 else { return false }
        if kill(parentPID, 0) == 0 {
            return false
        }
        return errno == ESRCH
    }

    private static func removeStopFile() {
        try? FileManager.default.removeItem(at: stopURL)
    }

    private static func cleanupFiles() {
        removeStopFile()
        try? FileManager.default.removeItem(at: pidURL)
    }
}

enum FileLogger {
    static func write(_ message: String) {
        let directory = SettingsStore.settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("helper.log")
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url)
        }
    }
}
