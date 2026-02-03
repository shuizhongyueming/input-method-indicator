import Carbon
import Cocoa
import CoreGraphics

/// 微信输入法状态检测器
/// 支持：单击切换、双击切换输入法、三秒内两次Shift确认状态
@MainActor
class WeTypeDetector: InputMethodDetector {
    
    static let shared = WeTypeDetector()
    
    private(set) var currentState: InputState = .empty
    var onStateChange: ((InputState) -> Void)?
    
    /// 当前是否是微信输入法
    private(set) var isWeTypeActive: Bool = false
    
    /// 推断的中文状态（true=中文，false=英文）
    private(set) var isChineseMode: Bool = true
    
    /// 快速双 Shift 阈值（秒）
    var quickDoubleShiftThreshold: TimeInterval = 3.0
    
    private let weTypeBundleID = "com.tencent.inputmethod.wetype"
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Shift 检测状态
    private var shiftPressed: Bool = false
    private var shiftUsedAsModifier: Bool = false
    private var keysPressedDuringShift: Set<Int64> = []
    
    // 双击检测（用于切换输入法）
    private var lastShiftReleaseTime: Date?
    private var pendingToggleTimer: Timer?
    private let doubleClickThreshold: TimeInterval = 0.3
    
    // 快速双 Shift 检测（用于状态确认/纠正）
    private var lastToggleTime: Date?
    
    // 标记是否是双击导致的输入法切换
    private var isDoubleClickSwitching: Bool = false
    
    // 状态持久化
    private var lastWeTypeChineseMode: Bool = true
    
    init() {
        checkCurrentInputSource()
        setupInputSourceListener()
    }
    
    func start() {
        guard eventTap == nil else { return }
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        if !hasPermission {
            Logger.logError("需要辅助功能权限", component: "WeType")
        }
        
        setupEventTap()
        Logger.log("开始监听 Shift 键 (快速双Shift阈值: \(quickDoubleShiftThreshold)s，功能: 状态确认)", component: "WeType")
    }
    
    func stop() {
        stopListening()
        pendingToggleTimer?.invalidate()
        pendingToggleTimer = nil
    }
    
    /// 手动翻转状态（Toast 按钮点击）
    func flipState() {
        guard isWeTypeActive else { return }
        
        isChineseMode.toggle()
        lastWeTypeChineseMode = isChineseMode
        updateCurrentState()
        
        Logger.logToggle(to: isChineseMode, type: .toastButton, component: "WeType")
        onStateChange?(currentState)
    }
    
    // MARK: - Private
    
    private func setupInputSourceListener() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: kTISNotifySelectedKeyboardInputSourceChanged as NSNotification.Name?,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }
    
    @objc private func inputSourceChanged() {
        checkCurrentInputSource()
    }
    
    private func checkCurrentInputSource() {
        guard let source = getCurrentKeyboardInputSource(),
              let sourceID = source.inputSourceID else {
            return
        }
        
        let wasActive = isWeTypeActive
        isWeTypeActive = sourceID.contains("wetype") || sourceID.contains("tencent")
        
        if isWeTypeActive != wasActive {
            if isWeTypeActive {
                // 切换到微信输入法
                isChineseMode = lastWeTypeChineseMode
                updateCurrentState()
                
                let modeStr = isChineseMode ? "中文(🔴)" : "英文(🟢)"
                Logger.logInputSource(action: "进入", source: "微信输入法", mode: modeStr, component: "WeType")
                onStateChange?(currentState)
            } else {
                // 离开微信输入法
                lastWeTypeChineseMode = isChineseMode
                Logger.logInputSource(action: "离开", source: "微信输入法", mode: isChineseMode ? "中文" : "英文", component: "WeType")
                
                if isDoubleClickSwitching {
                    Logger.log("双击导致的离开，隐藏 Toast", component: "WeType")
                    isDoubleClickSwitching = false
                }
            }
        }
    }
    
    private func updateCurrentState() {
        currentState = InputState(
            sourceID: weTypeBundleID,
            mode: isChineseMode ? "chinese" : "english"
        )
    }
    
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                WeTypeDetector.handleEvent(proxy: proxy, type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            Logger.logError("无法创建事件监听", component: "WeType")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func stopListening() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    private static func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) {
        Task { @MainActor in
            switch type {
            case .keyDown:
                WeTypeDetector.shared.handleKeyDown(event: event)
            case .keyUp:
                WeTypeDetector.shared.handleKeyUp(event: event)
            case .flagsChanged:
                WeTypeDetector.shared.handleFlagsChanged(event: event)
            default:
                break
            }
        }
    }
    
    private func handleKeyDown(event: CGEvent) {
        guard isWeTypeActive else { return }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // 如果正在等待单击确认时，又按下了 Shift，认为是双击的开始
        if (keyCode == 56 || keyCode == 60) && pendingToggleTimer != nil {
            cancelPendingToggle()
            Logger.log("检测到双击 Shift，取消模式切换", component: "WeType")
            return
        }
        
        if shiftPressed {
            keysPressedDuringShift.insert(keyCode)
            if keyCode != 56 && keyCode != 60 {
                shiftUsedAsModifier = true
            }
        }
    }
    
    private func handleKeyUp(event: CGEvent) {
        guard isWeTypeActive else { return }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        keysPressedDuringShift.remove(keyCode)
    }
    
    private func handleFlagsChanged(event: CGEvent) {
        let flags = event.flags
        let isShiftCurrentlyPressed = flags.contains(.maskShift)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        guard keyCode == 56 || keyCode == 60 else { return }
        
        if isShiftCurrentlyPressed && !shiftPressed {
            shiftPressed = true
            shiftUsedAsModifier = false
            keysPressedDuringShift.removeAll()
            
        } else if !isShiftCurrentlyPressed && shiftPressed {
            shiftPressed = false
            
            if !shiftUsedAsModifier {
                handleShiftRelease()
            } else {
                Logger.log("跳过切换: Shift 被用作组合键修饰器", component: "WeType")
            }
            
            shiftUsedAsModifier = false
            keysPressedDuringShift.removeAll()
        }
    }
    
    private func handleShiftRelease() {
        let now = Date()
        
        // 检查是否是双击（300ms 内）- 用于切换输入法
        if let lastRelease = lastShiftReleaseTime,
           now.timeIntervalSince(lastRelease) < doubleClickThreshold {
            // 双击 - 标记为输入法切换，不触发模式切换
            isDoubleClickSwitching = true
            Logger.log("双击 Shift - 用于切换输入法", component: "WeType")
            cancelPendingToggle()
            lastShiftReleaseTime = nil
            return
        }
        
        // 检查是否是快速双 Shift（3秒内第二次单击，用于状态确认/纠正）
        if let lastToggle = lastToggleTime,
           now.timeIntervalSince(lastToggle) < quickDoubleShiftThreshold {
            // 快速双 Shift - 确认并保持当前状态，不切换
            // 这用于处理状态不同步的情况：用户发现状态不对，快速按两次Shift来确认想要的状态
            Logger.log("快速双 Shift 检测（\(String(format: "%.1f", now.timeIntervalSince(lastToggle)))s），确认当前状态", component: "WeType")
            confirmCurrentState()
            lastShiftReleaseTime = now
            return
        }
        
        // 普通单击 - 延迟执行以检测双击
        scheduleToggle()
        lastShiftReleaseTime = now
    }
    
    /// 确认并保持当前状态（快速双Shift功能）
    private func confirmCurrentState() {
        guard isWeTypeActive else {
            Logger.log("确认状态时已离开微信输入法", component: "WeType")
            return
        }
        
        // 不切换状态，只是重新触发通知以刷新显示
        // 这表示"用户确认想要当前显示的状态"
        Logger.logToggle(to: isChineseMode, type: .quickDoubleShiftConfirm, component: "WeType")
        onStateChange?(currentState)
        
        // 关键：重置 lastToggleTime，这样下一次 Shift 就是正常单击切换
        lastToggleTime = nil
        Logger.log("状态已确认，重置切换计时器", component: "WeType")
    }
    
    private func scheduleToggle() {
        cancelPendingToggle()
        
        pendingToggleTimer = Timer.scheduledTimer(withTimeInterval: doubleClickThreshold, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.executeToggle()
        }
    }
    
    private func cancelPendingToggle() {
        pendingToggleTimer?.invalidate()
        pendingToggleTimer = nil
    }
    
    /// 执行实际的切换（在微信输入法内单击 Shift）
    private func executeToggle() {
        pendingToggleTimer = nil
        lastToggleTime = Date()
        
        guard isWeTypeActive else {
            Logger.log("切换时已离开微信输入法，跳过", component: "WeType")
            return
        }
        
        isChineseMode.toggle()
        lastWeTypeChineseMode = isChineseMode
        updateCurrentState()
        
        Logger.logToggle(to: isChineseMode, type: .singleShift, component: "WeType")
        onStateChange?(currentState)
    }
}
