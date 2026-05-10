import AppKit

final class SettingsWindowController: NSWindowController {
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
    private var actionPopups: [Int: NSPopUpButton] = [:]

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
        buildUI()
        reload()
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
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

        let title = NSTextField(labelWithString: "鼠标优化")
        title.font = .systemFont(ofSize: 23, weight: .bold)
        let subtitle = NSTextField(labelWithString: "鼠标结构固定为：左键、滚轮、右键、辅助按键 1、辅助按键 2。触控板连续滚动保持系统原样。")
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.addArrangedSubview(statusBox())
        root.addArrangedSubview(buttonMappingBox())
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
            stack.addArrangedSubview(mappingRow(label: label(forButton: button), detail: detail(forButton: button), popup: popup))
        }

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

    private func mappingRow(label: String, detail: String, popup: NSPopUpButton) -> NSView {
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

        popup.widthAnchor.constraint(equalToConstant: 250).isActive = true
        row.addArrangedSubview(labels)
        row.addArrangedSubview(popup)
        return row
    }

    private func sliderRow(label: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
        let row = NSStackView()
        row.spacing = 12
        row.alignment = .centerY
        let title = NSTextField(labelWithString: label)
        title.widthAnchor.constraint(equalToConstant: 140).isActive = true
        slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        valueLabel.widthAnchor.constraint(equalToConstant: 64).isActive = true
        row.addArrangedSubview(title)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func configureActionPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        for action in MouseAction.allCases {
            popup.addItem(withTitle: action.menuTitle)
            popup.lastItem?.representedObject = action.rawValue
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
}
