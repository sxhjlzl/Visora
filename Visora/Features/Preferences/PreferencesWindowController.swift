import AppKit

final class PreferencesWindowController: NSWindowController {
    private let onSave: (AppSettings) -> Void
    private var settings: AppSettings

    init(settings: AppSettings, onSave: @escaping (AppSettings) -> Void) {
        self.settings = settings
        self.onSave = onSave
        let localizer = Localizer(language: settings.language)
        let tabController = PreferencesTabViewController(settings: settings, localizer: localizer, onChange: onSave)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = tabController
        // preference 风格的 toolbar 让顶部按钮居中显示，贴近 Picview 的视觉
        window.toolbarStyle = .preference
        window.title = localizer.string(.preferences).replacingOccurrences(of: "...", with: "")
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(settings: AppSettings) {
        self.settings = settings
        rebuildContent(preservingSelectedTabIndex: (contentViewController as? PreferencesTabViewController)?.selectedTabViewItemIndex ?? 0)
    }

    private func rebuildContent(preservingSelectedTabIndex selectedTabIndex: Int) {
        let localizer = Localizer(language: settings.language)
        let tabController = PreferencesTabViewController(settings: settings, localizer: localizer, onChange: onSave)
        window?.contentViewController = tabController
        let clampedIndex = min(max(selectedTabIndex, 0), max(tabController.tabViewItems.count - 1, 0))
        tabController.selectedTabViewItemIndex = clampedIndex
        window?.title = tabController.tabViewItems[safe: clampedIndex]?.label
            ?? localizer.string(.preferences).replacingOccurrences(of: "...", with: "")
    }
}

private final class PreferencesTabViewController: NSTabViewController {
    private var settings: AppSettings
    private let localizer: Localizer
    private let onChange: (AppSettings) -> Void

    init(settings: AppSettings, localizer: Localizer, onChange: @escaping (AppSettings) -> Void) {
        self.settings = settings
        self.localizer = localizer
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabStyle = .toolbar
        transitionOptions = []

        installItem(
            controller: GeneralPaneViewController(
                settings: settings,
                localizer: localizer,
                update: applyUpdate
            ),
            symbol: "gearshape",
            labelKey: .general
        )
        installItem(
            controller: ViewerPaneViewController(
                settings: settings,
                localizer: localizer,
                update: applyUpdate
            ),
            symbol: "photo.on.rectangle.angled",
            labelKey: .viewer
        )
        installItem(
            controller: FolderPaneViewController(
                settings: settings,
                localizer: localizer,
                update: applyUpdate
            ),
            symbol: "folder",
            labelKey: .folder
        )
        installItem(
            controller: ShortcutsPaneViewController(localizer: localizer),
            symbol: "command",
            labelKey: .shortcuts
        )
        installItem(
            controller: AboutPaneViewController(localizer: localizer),
            symbol: "info.circle",
            labelKey: .about
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // viewWillAppear 阶段 window 已存在，需要在此时把当前 tab 标题同步到标题栏
        syncWindowTitleWithSelectedTab()
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        syncWindowTitleWithSelectedTab()
    }

    private func installItem(controller: NSViewController, symbol: String, labelKey: Localizer.Key) {
        let label = localizer.string(labelKey)
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        addTabViewItem(item)
    }

    private func applyUpdate(_ updater: (inout AppSettings) -> Void) {
        updater(&settings)
        onChange(settings)
    }

    private func syncWindowTitleWithSelectedTab() {
        guard tabViewItems.indices.contains(selectedTabViewItemIndex) else { return }
        view.window?.title = tabViewItems[selectedTabViewItemIndex].label
    }
}

// MARK: - Pane: 通用

private final class GeneralPaneViewController: NSViewController {
    private var settings: AppSettings
    private let localizer: Localizer
    private let update: ((inout AppSettings) -> Void) -> Void
    private let quitWhenLastWindowClosedCheckbox: NSButton
    private let languagePopup = NSPopUpButton()

    init(settings: AppSettings, localizer: Localizer, update: @escaping ((inout AppSettings) -> Void) -> Void) {
        self.settings = settings
        self.localizer = localizer
        self.update = update
        self.quitWhenLastWindowClosedCheckbox = NSButton(
            checkboxWithTitle: localizer.string(.quitWhenLastWindowClosed),
            target: nil,
            action: nil
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let host = PreferencesPaneRoot()
        view = host

        quitWhenLastWindowClosedCheckbox.state = settings.quitWhenLastWindowClosed ? .on : .off
        quitWhenLastWindowClosedCheckbox.target = self
        quitWhenLastWindowClosedCheckbox.action = #selector(quitTogglePressed)

        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: AppLanguage.allCases.map(\.displayName))
        languagePopup.selectItem(at: AppLanguage.allCases.firstIndex(of: settings.language) ?? 0)
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)

        let grid = PreferencesPaneLayout.makeGrid(rows: [
            .init(localizer.string(.application), quitWhenLastWindowClosedCheckbox),
            .init(localizer.string(.language), languagePopup)
        ])

        host.embed(grid)
        preferredContentSize = NSSize(width: 560, height: 320)
    }

    @objc private func quitTogglePressed() {
        update { $0.quitWhenLastWindowClosed = self.quitWhenLastWindowClosedCheckbox.state == .on }
    }

    @objc private func languageChanged() {
        let language = AppLanguage.allCases[safe: languagePopup.indexOfSelectedItem] ?? .english
        update { $0.language = language }
    }
}

// MARK: - Pane: 浏览

private final class ViewerPaneViewController: NSViewController {
    private var settings: AppSettings
    private let localizer: Localizer
    private let update: ((inout AppSettings) -> Void) -> Void

    private let autoHideCheckbox: NSButton
    private let immersiveCheckbox: NSButton
    private let longImageCheckbox: NSButton
    private let filmstripCheckbox: NSButton
    private let cacheField = NumericTextField()
    private let intervalField = NumericTextField()
    private let randomCheckbox: NSButton
    private let loopCheckbox: NSButton

    init(settings: AppSettings, localizer: Localizer, update: @escaping ((inout AppSettings) -> Void) -> Void) {
        self.settings = settings
        self.localizer = localizer
        self.update = update
        self.autoHideCheckbox = NSButton(checkboxWithTitle: localizer.string(.autoHideChrome), target: nil, action: nil)
        self.immersiveCheckbox = NSButton(checkboxWithTitle: localizer.string(.immersiveChrome), target: nil, action: nil)
        self.longImageCheckbox = NSButton(checkboxWithTitle: localizer.string(.openLongImagesFromTop), target: nil, action: nil)
        self.filmstripCheckbox = NSButton(checkboxWithTitle: localizer.string(.showFilmstrip), target: nil, action: nil)
        self.randomCheckbox = NSButton(checkboxWithTitle: localizer.string(.randomPlayback), target: nil, action: nil)
        self.loopCheckbox = NSButton(checkboxWithTitle: localizer.string(.loopPlayback), target: nil, action: nil)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let host = PreferencesPaneRoot()
        view = host

        autoHideCheckbox.state = settings.autoHideChrome ? .on : .off
        immersiveCheckbox.state = settings.startImmersiveChrome ? .on : .off
        longImageCheckbox.state = settings.enableLongImageMode ? .on : .off
        filmstripCheckbox.state = settings.showFilmstrip ? .on : .off
        randomCheckbox.state = settings.slideshowRandom ? .on : .off
        loopCheckbox.state = settings.slideshowLoop ? .on : .off

        autoHideCheckbox.target = self
        autoHideCheckbox.action = #selector(autoHideToggled)
        immersiveCheckbox.target = self
        immersiveCheckbox.action = #selector(immersiveToggled)
        longImageCheckbox.target = self
        longImageCheckbox.action = #selector(longImageToggled)
        filmstripCheckbox.target = self
        filmstripCheckbox.action = #selector(filmstripToggled)
        randomCheckbox.target = self
        randomCheckbox.action = #selector(randomToggled)
        loopCheckbox.target = self
        loopCheckbox.action = #selector(loopToggled)

        cacheField.integerValue = settings.cacheCountLimit
        cacheField.alignment = .right
        cacheField.target = self
        cacheField.action = #selector(cacheChanged)

        intervalField.doubleValue = settings.slideshowInterval
        intervalField.alignment = .right
        intervalField.target = self
        intervalField.action = #selector(intervalChanged)

        let slideshowRow = NSStackView(views: [randomCheckbox, loopCheckbox])
        slideshowRow.orientation = .horizontal
        slideshowRow.spacing = 14

        let grid = PreferencesPaneLayout.makeGrid(rows: [
            .init(nil, autoHideCheckbox),
            .init(nil, immersiveCheckbox),
            .init(nil, longImageCheckbox),
            .init(nil, filmstripCheckbox),
            .init(localizer.string(.memoryCacheImages), cacheField),
            .init(localizer.string(.intervalSeconds), intervalField),
            .init(localizer.string(.slideshow), slideshowRow)
        ])

        host.embed(grid)
        preferredContentSize = NSSize(width: 560, height: 420)
    }

    @objc private func autoHideToggled() {
        update { $0.autoHideChrome = self.autoHideCheckbox.state == .on }
    }

    @objc private func immersiveToggled() {
        update { $0.startImmersiveChrome = self.immersiveCheckbox.state == .on }
    }

    @objc private func longImageToggled() {
        update { $0.enableLongImageMode = self.longImageCheckbox.state == .on }
    }

    @objc private func filmstripToggled() {
        update { $0.showFilmstrip = self.filmstripCheckbox.state == .on }
    }

    @objc private func cacheChanged() {
        update { $0.cacheCountLimit = self.cacheField.integerValue }
    }

    @objc private func intervalChanged() {
        update { $0.slideshowInterval = self.intervalField.doubleValue }
    }

    @objc private func randomToggled() {
        update { $0.slideshowRandom = self.randomCheckbox.state == .on }
    }

    @objc private func loopToggled() {
        update { $0.slideshowLoop = self.loopCheckbox.state == .on }
    }
}

// MARK: - Pane: 来源

private final class FolderPaneViewController: NSViewController {
    private var settings: AppSettings
    private let localizer: Localizer
    private let update: ((inout AppSettings) -> Void) -> Void

    private let sortPopup = NSPopUpButton()
    private let includeHiddenCheckbox: NSButton
    private let recursiveCheckbox: NSButton
    private let maxDepthField = NumericTextField()
    private var formatButtons: [String: NSButton] = [:]

    init(settings: AppSettings, localizer: Localizer, update: @escaping ((inout AppSettings) -> Void) -> Void) {
        self.settings = settings
        self.localizer = localizer
        self.update = update
        self.includeHiddenCheckbox = NSButton(checkboxWithTitle: localizer.string(.includeHiddenFiles), target: nil, action: nil)
        self.recursiveCheckbox = NSButton(checkboxWithTitle: localizer.string(.recursiveBrowsing), target: nil, action: nil)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let host = PreferencesPaneRoot()
        view = host

        sortPopup.removeAllItems()
        sortPopup.addItems(withTitles: SortRule.allCases.map { $0.displayName(language: settings.language) })
        sortPopup.selectItem(at: SortRule.allCases.firstIndex(of: settings.sortRule) ?? 0)
        sortPopup.target = self
        sortPopup.action = #selector(sortChanged)

        includeHiddenCheckbox.state = settings.includeHiddenFiles ? .on : .off
        recursiveCheckbox.state = settings.recursiveBrowsing ? .on : .off
        includeHiddenCheckbox.target = self
        includeHiddenCheckbox.action = #selector(includeHiddenToggled)
        recursiveCheckbox.target = self
        recursiveCheckbox.action = #selector(recursiveToggled)

        maxDepthField.integerValue = settings.maxRecursionDepth
        maxDepthField.alignment = .right
        maxDepthField.target = self
        maxDepthField.action = #selector(maxDepthChanged)

        let formatControls = makeFormatControls()

        let grid = PreferencesPaneLayout.makeGrid(rows: [
            .init(localizer.string(.sort), sortPopup),
            .init(nil, includeHiddenCheckbox),
            .init(nil, recursiveCheckbox),
            .init(localizer.string(.maximumDepth), maxDepthField),
            .init(localizer.string(.formats), formatControls)
        ])

        host.embed(grid)
        preferredContentSize = NSSize(width: 600, height: 480)
    }

    private func makeFormatControls() -> NSStackView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.addArrangedSubview(NSButton(title: localizer.string(.all), target: self, action: #selector(selectAllFormats)))
        buttonRow.addArrangedSubview(NSButton(title: localizer.string(.none), target: self, action: #selector(clearAllFormats)))
        container.addArrangedSubview(buttonRow)

        let grid = NSGridView()
        grid.xPlacement = .leading
        grid.yPlacement = .center
        grid.rowSpacing = 6
        grid.columnSpacing = 24

        let columns = 2
        let options = ImageFormatOption.all
        let rowCount = Int(ceil(Double(options.count) / Double(columns)))

        for rowIndex in 0..<rowCount {
            var rowViews: [NSView] = []
            for columnIndex in 0..<columns {
                let optionIndex = rowIndex + columnIndex * rowCount
                if optionIndex < options.count {
                    let option = options[optionIndex]
                    let checkbox = NSButton(checkboxWithTitle: option.displayName, target: self, action: #selector(formatToggled(_:)))
                    checkbox.state = settings.enabledFormatIDs.contains(option.id) ? .on : .off
                    checkbox.identifier = NSUserInterfaceItemIdentifier(option.id)
                    formatButtons[option.id] = checkbox
                    rowViews.append(checkbox)
                } else {
                    rowViews.append(NSView())
                }
            }
            grid.addRow(with: rowViews)
        }

        container.addArrangedSubview(grid)
        return container
    }

    @objc private func sortChanged() {
        let rule = SortRule.allCases[safe: sortPopup.indexOfSelectedItem] ?? .fileNameAscending
        update { $0.sortRule = rule }
    }

    @objc private func includeHiddenToggled() {
        update { $0.includeHiddenFiles = self.includeHiddenCheckbox.state == .on }
    }

    @objc private func recursiveToggled() {
        update { $0.recursiveBrowsing = self.recursiveCheckbox.state == .on }
    }

    @objc private func maxDepthChanged() {
        update { $0.maxRecursionDepth = self.maxDepthField.integerValue }
    }

    @objc private func formatToggled(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        update { settings in
            if sender.state == .on {
                settings.enabledFormatIDs.insert(id)
            } else {
                settings.enabledFormatIDs.remove(id)
            }
        }
    }

    @objc private func selectAllFormats() {
        for button in formatButtons.values {
            button.state = .on
        }
        update { $0.enabledFormatIDs = ImageFormatOption.defaultEnabledIDs }
    }

    @objc private func clearAllFormats() {
        for button in formatButtons.values {
            button.state = .off
        }
        update { $0.enabledFormatIDs = [] }
    }
}

// MARK: - Pane: 快捷键

private final class ShortcutsPaneViewController: NSViewController {
    private let localizer: Localizer
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let entries: [ShortcutEntry]

    init(localizer: Localizer) {
        self.localizer = localizer
        self.entries = ShortcutEntry.makeAll(localizer: localizer)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let host = PreferencesPaneRoot()
        view = host

        let actionColumn = NSTableColumn(identifier: .init("action"))
        actionColumn.title = localizer.string(.actionColumn)
        actionColumn.width = 260
        actionColumn.minWidth = 200

        let shortcutColumn = NSTableColumn(identifier: .init("shortcut"))
        shortcutColumn.title = localizer.string(.shortcutColumn)
        shortcutColumn.width = 200
        shortcutColumn.minWidth = 140

        tableView.addTableColumn(actionColumn)
        tableView.addTableColumn(shortcutColumn)
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnResizing = true
        tableView.style = .inset
        tableView.rowSizeStyle = .medium
        tableView.dataSource = self
        tableView.delegate = self
        tableView.intercellSpacing = NSSize(width: 12, height: 6)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        host.embed(scrollView, edgeInsets: NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24))
        preferredContentSize = NSSize(width: 560, height: 440)
    }
}

extension ShortcutsPaneViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        let entry = entries[row]
        let isShortcutColumn = column.identifier.rawValue == "shortcut"
        let cell = NSTableCellView()
        cell.translatesAutoresizingMaskIntoConstraints = false

        let textField = NSTextField(labelWithString: isShortcutColumn ? entry.shortcut : entry.action)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = isShortcutColumn
            ? .monospacedSystemFont(ofSize: 12, weight: .medium)
            : .systemFont(ofSize: 12, weight: .regular)
        textField.textColor = isShortcutColumn
            ? NSColor.secondaryLabelColor
            : NSColor.labelColor
        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }
}

private struct ShortcutEntry {
    let action: String
    let shortcut: String

    static func makeAll(localizer: Localizer) -> [ShortcutEntry] {
        [
            ShortcutEntry(action: localizer.string(.openImage), shortcut: "⌘ O"),
            ShortcutEntry(action: localizer.string(.openFolder), shortcut: "⌘ ⇧ O"),
            ShortcutEntry(action: localizer.string(.pinClipboard), shortcut: "⌘ ⇧ V"),
            ShortcutEntry(action: localizer.string(.save), shortcut: "⌘ S"),
            ShortcutEntry(action: localizer.string(.filterImages), shortcut: "⌘ F / /"),
            ShortcutEntry(action: localizer.string(.copyImageBitmap), shortcut: "⌘ C"),
            ShortcutEntry(action: localizer.string(.copyFile), shortcut: "⌘ ⇧ C"),
            ShortcutEntry(action: localizer.string(.copyFilePath), shortcut: "⌘ ⌥ C"),
            ShortcutEntry(action: localizer.string(.previousImage), shortcut: "←"),
            ShortcutEntry(action: localizer.string(.nextImage), shortcut: "→"),
            ShortcutEntry(action: localizer.string(.zoomIn), shortcut: "↑"),
            ShortcutEntry(action: localizer.string(.zoomOut), shortcut: "↓"),
            ShortcutEntry(action: "\(localizer.string(.fitToWindow)) / \(localizer.string(.actualSize))", shortcut: "Space"),
            ShortcutEntry(action: "\(localizer.string(.rotateLeft)) / \(localizer.string(.rotateRight))", shortcut: "[ / ]"),
            ShortcutEntry(action: "\(localizer.string(.flipHorizontal)) / \(localizer.string(.flipVertical))", shortcut: "H / V"),
            ShortcutEntry(action: localizer.string(.canvasBackground), shortcut: "B"),
            ShortcutEntry(action: localizer.string(.pixelatedInterpolation), shortcut: "N"),
            ShortcutEntry(action: localizer.string(.zoomLock), shortcut: "L"),
            ShortcutEntry(action: localizer.string(.recognizeText), shortcut: "O"),
            ShortcutEntry(action: localizer.string(.toggleFullScreen), shortcut: "F"),
            ShortcutEntry(action: localizer.string(.grid), shortcut: "G"),
            ShortcutEntry(action: localizer.string(.filmstrip), shortcut: "T"),
            ShortcutEntry(action: localizer.string(.metadata), shortcut: "I"),
            ShortcutEntry(action: localizer.string(.pinImage), shortcut: "P"),
            ShortcutEntry(action: localizer.string(.immersiveChrome), shortcut: "C"),
            ShortcutEntry(action: localizer.string(.slideshow), shortcut: "S"),
            ShortcutEntry(action: localizer.string(.close), shortcut: "Esc")
        ]
    }
}

// MARK: - Pane: 关于

private final class AboutPaneViewController: NSViewController {
    private let localizer: Localizer

    init(localizer: Localizer) {
        self.localizer = localizer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let host = PreferencesPaneRoot()
        view = host

        let logo = AppIconView()
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.widthAnchor.constraint(equalToConstant: 84).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 84).isActive = true

        let name = NSTextField(labelWithString: "Visora")
        name.font = .systemFont(ofSize: 22, weight: .semibold)
        name.alignment = .center

        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let version = NSTextField(labelWithString: "\(localizer.string(.version)) \(versionString)")
        version.font = .systemFont(ofSize: 11, weight: .regular)
        version.textColor = .secondaryLabelColor
        version.alignment = .center

        let tagline = NSTextField(labelWithString: localizer.string(.aboutTagline))
        tagline.font = .systemFont(ofSize: 12, weight: .regular)
        tagline.textColor = .tertiaryLabelColor
        tagline.alignment = .center
        tagline.lineBreakMode = .byWordWrapping
        tagline.maximumNumberOfLines = 2
        tagline.preferredMaxLayoutWidth = 360

        let stack = NSStackView(views: [logo, name, version, tagline])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(14, after: logo)
        stack.setCustomSpacing(2, after: name)
        stack.setCustomSpacing(14, after: version)

        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])
        preferredContentSize = NSSize(width: 560, height: 360)
    }

}

// MARK: - 复用控件

/// 面板容器，统一暗色背景，避免每个 pane 重复设置
private final class PreferencesPaneRoot: NSView {
    private var embedded: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    func embed(_ subview: NSView, edgeInsets insets: NSEdgeInsets = NSEdgeInsets(top: 28, left: 32, bottom: 24, right: 32)) {
        embedded?.removeFromSuperview()
        embedded = subview
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            subview.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -insets.right),
            subview.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            subview.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -insets.bottom),
            subview.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
}

/// 统一的“右对齐 label - 控件”双列布局，label 传 nil 表示该行只有控件
private enum PreferencesPaneLayout {
    struct Row {
        let label: String?
        let control: NSView

        init(_ label: String?, _ control: NSView) {
            self.label = label
            self.control = control
        }
    }

    static func makeGrid(rows: [Row]) -> NSGridView {
        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 14
        grid.xPlacement = .leading
        grid.yPlacement = .center

        for row in rows {
            let labelView: NSView
            if let label = row.label, !label.isEmpty {
                let textField = NSTextField(labelWithString: label)
                textField.alignment = .right
                textField.font = .systemFont(ofSize: 13, weight: .regular)
                textField.textColor = .labelColor
                textField.setContentHuggingPriority(.required, for: .horizontal)
                labelView = textField
            } else {
                // 占位让无 label 的行依然与其它行的控件列对齐，整体观感更整齐
                labelView = NSView()
            }
            grid.addRow(with: [labelView, row.control])
        }

        if grid.numberOfColumns > 0 {
            let firstColumn = grid.column(at: 0)
            firstColumn.xPlacement = .trailing
            firstColumn.width = 110
        }
        if grid.numberOfColumns > 1 {
            grid.column(at: 1).xPlacement = .leading
        }
        return grid
    }
}

/// 编辑结束时才回调 action 的数字文本框，避免每次按键都触发设置变更
private final class NumericTextField: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = true
        isBezeled = true
        focusRingType = .default
        usesSingleLineMode = true
        widthAnchor.constraint(equalToConstant: 84).isActive = true
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
