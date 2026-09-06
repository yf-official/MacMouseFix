import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let store = SettingsStore.shared

    private let statusLabel = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let enabledCheckbox = NSButton(checkboxWithTitle: "启用鼠标优化", target: nil, action: nil)
    private let naturalCheckbox = NSButton(checkboxWithTitle: "自然滚动方向", target: nil, action: nil)
    private let smoothCheckbox = NSButton(checkboxWithTitle: "启用触控板式丝滑滚动（推荐）", target: nil, action: nil)
    private let pointerCheckbox = NSButton(checkboxWithTitle: "启用鼠标指针平滑", target: nil, action: nil)
    private let speedSlider = NSSlider(value: 1.15, minValue: 0.2, maxValue: 4.0, target: nil, action: nil)
    private let smoothnessSlider = NSSlider(value: 0.88, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let pointerSpeedSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 2.0, target: nil, action: nil)
    private let pointerSmoothnessSlider = NSSlider(value: 0.28, minValue: 0.0, maxValue: 0.8, target: nil, action: nil)
    private let speedValueLabel = NSTextField(labelWithString: "1.2x")
    private let smoothnessValueLabel = NSTextField(labelWithString: "88%")
    private let pointerSpeedValueLabel = NSTextField(labelWithString: "1.0x")
    private let pointerSmoothnessValueLabel = NSTextField(labelWithString: "28%")
    private let buttonDiagnosticLabel = NSTextField(labelWithString: "最近检测：请按一下鼠标侧键。")
    private var actionPopups: [Int: NSPopUpButton] = [:]
    private var physicalIDPopups: [Int: NSPopUpButton] = [:]
    private var gestureActionPopups: [String: NSPopUpButton] = [:]
    private var diagnosticTimer: Timer?

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

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

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
        let subtitle = NSTextField(labelWithString: "鼠标优化 · 配置侧键点击、按住侧键滚动、丝滑滚轮和指针手感。触控板连续滚动保持系统原样。")
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        let headingText = NSStackView()
        headingText.orientation = .vertical
        headingText.spacing = 3
        headingText.addArrangedSubview(title)
        headingText.addArrangedSubview(subtitle)

        let heading = NSStackView()
        heading.spacing = 12
        heading.alignment = .centerY
        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 48).isActive = true
        heading.addArrangedSubview(iconView)
        heading.addArrangedSubview(headingText)

        root.addArrangedSubview(heading)
        root.addArrangedSubview(statusBox())
        root.addArrangedSubview(buttonMappingBox())
        root.addArrangedSubview(buttonScrollGestureBox())
        root.addArrangedSubview(scrollBox())
        root.addArrangedSubview(pointerBox())

        let note = NSTextField(labelWithString: "提示：左键和右键固定保持系统默认。选择菜单栏里的“退出并停止优化”会停止后台代理并恢复系统默认输入。")
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 2
        root.addArrangedSubview(note)
    }

    private func statusBox() -> NSView {
        let box = NSBox()
        box.title = "运行状态"
        box.boxType = .primary

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)

        permissionLabel.textColor = .secondaryLabelColor
        permissionLabel.maximumNumberOfLines = 2
        statusLabel.textColor = .secondaryLabelColor

        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(toggleEnabled)

        let buttons = NSStackView()
        buttons.spacing = 10
        let requestButton = NSButton(title: "申请辅助功能权限", target: self, action: #selector(requestPermission))
        let openButton = NSButton(title: "打开隐私设置", target: self, action: #selector(openPrivacySettings))
        let resetButton = NSButton(title: "恢复默认设置", target: self, action: #selector(resetDefaults))
        buttons.addArrangedSubview(requestButton)
        buttons.addArrangedSubview(openButton)
        buttons.addArrangedSubview(resetButton)

        stack.addArrangedSubview(enabledCheckbox)
        stack.addArrangedSubview(permissionLabel)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(buttons)

        constrain(stack, in: box)
        return box
    }

    private func buttonMappingBox() -> NSView {
        let box = NSBox()
        box.title = "按键功能"
        box.boxType = .primary

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)

        stack.addArrangedSubview(fixedRow(label: "左键", detail: "系统默认点击，不拦截"))
        stack.addArrangedSubview(fixedRow(label: "右键", detail: "系统默认右键菜单，不拦截"))

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
        buttonDiagnosticLabel.maximumNumberOfLines = 2
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
        labels.addArrangedSubview(title)
        labels.addArrangedSubview(subtitle)
        labels.widthAnchor.constraint(equalToConstant: 190).isActive = true

        let value = NSTextField(labelWithString: "保持原样")
        value.textColor = .secondaryLabelColor
        value.alignment = .center
        value.widthAnchor.constraint(equalToConstant: 250).isActive = true
        row.addArrangedSubview(labels)
        row.addArrangedSubview(value)
        return row
    }

    private func scrollBox() -> NSView {
        let box = NSBox()
        box.title = "滚轮手感"
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
        stack.addArrangedSubview(sliderRow(label: "滚动速度", slider: speedSlider, valueLabel: speedValueLabel))
        stack.addArrangedSubview(sliderRow(label: "丝滑与惯性强度", slider: smoothnessSlider, valueLabel: smoothnessValueLabel))

        let helper = NSTextField(labelWithString: "高丝滑强度会把机械滚轮的一格滚动拆成更细的连续像素滚动，并在停止拨轮后保留短暂动量。")
        helper.textColor = .secondaryLabelColor
        helper.maximumNumberOfLines = 2
        stack.addArrangedSubview(helper)

        constrain(stack, in: box)
        return box
    }

    private func buttonScrollGestureBox() -> NSView {
        let box = NSBox()
        box.title = "按住侧键 + 滚轮"
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

        let note = NSTextField(labelWithString: "组合滚动触发后，本次侧键单击不会重复执行。选择“保持原样”可让该方向继续正常滚动。")
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 2
        stack.addArrangedSubview(note)

        constrain(stack, in: box)
        return box
    }

    private func pointerBox() -> NSView {
        let box = NSBox()
        box.title = "指针移动"
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
        stack.addArrangedSubview(sliderRow(label: "指针速度", slider: pointerSpeedSlider, valueLabel: pointerSpeedValueLabel))
        stack.addArrangedSubview(sliderRow(label: "移动平滑强度", slider: pointerSmoothnessSlider, valueLabel: pointerSmoothnessValueLabel))

        let helper = NSTextField(labelWithString: "用于降低机械鼠标移动时的小幅抖动。强度过高会带来延迟，建议保持 20%-40%。触控板如果感觉受影响，可关闭此项。")
        helper.textColor = .secondaryLabelColor
        helper.maximumNumberOfLines = 3
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
        labels.addArrangedSubview(title)
        labels.addArrangedSubview(subtitle)
        labels.widthAnchor.constraint(equalToConstant: 160).isActive = true

        row.addArrangedSubview(labels)
        if let physicalPopup {
            physicalPopup.toolTip = "鼠标驱动上报的底层按钮编号"
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

        let title = NSTextField(labelWithString: MouseSettings.displayName(forCGButton: button))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let upControl = labeledPopup(title: "滚轮向上", popup: upPopup)
        let downControl = labeledPopup(title: "滚轮向下", popup: downPopup)
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
            popup.addItem(withTitle: action.menuTitle)
            popup.lastItem?.representedObject = action.rawValue
        }
    }

    private func configurePhysicalIDPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        for physicalID in 3...31 {
            popup.addItem(withTitle: "编号 \(physicalID)")
            popup.lastItem?.representedObject = physicalID
        }
    }

    private func label(forButton button: Int) -> String {
        MouseSettings.displayName(forCGButton: button)
    }

    private func detail(forButton button: Int) -> String {
        switch button {
        case 2: return "滚轮按下，也就是中键"
        case 3: return "第一个侧边辅助键"
        case 4: return "第二个侧边辅助键"
        default: return "未使用"
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

    func reload() {
        let settings = store.settings
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
            ? "辅助功能权限已授权。"
            : "需要辅助功能权限，macOS 才允许本 App 监听和改写全局鼠标输入。"
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
        store.reset()
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
            buttonDiagnosticLabel.stringValue = "最近检测：请按一下鼠标侧键，再根据显示的编号完成校准。"
            return
        }

        if let logicalButton = diagnostic.logicalButton, let action = diagnostic.action {
            buttonDiagnosticLabel.stringValue = "最近检测：底层编号 \(diagnostic.physicalButton) → \(MouseSettings.displayName(forCGButton: logicalButton)) → \(action.menuTitle)"
        } else {
            buttonDiagnosticLabel.stringValue = "最近检测：底层编号 \(diagnostic.physicalButton) 尚未绑定，请把辅助按键 1 或 2 的编号改为 \(diagnostic.physicalButton)。"
        }
    }
}
