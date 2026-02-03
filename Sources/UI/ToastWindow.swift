import Cocoa

/// Toast 通知窗口
class ToastWindow: NSWindow {
    private let config: ToastConfig
    private let state: InputState
    private let onFlip: (() -> Void)?
    
    private var titleLabel: NSTextField!
    private var flipButton: NSButton!
    private var indicatorView: NSView!
    private var hideTimer: Timer?
    private var isHovering = false
    
    init(screen: NSScreen, config: ToastConfig, state: InputState, onFlip: (() -> Void)? = nil) {
        self.config = config
        self.state = state
        self.onFlip = onFlip
        
        let frame = Self.calculateFrame(for: screen, config: config)
        
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
        setupTrackingArea()
    }
    
    // MARK: - Public
    
    func show(animated: Bool = true) {
        alphaValue = 0
        orderFront(nil)
        
        if animated && config.animationDuration > 0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = config.animationDuration
                context.timingFunction = .init(name: .easeOut)
                animator().alphaValue = 1.0
            }
        } else {
            alphaValue = 1.0
        }
    }
    
    func hide(animated: Bool = true) {
        hideTimer?.invalidate()
        hideTimer = nil
        
        if animated && config.animationDuration > 0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = config.animationDuration
                context.timingFunction = .init(name: .easeIn)
                animator().alphaValue = 0.0
            } completionHandler: { [weak self] in
                self?.orderOut(nil)
            }
        } else {
            orderOut(nil)
        }
    }
    
    func startHideTimer(duration: TimeInterval) {
        guard duration > 0 else { return }
        
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self, !self.isHovering else { return }
            self.hide()
        }
    }
    
    func pauseTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    func resumeTimer(duration: TimeInterval) {
        startHideTimer(duration: duration)
    }
    
    // MARK: - Private
    
    private func setupWindow() {
        level = .modalPanel
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
    }
    
    private func setupUI() {
        guard let contentView = contentView else { return }
        
        let bgColor = ColorParser.parse(config.backgroundColor) ?? NSColor(white: 0.18, alpha: 0.95)
        let textColor = ColorParser.parse(config.textColor) ?? .white
        let accentColor = ColorParser.parse(config.accentColor) ?? NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        
        // 背景视图
        let backgroundView = NSView(frame: contentView.bounds)
        backgroundView.autoresizingMask = [.width, .height]
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = bgColor.cgColor
        backgroundView.layer?.cornerRadius = CGFloat(config.cornerRadius)
        backgroundView.layer?.masksToBounds = true
        contentView.addSubview(backgroundView)
        
        // 颜色指示器（红/绿圆点）- 放大到 12
        let isChinese = state.mode == "chinese"
        let indicatorColor: NSColor = isChinese ? .systemRed : .systemGreen
        
        let indicatorSize: CGFloat = 12
        indicatorView = NSView(frame: NSRect(
            x: 16,
            y: (contentView.bounds.height - indicatorSize) / 2,
            width: indicatorSize,
            height: indicatorSize
        ))
        indicatorView.wantsLayer = true
        indicatorView.layer?.backgroundColor = indicatorColor.cgColor
        indicatorView.layer?.cornerRadius = indicatorSize / 2
        contentView.addSubview(indicatorView)
        
        // 标题标签 - 字体从 14 放大到 16
        let title = isChinese ? "中文模式" : "英文模式"
        titleLabel = NSTextField(labelWithString: title)
        titleLabel.textColor = textColor
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)  // 放大字体
        titleLabel.sizeToFit()
        titleLabel.frame.origin = NSPoint(
            x: 34,
            y: (contentView.bounds.height - titleLabel.frame.height) / 2
        )
        contentView.addSubview(titleLabel)
        
        // 翻转按钮 - 放大尺寸和字体
        if config.showFlipButton {
            let buttonWidth: CGFloat = 70   // 从 60 增加到 70
            let buttonHeight: CGFloat = 32  // 从 28 增加到 32
            flipButton = NSButton(frame: NSRect(
                x: contentView.bounds.width - buttonWidth - 12,
                y: (contentView.bounds.height - buttonHeight) / 2,
                width: buttonWidth,
                height: buttonHeight
            ))
            
            // 使用纯文本，去掉图标
            flipButton.title = config.flipButtonText
            flipButton.bezelStyle = .rounded
            flipButton.font = .systemFont(ofSize: 13)  // 按钮字体稍微放大
            flipButton.target = self
            flipButton.action = #selector(flipButtonClicked)
            
            // 设置按钮颜色
            flipButton.contentTintColor = accentColor
            
            contentView.addSubview(flipButton)
        }
    }
    
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: contentView?.bounds ?? .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView?.addTrackingArea(trackingArea)
    }
    
    @objc private func flipButtonClicked() {
        onFlip?()
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        pauseTimer()
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        resumeTimer(duration: config.displayDuration)
    }
    
    private static func calculateFrame(for screen: NSScreen, config: ToastConfig) -> NSRect {
        let screenFrame = screen.visibleFrame
        let width = CGFloat(config.width)
        let height = CGFloat(config.height)
        let offsetX = CGFloat(config.offsetX)
        let offsetY = CGFloat(config.offsetY)
        
        // 计算水平位置
        let x: CGFloat
        switch config.hPosition {
        case .left:
            x = screenFrame.minX + offsetX
        case .center:
            x = screenFrame.midX - width / 2 + offsetX
        case .right:
            x = screenFrame.maxX - width - offsetX
        }
        
        // 计算垂直位置
        let y: CGFloat
        switch config.vPosition {
        case .top:
            y = screenFrame.maxY - height - offsetY
        case .center:
            y = screenFrame.midY - height / 2 + offsetY
        case .bottom:
            y = screenFrame.minY + offsetY
        }
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
