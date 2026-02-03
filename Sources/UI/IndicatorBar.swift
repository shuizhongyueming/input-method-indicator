import Cocoa

/// 输入法状态指示条（顶部或底部）
class IndicatorBar {
    private let window: NSWindow
    private let colorView: NSView
    private let config: BarConfig
    private let screen: NSScreen
    
    init(screen: NSScreen, config: BarConfig) {
        self.screen = screen
        self.config = config
        
        // 计算窗口位置和大小
        let frame = Self.calculateFrame(for: screen, config: config)
        
        // 创建窗口
        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 配置窗口属性（参考 ShowyEdge）
        window.level = .statusBar + 1
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hasShadow = false
        
        // 创建颜色视图
        colorView = NSView(frame: window.contentView?.bounds ?? .zero)
        colorView.autoresizingMask = [.width, .height]
        colorView.wantsLayer = true
        colorView.layer?.cornerRadius = CGFloat(config.radius)
        colorView.layer?.masksToBounds = true
        
        window.contentView?.addSubview(colorView)
        
        // 初始透明
        colorView.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    /// 显示窗口
    func show() {
        window.orderFront(nil)
    }
    
    /// 隐藏窗口
    func hide() {
        window.orderOut(nil)
    }
    
    /// 更新颜色
    func updateColor(_ color: NSColor, animated: Bool = true) {
        let effectiveColor = color.withAlphaComponent(CGFloat(config.opacity))
        
        if animated && config.animationDuration > 0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = config.animationDuration
                context.timingFunction = .init(name: .easeInEaseOut)
                colorView.animator().layer?.backgroundColor = effectiveColor.cgColor
            }
        } else {
            colorView.layer?.backgroundColor = effectiveColor.cgColor
        }
    }
    
    /// 更新屏幕位置（屏幕配置变化时调用）
    func updateFrame() {
        let newFrame = Self.calculateFrame(for: screen, config: config)
        window.setFrame(newFrame, display: true, animate: false)
        colorView.frame = window.contentView?.bounds ?? .zero
    }
    
    /// 获取关联的屏幕
    var associatedScreen: NSScreen {
        return screen
    }
    
    // MARK: - Private
    
    private static func calculateFrame(for screen: NSScreen, config: BarConfig) -> NSRect {
        let screenFrame = screen.frame
        let height = CGFloat(config.height)
        let y: CGFloat
        
        switch config.position {
        case .top:
            // 顶部：y 坐标是屏幕高度减去高度
            y = screenFrame.maxY - height
        case .bottom:
            // 底部：y 坐标是屏幕最小 y
            y = screenFrame.minY
        }
        
        return NSRect(
            x: screenFrame.minX,
            y: y,
            width: screenFrame.width,
            height: height
        )
    }
}

// MARK: - 指示器管理器

class IndicatorBarManager {
    private var bars: [IndicatorBar] = []
    private let config: BarConfig
    
    init(config: BarConfig) {
        self.config = config
        setupBars()
        setupScreenNotifications()
    }
    
    /// 更新所有指示条的颜色
    func updateColor(_ color: NSColor) {
        bars.forEach { $0.updateColor(color) }
    }
    
    /// 显示所有指示条
    func show() {
        bars.forEach { $0.show() }
    }
    
    /// 隐藏所有指示条
    func hide() {
        bars.forEach { $0.hide() }
    }
    
    // MARK: - Private
    
    private func setupBars() {
        let screens = config.showOnAllDisplays ? NSScreen.screens : [NSScreen.main].compactMap { $0 }
        
        bars = screens.map { screen in
            let bar = IndicatorBar(screen: screen, config: config)
            bar.show()
            return bar
        }
    }
    
    private func setupScreenNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenConfigurationChanged() {
        // 屏幕配置变化时，重建所有指示条
        bars.forEach { $0.hide() }
        bars.removeAll()
        setupBars()
    }
}
