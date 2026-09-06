import ApplicationServices
import Darwin
import Foundation

enum HelperDaemon {
    private static var lockDescriptor: Int32 = -1
    private static var parentPID: Int32?
    private static var shutdownSources: [DispatchSourceSignal] = []
    private static var healthTimer: Timer?
    private static var isShuttingDown = false

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
        engine.onButtonEvent = { physicalButton, logicalButton, action in
            RuntimeStatusStore.recordButton(
                physicalButton: physicalButton,
                logicalButton: logicalButton,
                action: action
            )
        }

        guard PermissionManager.isAccessibilityTrusted else {
            FileLogger.write("后台代理缺少辅助功能权限，无法启动鼠标引擎。")
            exit(1)
        }

        engine.start(with: store.settings)
        installSignalHandlers(engine: engine)

        healthTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            if shouldStop() || parentProcessEnded() {
                shutdown(engine: engine)
            }
            if store.reloadFromDisk() {
                engine.update(settings: store.settings)
            }
        }
        if let healthTimer {
            RunLoop.main.add(healthTimer, forMode: .common)
        }
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

    private static func installSignalHandlers(engine: MouseEngine) {
        for signalNumber in [SIGTERM, SIGINT] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler {
                shutdown(engine: engine)
            }
            source.resume()
            shutdownSources.append(source)
        }
    }

    private static func shutdown(engine: MouseEngine) {
        guard !isShuttingDown else { return }
        isShuttingDown = true
        healthTimer?.invalidate()
        healthTimer = nil
        engine.stop()
        cleanupFiles()
        exit(0)
    }

    private static func cleanupFiles() {
        removeStopFile()
        try? FileManager.default.removeItem(at: pidURL)
        if lockDescriptor >= 0 {
            flock(lockDescriptor, LOCK_UN)
            close(lockDescriptor)
            lockDescriptor = -1
        }
    }
}

enum FileLogger {
    private static let maximumLogSize: UInt64 = 512 * 1024

    static func write(_ message: String) {
        let directory = SettingsStore.settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("helper.log")
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? UInt64,
            size > maximumLogSize
        {
            try? FileManager.default.removeItem(at: url)
        }

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
