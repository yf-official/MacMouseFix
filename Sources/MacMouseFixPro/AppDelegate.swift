import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var retainedDelegate: AppDelegate?

    private let store = SettingsStore.shared
    private let agent = BackgroundAgentManager.shared
    private var settingsWindowController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private var activeLanguage = AppLanguage.simplifiedChinese

    private var language: AppLanguage { store.settings.language }

    private func text(_ chinese: String, _ english: String) -> String {
        language.text(chinese, english)
    }

    static func main() {
        if CommandLine.arguments.contains("--helper") {
            HelperDaemon.run()
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupObservers()
        showSettings()

        startEngineIfPossible(promptIfNeeded: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSettings()
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: text("打开设置窗口", "Open Settings Window"),
            action: #selector(showSettings),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)
        return menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        agent.stopRunning()
    }

    private func setupObservers() {
        activeLanguage = language
        store.onChange = { [weak self] settings in
            guard let self else { return }
            self.agent.ensureRunning()

            if settings.language != self.activeLanguage {
                self.activeLanguage = settings.language
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.settingsWindowController?.applyLanguageChange()
                    self.settingsWindowController?.setStatus(self.text(
                        "设置已保存，后台代理会自动应用。",
                        "Settings saved. The background agent will apply them automatically."
                    ))
                }
            } else {
                self.settingsWindowController?.reload()
                self.settingsWindowController?.setStatus(self.text(
                    "设置已保存，后台代理会自动应用。",
                    "Settings saved. The background agent will apply them automatically."
                ))
            }

            self.rebuildStatusMenu()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "MMF"
        rebuildStatusMenu()
    }

    private func startEngineIfPossible(promptIfNeeded: Bool) {
        if PermissionManager.isAccessibilityTrusted {
            permissionTimer?.invalidate()
            permissionTimer = nil
            agent.ensureRunning()
            settingsWindowController?.setStatus(text(
                "后台代理已启动。关闭窗口会继续生效；选择“退出并停止优化”会完全停止。",
                "The background agent is running. Closing this window keeps optimization active; Quit and Stop Optimization stops it completely."
            ))
            settingsWindowController?.reload()
            return
        }

        settingsWindowController?.setStatus(text(
            "正在等待辅助功能权限。",
            "Waiting for Accessibility access."
        ))
        if promptIfNeeded {
            PermissionManager.requestAccessibility()
        }
        startPermissionPolling()
    }

    private func startPermissionPolling() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.startEngineIfPossible(promptIfNeeded: false)
        }
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: text("显示设置", "Show Settings"), action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(NSMenuItem.separator())

        let enabledTitle = store.settings.enabled
            ? text("暂停鼠标优化", "Pause Mouse Optimization")
            : text("启用鼠标优化", "Enable Mouse Optimization")
        menu.addItem(withTitle: enabledTitle, action: #selector(toggleEnabledFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: text("申请辅助功能权限", "Request Accessibility Access"), action: #selector(requestPermissionFromMenu), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())

        for button in MouseSettings.configurableButtons {
            let action = store.settings.action(forButton: button)
            let physicalSuffix = button > 2
                ? text(
                    "（编号 \(store.settings.physicalButton(forLogicalButton: button) ?? button)）",
                    " (Button \(store.settings.physicalButton(forLogicalButton: button) ?? button))"
                )
                : ""
            let item = NSMenuItem(
                title: "\(MouseSettings.displayName(forCGButton: button, language: language))\(physicalSuffix): \(action.menuTitle(for: language))",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }
        for button in [3, 4] {
            let upAction = store.settings.scrollGestureAction(forButton: button, direction: .up)
            let downAction = store.settings.scrollGestureAction(forButton: button, direction: .down)
            let item = NSMenuItem(
                title: text(
                    "\(MouseSettings.displayName(forCGButton: button, language: language)) + 滚轮：↑ \(upAction.menuTitle(for: language)) / ↓ \(downAction.menuTitle(for: language))",
                    "\(MouseSettings.displayName(forCGButton: button, language: language)) + Wheel: ↑ \(upAction.menuTitle(for: language)) / ↓ \(downAction.menuTitle(for: language))"
                ),
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }
        let scroll = NSMenuItem(
            title: String(
                format: text("滚动：%.1fx / 丝滑 %.0f%%", "Scrolling: %.1fx / Smoothness %.0f%%"),
                store.settings.scrollSpeed,
                store.settings.smoothness * 100
            ),
            action: nil,
            keyEquivalent: ""
        )
        scroll.isEnabled = false
        menu.addItem(scroll)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: text("隐藏设置窗口（后台继续）", "Hide Settings (Keep Running)"), action: #selector(hideSettings), keyEquivalent: "w").target = self
        menu.addItem(withTitle: text("退出并停止优化", "Quit and Stop Optimization"), action: #selector(quitAndStop), keyEquivalent: "q").target = self
        statusItem?.menu = menu
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.reload()
    }

    @objc private func toggleEnabledFromMenu() {
        store.update { $0.enabled.toggle() }
    }

    @objc private func requestPermissionFromMenu() {
        PermissionManager.requestAccessibility()
        PermissionManager.openAccessibilitySettings()
        startPermissionPolling()
        settingsWindowController?.reload()
    }

    @objc private func hideSettings() {
        settingsWindowController?.close()
    }

    @objc private func quitAndStop() {
        agent.stopRunning()
        NSApp.terminate(nil)
    }
}
