import Foundation

enum MouseAction: String, CaseIterable, Codable {
    case passThrough = "Pass Through"
    case back = "Back"
    case forward = "Forward"
    case missionControl = "Mission Control"
    case appExpose = "App Expose"
    case showDesktop = "Show Desktop"
    case launchpad = "Launchpad"
    case spaceLeft = "Move Space Left"
    case spaceRight = "Move Space Right"
    case previousTab = "Previous Tab"
    case nextTab = "Next Tab"
    case newTab = "New Tab"
    case closeTab = "Close Tab"
    case refresh = "Refresh"
    case copy = "Copy"
    case paste = "Paste"
    case undo = "Undo"
    case redo = "Redo"
    case zoomIn = "Zoom In"
    case zoomOut = "Zoom Out"
    case pageUp = "Page Up"
    case pageDown = "Page Down"
    case escape = "Escape"
    case returnKey = "Return"
    case screenshotArea = "Screenshot Area"
    case lockScreen = "Lock Screen"
    case middleClick = "Middle Click"
    case disabled = "Disabled"

    var menuTitle: String {
        switch self {
        case .passThrough: return "保持原样"
        case .back: return "后退"
        case .forward: return "前进"
        case .missionControl: return "调度中心"
        case .appExpose: return "App Expose"
        case .showDesktop: return "显示桌面"
        case .launchpad: return "启动台"
        case .spaceLeft: return "切换到左侧桌面"
        case .spaceRight: return "切换到右侧桌面"
        case .previousTab: return "上一个标签页"
        case .nextTab: return "下一个标签页"
        case .newTab: return "新建标签页"
        case .closeTab: return "关闭标签页"
        case .refresh: return "刷新"
        case .copy: return "复制"
        case .paste: return "粘贴"
        case .undo: return "撤销"
        case .redo: return "重做"
        case .zoomIn: return "放大"
        case .zoomOut: return "缩小"
        case .pageUp: return "上一页"
        case .pageDown: return "下一页"
        case .escape: return "Esc"
        case .returnKey: return "回车"
        case .screenshotArea: return "区域截图"
        case .lockScreen: return "锁定屏幕"
        case .middleClick: return "中键点击"
        case .disabled: return "禁用"
        }
    }
}

struct MouseSettings: Codable, Equatable {
    static let currentVersion = 2

    var settingsVersion = MouseSettings.currentVersion
    var enabled = true
    var buttonActions: [Int: MouseAction] = MouseSettings.defaultButtonActions
    var naturalScrolling = false
    var scrollSpeed = 1.15
    var smoothScroll = true
    var smoothness = 0.88
    var pointerSmoothing = false
    var pointerSpeed = 1.0
    var pointerSmoothness = 0.28

    static let configurableButtons = [2, 3, 4]

    static let defaultButtonActions: [Int: MouseAction] = [
        2: .missionControl,
        3: .back,
        4: .forward
    ]

    init() {}

    func action(forButton button: Int) -> MouseAction {
        guard Self.configurableButtons.contains(button) else { return .passThrough }
        return buttonActions[button] ?? .passThrough
    }

    mutating func setAction(_ action: MouseAction, forButton button: Int) {
        guard Self.configurableButtons.contains(button) else { return }
        buttonActions[button] = action
    }

    static func displayName(forCGButton button: Int) -> String {
        switch button {
        case 2: return "滚轮按下"
        case 3: return "辅助按键 1"
        case 4: return "辅助按键 2"
        default: return "未使用按键 \(button)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case settingsVersion
        case buttonActions
        case button3Action
        case button4Action
        case middleButtonAction
        case naturalScrolling
        case scrollSpeed
        case smoothScroll
        case smoothness
        case pointerSmoothing
        case pointerSpeed
        case pointerSmoothness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settingsVersion = try container.decodeIfPresent(Int.self, forKey: .settingsVersion) ?? 1
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        naturalScrolling = try container.decodeIfPresent(Bool.self, forKey: .naturalScrolling) ?? false
        scrollSpeed = try container.decodeIfPresent(Double.self, forKey: .scrollSpeed) ?? 1.15
        smoothScroll = try container.decodeIfPresent(Bool.self, forKey: .smoothScroll) ?? true
        smoothness = try container.decodeIfPresent(Double.self, forKey: .smoothness) ?? 0.88
        if settingsVersion >= MouseSettings.currentVersion {
            pointerSmoothing = try container.decodeIfPresent(Bool.self, forKey: .pointerSmoothing) ?? false
        } else {
            pointerSmoothing = false
        }
        pointerSpeed = try container.decodeIfPresent(Double.self, forKey: .pointerSpeed) ?? 1.0
        pointerSmoothness = try container.decodeIfPresent(Double.self, forKey: .pointerSmoothness) ?? 0.28

        let storedActions = try container.decodeIfPresent([Int: MouseAction].self, forKey: .buttonActions)
        if let storedActions, !storedActions.isEmpty {
            var actions = MouseSettings.defaultButtonActions
            for button in MouseSettings.configurableButtons {
                if let action = storedActions[button] {
                    actions[button] = action
                }
            }
            buttonActions = actions
        } else {
            buttonActions = MouseSettings.defaultButtonActions
            if let action = try container.decodeIfPresent(MouseAction.self, forKey: .button3Action) {
                buttonActions[3] = action
            }
            if let action = try container.decodeIfPresent(MouseAction.self, forKey: .button4Action) {
                buttonActions[4] = action
            }
            if let action = try container.decodeIfPresent(MouseAction.self, forKey: .middleButtonAction) {
                buttonActions[2] = action
            }
        }

        scrollSpeed = max(0.2, min(4.0, scrollSpeed))
        smoothness = max(0.0, min(1.0, smoothness))
        pointerSpeed = max(0.5, min(2.0, pointerSpeed))
        pointerSmoothness = max(0.0, min(0.8, pointerSmoothness))
        settingsVersion = MouseSettings.currentVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(MouseSettings.currentVersion, forKey: .settingsVersion)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(buttonActions, forKey: .buttonActions)
        try container.encode(naturalScrolling, forKey: .naturalScrolling)
        try container.encode(scrollSpeed, forKey: .scrollSpeed)
        try container.encode(smoothScroll, forKey: .smoothScroll)
        try container.encode(smoothness, forKey: .smoothness)
        try container.encode(pointerSmoothing, forKey: .pointerSmoothing)
        try container.encode(pointerSpeed, forKey: .pointerSpeed)
        try container.encode(pointerSmoothness, forKey: .pointerSmoothness)
    }
}

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaultsKey = "MacMouseFixProSettings"
    var onChange: ((MouseSettings) -> Void)?

    private(set) var settings: MouseSettings {
        didSet {
            save()
            onChange?(settings)
        }
    }

    private init() {
        settings = Self.loadSettings(defaultsKey: defaultsKey)
    }

    func update(_ block: (inout MouseSettings) -> Void) {
        var next = settings
        block(&next)
        settings = next
    }

    func reset() {
        settings = MouseSettings()
    }

    @discardableResult
    func reloadFromDisk() -> Bool {
        let next = Self.loadSettings(defaultsKey: defaultsKey)
        guard next != settings else { return false }
        settings = next
        return true
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? FileManager.default.createDirectory(
            at: Self.settingsDirectory,
            withIntermediateDirectories: true
        )
        try? data.write(to: Self.settingsURL, options: .atomic)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static var settingsDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacMouseFixPro", isDirectory: true)
    }

    static var settingsURL: URL {
        settingsDirectory.appendingPathComponent("settings.json")
    }

    private static func loadSettings(defaultsKey: String) -> MouseSettings {
        if
            let data = try? Data(contentsOf: settingsURL),
            let decoded = try? JSONDecoder().decode(MouseSettings.self, from: data)
        {
            return decoded
        }

        if
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(MouseSettings.self, from: data)
        {
            return decoded
        }

        return MouseSettings()
    }
}
