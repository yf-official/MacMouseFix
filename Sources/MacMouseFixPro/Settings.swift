import Foundation

enum AppLanguage: String, CaseIterable, Codable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }

    func text(_ chinese: String, _ english: String) -> String {
        self == .simplifiedChinese ? chinese : english
    }
}

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
    case volumeUp = "Volume Up"
    case volumeDown = "Volume Down"
    case mute = "Mute"
    case previousApp = "Previous App"
    case nextApp = "Next App"
    case disabled = "Disabled"

    func menuTitle(for language: AppLanguage) -> String {
        switch self {
        case .passThrough: return language.text("保持原样", "Pass Through")
        case .back: return language.text("后退", "Back")
        case .forward: return language.text("前进", "Forward")
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Expose"
        case .showDesktop: return language.text("显示桌面", "Show Desktop")
        case .launchpad: return "Launchpad"
        case .spaceLeft: return language.text("切换到左侧桌面", "Move One Space Left")
        case .spaceRight: return language.text("切换到右侧桌面", "Move One Space Right")
        case .previousTab: return language.text("上一个标签页", "Previous Tab")
        case .nextTab: return language.text("下一个标签页", "Next Tab")
        case .newTab: return language.text("新建标签页", "New Tab")
        case .closeTab: return language.text("关闭标签页", "Close Tab")
        case .refresh: return language.text("刷新", "Refresh")
        case .copy: return language.text("复制", "Copy")
        case .paste: return language.text("粘贴", "Paste")
        case .undo: return language.text("撤销", "Undo")
        case .redo: return language.text("重做", "Redo")
        case .zoomIn: return language.text("捏合放大", "Pinch to Zoom In")
        case .zoomOut: return language.text("捏合缩小", "Pinch to Zoom Out")
        case .pageUp: return language.text("上一页", "Page Up")
        case .pageDown: return language.text("下一页", "Page Down")
        case .escape: return "Esc"
        case .returnKey: return language.text("回车", "Return")
        case .screenshotArea: return language.text("区域截图", "Capture Selection")
        case .lockScreen: return language.text("锁定屏幕", "Lock Screen")
        case .middleClick: return language.text("中键点击", "Middle Click")
        case .volumeUp: return language.text("增大音量", "Volume Up")
        case .volumeDown: return language.text("减小音量", "Volume Down")
        case .mute: return language.text("静音 / 取消静音", "Mute / Unmute")
        case .previousApp: return language.text("上一个 App", "Previous App")
        case .nextApp: return language.text("下一个 App", "Next App")
        case .disabled: return language.text("禁用", "Disabled")
        }
    }
}

enum ScrollGestureDirection: String, CaseIterable, Codable {
    case up
    case down

    func menuTitle(for language: AppLanguage) -> String {
        switch self {
        case .up: return language.text("滚轮向上", "Wheel Up")
        case .down: return language.text("滚轮向下", "Wheel Down")
        }
    }
}

struct ButtonScrollGesture: Codable, Equatable {
    var upAction: MouseAction
    var downAction: MouseAction

    func action(for direction: ScrollGestureDirection) -> MouseAction {
        direction == .up ? upAction : downAction
    }

    mutating func setAction(_ action: MouseAction, for direction: ScrollGestureDirection) {
        switch direction {
        case .up: upAction = action
        case .down: downAction = action
        }
    }
}

struct MouseSettings: Codable, Equatable {
    static let currentVersion = 5

    var settingsVersion = MouseSettings.currentVersion
    var language = AppLanguage.simplifiedChinese
    var enabled = true
    var buttonActions: [Int: MouseAction] = MouseSettings.defaultButtonActions
    var naturalScrolling = false
    var scrollSpeed = 1.15
    var smoothScroll = true
    var smoothness = 0.88
    var pointerSmoothing = false
    var pointerSpeed = 1.0
    var pointerSmoothness = 0.28
    var auxiliaryButton1PhysicalID = 3
    var auxiliaryButton2PhysicalID = 4
    var buttonScrollGestures = MouseSettings.defaultButtonScrollGestures

    static let configurableButtons = [2, 3, 4]

    static let defaultButtonActions: [Int: MouseAction] = [
        2: .missionControl,
        3: .back,
        4: .forward
    ]

    static let defaultButtonScrollGestures: [Int: ButtonScrollGesture] = [
        3: ButtonScrollGesture(upAction: .volumeUp, downAction: .volumeDown),
        4: ButtonScrollGesture(upAction: .zoomIn, downAction: .zoomOut)
    ]

    init() {}

    func action(forButton button: Int) -> MouseAction {
        guard Self.configurableButtons.contains(button) else { return .passThrough }
        return buttonActions[button] ?? .passThrough
    }

    func logicalButton(forPhysicalButton physicalButton: Int) -> Int? {
        switch physicalButton {
        case 2:
            return 2
        case auxiliaryButton1PhysicalID:
            return 3
        case auxiliaryButton2PhysicalID:
            return 4
        default:
            return nil
        }
    }

    func physicalButton(forLogicalButton logicalButton: Int) -> Int? {
        switch logicalButton {
        case 2: return 2
        case 3: return auxiliaryButton1PhysicalID
        case 4: return auxiliaryButton2PhysicalID
        default: return nil
        }
    }

    mutating func setPhysicalButton(_ physicalButton: Int, forLogicalButton logicalButton: Int) {
        guard (3...31).contains(physicalButton) else { return }

        switch logicalButton {
        case 3:
            if physicalButton == auxiliaryButton2PhysicalID {
                auxiliaryButton2PhysicalID = auxiliaryButton1PhysicalID
            }
            auxiliaryButton1PhysicalID = physicalButton
        case 4:
            if physicalButton == auxiliaryButton1PhysicalID {
                auxiliaryButton1PhysicalID = auxiliaryButton2PhysicalID
            }
            auxiliaryButton2PhysicalID = physicalButton
        default:
            break
        }
    }

    mutating func setAction(_ action: MouseAction, forButton button: Int) {
        guard Self.configurableButtons.contains(button) else { return }
        buttonActions[button] = action
    }

    func scrollGestureAction(
        forButton button: Int,
        direction: ScrollGestureDirection
    ) -> MouseAction {
        guard button == 3 || button == 4 else { return .passThrough }
        return buttonScrollGestures[button]?.action(for: direction) ?? .passThrough
    }

    func hasScrollGesture(forButton button: Int) -> Bool {
        ScrollGestureDirection.allCases.contains {
            scrollGestureAction(forButton: button, direction: $0) != .passThrough
        }
    }

    mutating func setScrollGestureAction(
        _ action: MouseAction,
        forButton button: Int,
        direction: ScrollGestureDirection
    ) {
        guard button == 3 || button == 4 else { return }
        var gesture = buttonScrollGestures[button]
            ?? ButtonScrollGesture(upAction: .passThrough, downAction: .passThrough)
        gesture.setAction(action, for: direction)
        buttonScrollGestures[button] = gesture
    }

    static func displayName(forCGButton button: Int, language: AppLanguage) -> String {
        switch button {
        case 2: return language.text("滚轮按下", "Wheel Click")
        case 3: return language.text("辅助按键 1", "Auxiliary Button 1")
        case 4: return language.text("辅助按键 2", "Auxiliary Button 2")
        default: return language.text("未使用按键 \(button)", "Unused Button \(button)")
        }
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case settingsVersion
        case language
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
        case auxiliaryButton1PhysicalID
        case auxiliaryButton2PhysicalID
        case buttonScrollGestures
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settingsVersion = try container.decodeIfPresent(Int.self, forKey: .settingsVersion) ?? 1
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .simplifiedChinese
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        naturalScrolling = try container.decodeIfPresent(Bool.self, forKey: .naturalScrolling) ?? false
        scrollSpeed = try container.decodeIfPresent(Double.self, forKey: .scrollSpeed) ?? 1.15
        smoothScroll = try container.decodeIfPresent(Bool.self, forKey: .smoothScroll) ?? true
        smoothness = try container.decodeIfPresent(Double.self, forKey: .smoothness) ?? 0.88
        if settingsVersion >= 2 {
            pointerSmoothing = try container.decodeIfPresent(Bool.self, forKey: .pointerSmoothing) ?? false
        } else {
            pointerSmoothing = false
        }
        pointerSpeed = try container.decodeIfPresent(Double.self, forKey: .pointerSpeed) ?? 1.0
        pointerSmoothness = try container.decodeIfPresent(Double.self, forKey: .pointerSmoothness) ?? 0.28
        auxiliaryButton1PhysicalID = try container.decodeIfPresent(Int.self, forKey: .auxiliaryButton1PhysicalID) ?? 3
        auxiliaryButton2PhysicalID = try container.decodeIfPresent(Int.self, forKey: .auxiliaryButton2PhysicalID) ?? 4
        let storedScrollGestures = try container.decodeIfPresent(
            [Int: ButtonScrollGesture].self,
            forKey: .buttonScrollGestures
        )
        if let storedScrollGestures {
            var gestures = MouseSettings.defaultButtonScrollGestures
            for button in [3, 4] {
                if let gesture = storedScrollGestures[button] {
                    gestures[button] = gesture
                }
            }
            buttonScrollGestures = gestures
        } else {
            buttonScrollGestures = MouseSettings.defaultButtonScrollGestures
        }

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
        if !(3...31).contains(auxiliaryButton1PhysicalID) {
            auxiliaryButton1PhysicalID = 3
        }
        if !(3...31).contains(auxiliaryButton2PhysicalID) || auxiliaryButton2PhysicalID == auxiliaryButton1PhysicalID {
            auxiliaryButton2PhysicalID = auxiliaryButton1PhysicalID == 4 ? 3 : 4
        }
        settingsVersion = MouseSettings.currentVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(MouseSettings.currentVersion, forKey: .settingsVersion)
        try container.encode(language, forKey: .language)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(buttonActions, forKey: .buttonActions)
        try container.encode(naturalScrolling, forKey: .naturalScrolling)
        try container.encode(scrollSpeed, forKey: .scrollSpeed)
        try container.encode(smoothScroll, forKey: .smoothScroll)
        try container.encode(smoothness, forKey: .smoothness)
        try container.encode(pointerSmoothing, forKey: .pointerSmoothing)
        try container.encode(pointerSpeed, forKey: .pointerSpeed)
        try container.encode(pointerSmoothness, forKey: .pointerSmoothness)
        try container.encode(auxiliaryButton1PhysicalID, forKey: .auxiliaryButton1PhysicalID)
        try container.encode(auxiliaryButton2PhysicalID, forKey: .auxiliaryButton2PhysicalID)
        try container.encode(buttonScrollGestures, forKey: .buttonScrollGestures)
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
