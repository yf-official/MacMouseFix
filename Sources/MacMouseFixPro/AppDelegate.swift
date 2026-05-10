import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var retainedDelegate: AppDelegate?

    private let store = SettingsStore.shared
    private let agent = BackgroundAgentManager.shared
    private var settingsWindowController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?

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

    func applicationWillTerminate(_ notification: Notification) {
        agent.stopRunning()
    }

    private func setupObservers() {
        store.onChange = { [weak self] settings in
            self?.agent.ensureRunning()
            self?.settingsWindowController?.reload()
            self?.settingsWindowController?.setStatus("设置已保存，后台代理会自动应用。")
            self?.rebuildStatusMenu()
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
            settingsWindowController?.setStatus("后台代理已启动。关闭窗口会继续生效；选择“退出并停止优化”会完全停止。")
            settingsWindowController?.reload()
            return
        }

        settingsWindowController?.setStatus("正在等待辅助功能权限。")
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
        menu.addItem(withTitle: "显示设置", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(NSMenuItem.separator())

        let enabledTitle = store.settings.enabled ? "暂停鼠标优化" : "启用鼠标优化"
        menu.addItem(withTitle: enabledTitle, action: #selector(toggleEnabledFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: "申请辅助功能权限", action: #selector(requestPermissionFromMenu), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())

        for button in MouseSettings.configurableButtons {
            let action = store.settings.action(forButton: button)
            let item = NSMenuItem(
                title: "\(MouseSettings.displayName(forCGButton: button))：\(action.menuTitle)",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }
        let scroll = NSMenuItem(
            title: String(
                format: "滚动：%.1fx / 丝滑 %.0f%%",
                store.settings.scrollSpeed,
                store.settings.smoothness * 100
            ),
            action: nil,
            keyEquivalent: ""
        )
        scroll.isEnabled = false
        menu.addItem(scroll)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "隐藏设置窗口（后台继续）", action: #selector(hideSettings), keyEquivalent: "w").target = self
        menu.addItem(withTitle: "退出并停止优化", action: #selector(quitAndStop), keyEquivalent: "q").target = self
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
