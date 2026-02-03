import Cocoa

/// Toast 管理器
@MainActor
class ToastManager {
    private let config: ToastConfig
    private var currentToast: ToastWindow?
    
    /// 用户点击翻转按钮的回调
    var onFlip: (() -> Void)?
    
    init(config: ToastConfig) {
        self.config = config
    }
    
    /// 显示 Toast
    /// - Parameters:
    ///   - state: 当前输入状态
    ///   - screen: 指定屏幕（nil 则使用当前鼠标所在屏幕）
    func showToast(for state: InputState, on screen: NSScreen? = nil) {
        guard config.enabled else { return }
        
        // 关闭旧 Toast
        hideCurrentToast()
        
        // 确定要显示的屏幕
        let targetScreen = screen ?? getActiveScreen()
        
        // 创建新 Toast
        let toast = ToastWindow(
            screen: targetScreen,
            config: config,
            state: state,
            onFlip: { [weak self] in
                self?.handleFlip()
            }
        )
        
        currentToast = toast
        toast.show(animated: true)
        
        // 开始自动隐藏倒计时
        if config.displayDuration > 0 {
            toast.startHideTimer(duration: config.displayDuration)
        }
    }
    
    /// 隐藏当前 Toast
    func hideToast() {
        hideCurrentToast()
    }
    
    /// 更新当前 Toast 的状态（用于翻转后刷新）
    func updateToast(for state: InputState) {
        guard config.enabled else { return }
        
        // 先隐藏旧的
        hideCurrentToast()
        
        // 重新显示新的状态
        let targetScreen = getActiveScreen()
        let toast = ToastWindow(
            screen: targetScreen,
            config: config,
            state: state,
            onFlip: { [weak self] in
                self?.handleFlip()
            }
        )
        
        currentToast = toast
        toast.show(animated: true)
        
        // 重置倒计时
        if config.displayDuration > 0 {
            toast.startHideTimer(duration: config.displayDuration)
        }
    }
    
    // MARK: - Private
    
    private func hideCurrentToast() {
        currentToast?.hide(animated: true)
        currentToast = nil
    }
    
    private func handleFlip() {
        onFlip?()
    }
    
    /// 获取当前活动的屏幕（鼠标所在或 keyWindow 所在）
    private func getActiveScreen() -> NSScreen {
        // 尝试获取鼠标位置
        let mouseLocation = NSEvent.mouseLocation
        
        // 找到包含鼠标位置的屏幕
        if let screen = NSScreen.screens.first(where: { screen in
            screen.frame.contains(mouseLocation)
        }) {
            return screen
        }
        
        // 回退到主屏幕
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
