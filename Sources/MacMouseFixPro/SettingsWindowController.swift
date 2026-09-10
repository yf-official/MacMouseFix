import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let store = SettingsStore.shared

    private let statusLabel = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let enabledCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let naturalCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let smoothCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let pointerCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let languagePopup = NSPopUpButton()
    private let speedSlider = NSSlider(value: 1.15, minValue: 0.2, maxValue: 4.0, target: nil, action: nil)
    private let smoothnessSlider = NSSlider(value: 0.88, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let pointerSpeedSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 2.0, target: nil, action: nil)
    private let pointerSmoothnessSlider = NSSlider(value: 0.28, minValue: 0.0, maxValue: 0.8, target: nil, action: nil)
    private let speedValueLabel = NSTextField(labelWithString: "1.2x")
    private let smoothnessValueLabel = NSTextField(labelWithString: "88%")
    private let pointerSpeedValueLabel = NSTextField(labelWithString: "1.0x")
    private let pointerSmoothnessValueLabel = NSTextField(labelWithString: "28%")
    private let buttonDiagnosticLabel = NSTextField(labelWithString: "")
    private var actionPopups: [Int: NSPopUpButton] = [:]
    private var physicalIDPopups: [Int: NSPopUpButton] = [:]
    private var gestureActionPopups: [String: NSPopUpButton] = [:]
    private var diagnosticTimer: Timer?
    private var scrollView: NSScrollView?

    private var language: AppLanguage { store.settings.language }

    private func text(_ chinese: String, _ english: String) -> String {
        language.text(chinese, english)
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 560, height: 420)
        window.title = "Mac Mouse Fix Pro"
        window.center()
        self.init(window: window)
        window.delegate = self
        buildUI()
        reload()
        startDiagnosticPolling()
    }

    deinit {
        diagnosticTimer?.invalidate()
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        startDiagnosticPolling()
    }

    func windowWillClose(_ notification: Notification) {
        diagnosticTimer?.invalidate()
        diagnosticTimer = nil
    }

    func applyLanguageChange() {
        let originalFrame = window?.frame
        window?.disableScreenUpdatesUntilFlush()
        buildUI()
        reload()
        if let originalFrame {
            window?.setFrame(originalFrame, display: false)
        }
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let previousScrollView = scrollView
        let previousScrollOrigin = previousScrollView?.contentView.bounds.origin ?? .zero
        actionPopups.removeAll(keepingCapacity: true)
        physicalIDPopups.removeAll(keepingCapacity: true)
        gestureActionPopups.removeAll(keepingCapacity: true)

        enabledCheckbox.title = text("启用鼠标优化", "Enable Mouse Optimization")
        naturalCheckbox.title = text("自然滚动方向", "Natural Scrolling Direction")
        smoothCheckbox.title = text("启用触控板式丝滑滚动（推荐）", "Enable Trackpad-like Smooth Scrolling (Recommended)")
        pointerCheckbox.title = text("启用鼠标指针平滑", "Enable Pointer Smoothing")

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView = scrollView

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        contentView.addSubview(scrollView)

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(root)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            root.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: documentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        let title = NSTextField(labelWithString: "Mac Mouse Fix Pro")
        title.font = .systemFont(ofSize: 23, weight: .bold)
        let subtitle = NSTextField(labelWithString: text(
            "鼠标优化 · 配置侧键点击、按住侧键滚动、丝滑滚轮和指针手感。触控板连续滚动保持系统原样。",
            "Configure buttons, button-wheel gestures, smooth scrolling, and pointer response. Trackpad scrolling remains unchanged."
        ))
        subtitle.textColor = .secondaryLabelColor
        configureWrappingLabel(subtitle, maximumNumberOfLines: 2)

        let headingText = NSStackView()
        headingText.orientation = .vertical
        headingText.spacing = 3
        headingText.addArrangedSubview(title)
        headingText.addArrangedSubview(subtitle)

        root.addArrangedSubview(headingText)
        root.addArrangedSubview(statusBox())
        root.addArrangedSubview(buttonMappingBox())
        root.addArrangedSubview(buttonScrollGestureBox())
        root.addArrangedSubview(scrollBox())
        root.addArrangedSubview(pointerBox())

        let note = NSTextField(labelWithString: text(
            "提示：左键和右键固定保持系统默认。选择菜单栏里的“退出并停止优化”会停止后台代理并恢复系统默认输入。",
            "The left and right buttons always keep their system behavior. Choose Quit and Stop Optimization from the menu bar to restore default input."
        ))
        note.textColor = .secondaryLabelColor
        configureWrappingLabel(note, maximumNumberOfLines: 2)
        root.addArrangedSubview(note)

        contentView.layoutSubtreeIfNeeded()
        previousScrollView?.removeFromSuperview()

        if previousScrollView != nil, let documentView = scrollView.documentView {
            let maximumY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            scrollView.contentView.scroll(to: NSPoint(
                x: previousScrollOrigin.x,
                y: min(previousScrollOrigin.y, maximumY)
            ))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private func statusBox() -> NSView {
        let box = NSBox()
        box.title = text("运行状态", "Status")
        box.boxType = .primary

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)

        permissionLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(permissionLabel, maximumNumberOfLines: 2)
        statusLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(statusLabel, maximumNumberOfLines: 2)

        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(toggleEnabled)

        let buttons = NSStackView()
        buttons.spacing = 10
        let requestButton = NSButton(title: text("申请辅助功能权限", "Grant Access"), target: self, action: #selector(requestPermission))
        let openButton = NSButton(title: text("打开隐私设置", "Privacy Settings"), target: self, action: #selector(openPrivacySettings))
        let resetButton = NSButton(title: text("恢复默认设置", "Restore Defaults"), target: self, action: #selector(resetDefaults))
        buttons.addArrangedSubview(requestButton)
        buttons.addArrangedSubview(openButton)
        buttons.addArrangedSubview(resetButton)

        configureLanguagePopup()
        stack.addArrangedSubview(languageRow())
        stack.addArrangedSubview(enabledCheckbox)
        stack.addArrangedSubview(permissionLabel)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(buttons)

        constrain(stack, in: box)
        return box
    }

    private func buttonMappingBox() -> NSView {
        let box = NSBox()
        box.title = text("按键功能", "Button Actions")
        box.boxType = .primary

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)

        stack.addArrangedSubview(fixedRow(
            label: text("左键", "Left Button"),
            detail: text("系统默认点击，不拦截", "System click, never intercepted")
        ))
        stack.addArrangedSubview(fixedRow(
            label: text("右键", "Right Button"),
            detail: text("系统默认右键菜单，不拦截", "System context menu, never intercepted")
        ))

        for button in MouseSettings.configurableButtons {
            let popup = NSPopUpButton()
            popup.tag = button
            configureActionPopup(popup)
            popup.target = self
            popup.action = #selector(changeButtonAction(_:))
            actionPopups[button] = popup

            var physicalPopup: NSPopUpButton?
            if button > 2 {
                let idPopup = NSPopUpButton()
                idPopup.tag = button
                configurePhysicalIDPopup(idPopup)
                idPopup.target = self
                idPopup.action = #selector(changePhysicalButton(_:))
                physicalIDPopups[button] = idPopup
                physicalPopup = idPopup
            }

            stack.addArrangedSubview(mappingRow(
                label: label(forButton: button),
                detail: detail(forButton: button),
                physicalPopup: physicalPopup,
                actionPopup: popup
            ))
        }


        buttonDiagnosticLabel.textColor = .secondaryLabelColor
        configureWrappingLabel(buttonDiagnosticLabel, maximumNumberOfLines: 2)
        stack.addArrangedSubview(buttonDiagnosticLabel)

        constrain(stack, in: box)
        return box
    }

    private func fixedRow(label: String, detail: String) -> NSView {
        let row = NSStackView()
        row.spacing = 12
        row.alignment = .centerY

        let labels = NSStackView()
        labels.orientation = .vertical
        labels.spacing = 2
        let title = NSTextField(labelWithString: label)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let subtitle = NSTextField(labelWithString: detail)
        subtitle.textColor = .secondaryLabelColor
        configureWrappingLabel(subtitle, maximumNumberOfLines: 2)
        labels.addArrangedSubview(title)
        labels.addArrangedSubview(subtitle)
        labels.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let value = NSTextField(labelWithString: text("保持原样", "Pass Through"))
        value.textColor = .secondaryLabelColor
        value.alignment = .center
        value.widthAnchor.constraint(equalToConstant: 200).isActive = true
        row.addArrangedSubview(labels)
        row.addArrangedSubview(value)
        return row
    }

    private func languageRow() -> NSView {
        let row = NSStackView()
        row.spacing = 12
        row.alignment = .centerY

        let label = NSTextField(labelWithString: text("界面语言", "Interface Language"))
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        languagePopup.widthAnchor.constraint(equalToConstant: 180).isActive = true
        row.addArrangedSubview(label)
        row.addArrangedSubview(languagePopup)
        return row
    }

    private func configureLanguagePopup() {
        languagePopup.removeAllItems()
        for language in AppLanguage.allCases {
            languagePopup.addItem(withTitle: language.displayName)
            languagePopup.lastItem?.representedObject = language.rawValue
        }
        languagePopup.target = self
        languagePopup.action = #selector(changeLanguage(_:))
    }

    private func scrollBox() -> NSView {
        let box = NSBox()
        box.title = text("滚轮手感", "Scrolling")
        box.boxType = .primary

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)

        naturalCheckbox.target = self
        naturalCheckbox.action = #selector(toggleNaturalScrolling)
        smoothCheckbox.target = self
        smoothCheckbox.action = #selector(toggleSmoothScroll)
        speedSlider.target = self
        speedSlider.action = #selector(changeScrollSpeed)
        smoothnessSlider.target = self
        smoothnessSlider.action = #selector(changeSmoothness)

        stack.addArrangedSubview(naturalCheckbox)
        stack.addArrangedSubview(smoothCheckbox)
        stack.addArrangedSubview(sliderRow(label: text("滚动速度", "Scroll Speed"), slider: speedSlider, valueLabel: speedValueLabel))
        stack.addArrangedSubview(sliderRow(label: text("丝滑与惯性强度", "Smoothness"), slider: smoothnessSlider, valueLabel: smoothnessValueLabel))

        let helper = NSTextField(labelWithString: text(
            "高丝滑强度会把机械滚轮的一格滚动拆成更细的连续像素滚动，并在停止拨轮后保留短暂动量。",
            "Higher smoothness splits each wheel notch into finer pixel scrolling and keeps brief momentum after the wheel stops."
        ))
        helper.textColor = .secondaryLabelColor
        configureWrappingLabel(helper, maximumNumberOfLines: 2)
        stack.addArrangedSubview(helper)

        constrain(stack, in: box)
        return box
    }

    private func buttonScrollGestureBox() -> NSView {
        let box = NSBox()
        box.title = text("按住侧键 + 滚轮", "Hold Side Button + Wheel")
        box.boxType = .primary

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)

        for logicalButton in [3, 4] {
            var popups: [ScrollGestureDirection: NSPopUpButton] = [:]
            for direction in ScrollGestureDirection.allCases {
                let popup = NSPopUpButton()
                popup.tag = gestureTag(button: logicalButton, direction: direction)
                configureActionPopup(popup)
                popup.target = self
                popup.action = #selector(changeScrollGestureAction(_:))
                gestureActionPopups[gestureKey(button: logicalButton, direction: direction)] = popup
                popups[direction] = popup
            }

            if let upPopup = popups[.up], let downPopup = popups[.down] {
                stack.addArrangedSubview(gestureRow(
                    button: logicalButton,
                    upPopup: upPopup,
                    downPopup: downPopup
                ))
            }
        }

        let note = NSTextField(labelWithString: text(
            "“捏合放大 / 缩小”会模拟触控板双指手势。组合滚动触发后，本次侧键单击不会重复执行。",
            "Pinch zoom actions simulate a two-finger trackpad gesture. Once a wheel gesture starts, the original side-button click is suppressed."
        ))
        note.textColor = .secondaryLabelColor
        configureWrappingLabel(note, maximumNumberOfLines: 2)
        stack.addArrangedSubview(note)

        constrain(stack, in: box)
        return box
    }

    private func pointerBox() -> NSView {
        let box = NSBox()
        box.title = text("指针移动", "Pointer Movement")
        box.boxType = .primary

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)

        pointerCheckbox.target = self
        pointerCheckbox.action = #selector(togglePointerSmoothing)
        pointerSpeedSlider.target = self
        pointerSpeedSlider.action = #selector(changePointerSpeed)
        pointerSmoothnessSlider.target = self
        pointerSmoothnessSlider.action = #selector(changePointerSmoothness)

        stack.addArrangedSubview(pointerCheckbox)
        stack.addArrangedSubview(sliderRow(label: text("指针速度", "Pointer Speed"), slider: pointerSpeedSlider, valueLabel: pointerSpeedValueLabel))
        stack.addArrangedSubview(sliderRow(label: text("移动平滑强度", "Pointer Smoothing"), slider: pointerSmoothnessSlider, valueLabel: pointerSmoothnessValueLabel))

        let helper = NSTextField(labelWithString: text(
            "用于降低机械鼠标移动时的小幅抖动。强度过高会带来延迟，建议保持 20%-40%。触控板如果感觉受影响，可关闭此项。",
            "Reduces small pointer jitter from mechanical mice. High values add latency; 20%-40% is recommended. Disable it if trackpad movement feels affected."
        ))
        helper.textColor = .secondaryLabelColor
        configureWrappingLabel(helper, maximumNumberOfLines: 3)
        stack.addArrangedSubview(helper)

        constrain(stack, in: box)
        return box
    }

    private func mappingRow(
        label: String,
        detail: String,
        physicalPopup: NSPopUpButton?,
        actionPopup: NSPopUpButton
    ) -> NSView {
        let row = NSStackView()
        row.spacing = 12
        row.alignment = .centerY

        let labels = NSStackView()
        labels.orientation = .vertical
        labels.spacing = 2
        let title = NSTextField(labelWithString: label)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let subtitle = NSTextField(labelWithString: detail)
        subtitle.textColor = .secondaryLabelColor
        configureWrappingLabel(subtitle, maximumNumberOfLines: 2)
        labels.addArrangedSubview(title)
        labels.addArrangedSubview(subtitle)
        labels.widthAnchor.constraint(equalToConstant: 210).isActive = true

        row.addArrangedSubview(labels)
        if let physicalPopup {
            physicalPopup.toolTip = text("鼠标驱动上报的底层按钮编号", "Low-level button number reported by the mouse driver")
            physicalPopup.widthAnchor.constraint(equalToConstant: 90).isActive = true
            row.addArrangedSubview(physicalPopup)
        }
        actionPopup.widthAnchor.constraint(equalToConstant: 190).isActive = true
        row.addArrangedSubview(actionPopup)
        return row
    }

    private func sliderRow(label: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
        let row = NSStackView()
        row.spacing = 12
        row.alignment = .centerY
        let title = NSTextField(labelWithString: label)
        title.widthAnchor.constraint(equalToConstant: 130).isActive = true
        slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        valueLabel.widthAnchor.constraint(equalToConstant: 64).isActive = true
        row.addArrangedSubview(title)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func gestureRow(
        button: Int,
        upPopup: NSPopUpButton,
        downPopup: NSPopUpButton
    ) -> NSView {
        let row = NSStackView()
        row.spacing = 12
        row.alignment = .centerY

        let title = NSTextField(labelWithString: MouseSettings.displayName(forCGButton: button, language: language))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let upControl = labeledPopup(title: text("滚轮向上", "Wheel Up"), popup: upPopup)
        let downControl = labeledPopup(title: text("滚轮向下", "Wheel Down"), popup: downPopup)
        upControl.widthAnchor.constraint(equalToConstant: 160).isActive = true
        downControl.widthAnchor.constraint(equalToConstant: 160).isActive = true

        row.addArrangedSubview(title)
        row.addArrangedSubview(upControl)
        row.addArrangedSubview(downControl)
        return row
    }

    private func labeledPopup(title: String, popup: NSPopUpButton) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 3
        let label = NSTextField(labelWithString: title)
        label.textColor = .secondaryLabelColor
        popup.widthAnchor.constraint(equalToConstant: 160).isActive = true
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(popup)
        return stack
    }

    private func configureActionPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        for action in MouseAction.allCases {
            popup.addItem(withTitle: action.menuTitle(for: language))
            popup.lastItem?.representedObject = action.rawValue
        }
    }

    private func configurePhysicalIDPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        for physicalID in 3...31 {
            popup.addItem(withTitle: text("编号 \(physicalID)", "Button \(physicalID)"))
            popup.lastItem?.representedObject = physicalID
        }
    }

    private func label(forButton button: Int) -> String {
        MouseSettings.displayName(forCGButton: button, language: language)
    }

    private func detail(forButton button: Int) -> String {
        switch button {
        case 2: return text("滚轮按下，也就是中键", "Press the wheel (middle button)")
        case 3: return text("第一个侧边辅助键", "First side button")
        case 4: return text("第二个侧边辅助键", "Second side button")
        default: return text("未使用", "Unused")
        }
    }

    private func constrain(_ stack: NSStackView, in box: NSBox) {
        guard let contentView = box.contentView else { return }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    private func configureWrappingLabel(
        _ label: NSTextField,
        maximumNumberOfLines: Int
    ) {
        label.maximumNumberOfLines = maximumNumberOfLines
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func reload() {
        let settings = store.settings
        selectLanguage(settings.language)
        enabledCheckbox.state = settings.enabled ? .on : .off
        naturalCheckbox.state = settings.naturalScrolling ? .on : .off
        smoothCheckbox.state = settings.smoothScroll ? .on : .off
        pointerCheckbox.state = settings.pointerSmoothing ? .on : .off
        speedSlider.doubleValue = settings.scrollSpeed
        smoothnessSlider.doubleValue = settings.smoothness
        pointerSpeedSlider.doubleValue = settings.pointerSpeed
        pointerSmoothnessSlider.doubleValue = settings.pointerSmoothness
        speedValueLabel.stringValue = String(format: "%.1fx", settings.scrollSpeed)
        smoothnessValueLabel.stringValue = String(format: "%.0f%%", settings.smoothness * 100)
        pointerSpeedValueLabel.stringValue = String(format: "%.1fx", settings.pointerSpeed)
        pointerSmoothnessValueLabel.stringValue = String(format: "%.0f%%", settings.pointerSmoothness * 100)

        for (button, popup) in actionPopups {
            select(settings.action(forButton: button), in: popup)
        }
        for (logicalButton, popup) in physicalIDPopups {
            if let physicalButton = settings.physicalButton(forLogicalButton: logicalButton) {
                selectPhysicalButton(physicalButton, in: popup)
            }
        }
        for logicalButton in [3, 4] {
            for direction in ScrollGestureDirection.allCases {
                let key = gestureKey(button: logicalButton, direction: direction)
                guard let popup = gestureActionPopups[key] else { continue }
                let action = settings.scrollGestureAction(
                    forButton: logicalButton,
                    direction: direction
                )
                select(action, in: popup)
            }
        }
        refreshButtonDiagnostic()

        permissionLabel.stringValue = PermissionManager.isAccessibilityTrusted
            ? text("辅助功能权限已授权。", "Accessibility access is granted.")
            : text(
                "需要辅助功能权限，macOS 才允许本 App 监听和改写全局鼠标输入。",
                "Accessibility access is required for this app to monitor and modify global mouse input."
            )
    }

    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard
            let rawValue = sender.selectedItem?.representedObject as? String,
            let language = AppLanguage(rawValue: rawValue)
        else { return }
        store.update { $0.language = language }
    }

    @objc private func toggleEnabled() {
        store.update { $0.enabled = enabledCheckbox.state == .on }
    }

    @objc private func requestPermission() {
        PermissionManager.requestAccessibility()
        reload()
    }

    @objc private func openPrivacySettings() {
        PermissionManager.openAccessibilitySettings()
    }

    @objc private func resetDefaults() {
        let currentLanguage = store.settings.language
        store.update {
            $0 = MouseSettings()
            $0.language = currentLanguage
        }
        reload()
    }

    @objc private func changeButtonAction(_ sender: NSPopUpButton) {
        guard let action = selectedAction(in: sender) else { return }
        let button = sender.tag
        store.update { settings in
            settings.setAction(action, forButton: button)
        }
    }

    @objc private func changePhysicalButton(_ sender: NSPopUpButton) {
        guard let physicalButton = sender.selectedItem?.representedObject as? Int else { return }
        let logicalButton = sender.tag
        store.update { settings in
            settings.setPhysicalButton(physicalButton, forLogicalButton: logicalButton)
        }
    }

    @objc private func changeScrollGestureAction(_ sender: NSPopUpButton) {
        guard
            let action = selectedAction(in: sender),
            let decoded = decodeGestureTag(sender.tag)
        else { return }

        store.update { settings in
            settings.setScrollGestureAction(
                action,
                forButton: decoded.button,
                direction: decoded.direction
            )
        }
    }

    @objc private func toggleNaturalScrolling() {
        store.update { $0.naturalScrolling = naturalCheckbox.state == .on }
    }

    @objc private func toggleSmoothScroll() {
        store.update { $0.smoothScroll = smoothCheckbox.state == .on }
    }

    @objc private func togglePointerSmoothing() {
        store.update { $0.pointerSmoothing = pointerCheckbox.state == .on }
    }

    @objc private func changeScrollSpeed() {
        speedValueLabel.stringValue = String(format: "%.1fx", speedSlider.doubleValue)
        store.update { $0.scrollSpeed = speedSlider.doubleValue }
    }

    @objc private func changeSmoothness() {
        smoothnessValueLabel.stringValue = String(format: "%.0f%%", smoothnessSlider.doubleValue * 100)
        store.update { $0.smoothness = smoothnessSlider.doubleValue }
    }

    @objc private func changePointerSpeed() {
        pointerSpeedValueLabel.stringValue = String(format: "%.1fx", pointerSpeedSlider.doubleValue)
        store.update { $0.pointerSpeed = pointerSpeedSlider.doubleValue }
    }

    @objc private func changePointerSmoothness() {
        pointerSmoothnessValueLabel.stringValue = String(format: "%.0f%%", pointerSmoothnessSlider.doubleValue * 100)
        store.update { $0.pointerSmoothness = pointerSmoothnessSlider.doubleValue }
    }

    private func selectedAction(in popup: NSPopUpButton) -> MouseAction? {
        guard let rawValue = popup.selectedItem?.representedObject as? String else { return nil }
        return MouseAction(rawValue: rawValue)
    }

    private func select(_ action: MouseAction, in popup: NSPopUpButton) {
        for index in 0..<popup.numberOfItems {
            if popup.item(at: index)?.representedObject as? String == action.rawValue {
                popup.selectItem(at: index)
                return
            }
        }
    }

    private func selectPhysicalButton(_ physicalButton: Int, in popup: NSPopUpButton) {
        for index in 0..<popup.numberOfItems {
            if popup.item(at: index)?.representedObject as? Int == physicalButton {
                popup.selectItem(at: index)
                return
            }
        }
    }

    private func selectLanguage(_ language: AppLanguage) {
        for index in 0..<languagePopup.numberOfItems {
            if languagePopup.item(at: index)?.representedObject as? String == language.rawValue {
                languagePopup.selectItem(at: index)
                return
            }
        }
    }

    private func gestureKey(button: Int, direction: ScrollGestureDirection) -> String {
        "\(button)-\(direction.rawValue)"
    }

    private func gestureTag(button: Int, direction: ScrollGestureDirection) -> Int {
        button * 10 + (direction == .up ? 1 : 2)
    }

    private func decodeGestureTag(_ tag: Int) -> (button: Int, direction: ScrollGestureDirection)? {
        let button = tag / 10
        guard button == 3 || button == 4 else { return nil }
        switch tag % 10 {
        case 1: return (button, .up)
        case 2: return (button, .down)
        default: return nil
        }
    }

    private func startDiagnosticPolling() {
        diagnosticTimer?.invalidate()
        diagnosticTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.refreshButtonDiagnostic()
        }
    }

    private func refreshButtonDiagnostic() {
        guard let diagnostic = RuntimeStatusStore.latestButton() else {
            buttonDiagnosticLabel.stringValue = text(
                "最近检测：请按一下鼠标侧键，再根据显示的编号完成校准。",
                "Last detected: press a side button, then use the reported number to calibrate it."
            )
            return
        }

        if let logicalButton = diagnostic.logicalButton, let action = diagnostic.action {
            let buttonName = MouseSettings.displayName(forCGButton: logicalButton, language: language)
            let actionName = action.menuTitle(for: language)
            buttonDiagnosticLabel.stringValue = text(
                "最近检测：底层编号 \(diagnostic.physicalButton) → \(buttonName) → \(actionName)",
                "Last detected: button \(diagnostic.physicalButton) → \(buttonName) → \(actionName)"
            )
        } else {
            buttonDiagnosticLabel.stringValue = text(
                "最近检测：底层编号 \(diagnostic.physicalButton) 尚未绑定，请把辅助按键 1 或 2 的编号改为 \(diagnostic.physicalButton)。",
                "Last detected: button \(diagnostic.physicalButton) is unassigned. Set Auxiliary Button 1 or 2 to button \(diagnostic.physicalButton)."
            )
        }
    }
}
