import Cocoa
import Carbon

/// 主控制器 - 协调颜色条、Toast 和输入法检测器
@MainActor
class AppController {
    private let config: Config
    private var barManager: IndicatorBarManager?
    private var toastManager: ToastManager?
    private var nativeDetector: NativeDetector?
    private var weTypeDetector: WeTypeDetector?
    
    init(config: Config) {
        self.config = config
    }
    
    func start() {
        // 1. 初始化 UI
        setupBarManager()
        setupToastManager()
        
        // 2. 启动输入法检测器
        setupDetectors()
        
        print("[IMI] 输入法指示器已启动")
    }
    
    func stop() {
        nativeDetector?.stop()
        weTypeDetector?.stop()
        barManager?.hide()
        toastManager?.hideToast()
    }
    
    // MARK: - Private
    
    private func setupBarManager() {
        barManager = IndicatorBarManager(config: config.bar)
        barManager?.show()
    }
    
    private func setupToastManager() {
        toastManager = ToastManager(config: config.toast)
        toastManager?.onFlip = { [weak self] in
            self?.handleFlip()
        }
    }
    
    private func setupDetectors() {
        // 检查是否需要启动 WeType 检测器
        let hasWeTypeConfig = config.inputSources.contains { $0.detectMethod == .shiftKey }
        
        if hasWeTypeConfig {
            weTypeDetector = WeTypeDetector.shared
            weTypeDetector?.quickDoubleShiftThreshold = config.quickDoubleShiftThreshold
            weTypeDetector?.onStateChange = { [weak self] state in
                self?.handleStateChange(state, source: .detector)
            }
            weTypeDetector?.start()
        }
        
        // 始终启动 Native 检测器（用于非 WeType 输入法）
        nativeDetector = NativeDetector()
        nativeDetector?.onStateChange = { [weak self] state in
            self?.handleStateChange(state, source: .detector)
        }
        nativeDetector?.start()
        
        // 初始化当前状态
        updateInitialState()
    }
    
    private func updateInitialState() {
        // 获取当前输入法状态
        if let detector = weTypeDetector, detector.isWeTypeActive {
            let state = InputState(
                sourceID: detector.currentState.sourceID,
                mode: detector.isChineseMode ? "chinese" : "english"
            )
            handleStateChange(state, source: .initial)
        } else if let detector = nativeDetector {
            let state = detector.updateCurrentState()
            handleStateChange(state, source: .initial)
        }
    }
    
    private func handleStateChange(_ state: InputState, source: ChangeSource) {
        guard !state.isEmpty else { return }
        
        // 查找对应的颜色
        if let color = config.color(for: state) {
            barManager?.updateColor(color)
        }
        
        // 触发 Toast（仅当变化来自检测器时）
        if source == .detector {
            toastManager?.showToast(for: state)
        }
    }
    
    private func handleFlip() {
        // 只有 WeType 支持手动翻转
        guard let detector = weTypeDetector, detector.isWeTypeActive else { return }
        
        detector.flipState()
        
        // 更新 Toast 显示新的状态
        let state = InputState(
            sourceID: detector.currentState.sourceID,
            mode: detector.isChineseMode ? "chinese" : "english"
        )
        toastManager?.updateToast(for: state)
    }
    
    enum ChangeSource {
        case initial
        case detector
    }
}
