import Foundation

struct ButtonDiagnostic: Codable, Equatable {
    let timestamp: Date
    let physicalButton: Int
    let logicalButton: Int?
    let action: MouseAction?
}

enum RuntimeStatusStore {
    private static let queue = DispatchQueue(label: "MacMouseFixPro.runtime-status", qos: .utility)

    private static var buttonDiagnosticURL: URL {
        SettingsStore.settingsURL
            .deletingLastPathComponent()
            .appendingPathComponent("last-button.json")
    }

    static func recordButton(physicalButton: Int, logicalButton: Int?, action: MouseAction?) {
        let diagnostic = ButtonDiagnostic(
            timestamp: Date(),
            physicalButton: physicalButton,
            logicalButton: logicalButton,
            action: action
        )

        queue.async {
            guard let data = try? JSONEncoder().encode(diagnostic) else { return }
            let directory = buttonDiagnosticURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: buttonDiagnosticURL, options: .atomic)
        }
    }

    static func latestButton() -> ButtonDiagnostic? {
        guard
            let data = try? Data(contentsOf: buttonDiagnosticURL),
            let diagnostic = try? JSONDecoder().decode(ButtonDiagnostic.self, from: data)
        else { return nil }
        return diagnostic
    }
}
