import Carbon
import Cocoa
import CoreGraphics

/// 微信输入法状态检测器
/// 支持：单击立即切换、快速双Shift确认状态
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
    
    // 快速双 Shift 检测（用于状态确认）
    private var lastShiftTime: Date?
    
    // 状态持久化
    private let stateKey = "com.imi.wetype.lastChineseMode"
    private var lastWeTypeChineseMode: Bool {
        get {
            UserDefaults.standard.object(forKey: stateKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: stateKey)
        }
    }
    
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
        Logger.log("开始监听 Shift 键 (单击立即切换，双Shift确认状态)", component: "WeType")
    }
    
    func stop() {
        stopListening()
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
        
        // 检查是否在冷却期内（刚确认过状态，防止误触发）
        if let cooldown = confirmationCooldownUntil,
           now < cooldown {
            Logger.log("冷却期内，忽略Shift", component: "WeType")
            return
        }
        confirmationCooldownUntil = nil
        
        // 检查是否是快速双 Shift（3秒内第二次，用于状态确认）
        if let lastTime = lastShiftTime,
           now.timeIntervalSince(lastTime) < quickDoubleShiftThreshold {
            // 快速双 Shift - 确认并保持当前状态
            Logger.log("快速双 Shift 检测（\(String(format: "%.1f", now.timeIntervalSince(lastTime)))s），确认当前状态", component: "WeType")
            confirmCurrentState()
            return
        }
        
        // 普通单击 - 立即切换（无延迟）
        lastShiftTime = now
        executeToggle()
    }
    
    /// 快速双 Shift 的冷却期，防止误触发
    private var confirmationCooldownUntil: Date?
    
    /// 确认并保持当前状态（快速双Shift功能）
    private func confirmCurrentState() {
        guard isWeTypeActive else {
            Logger.log("确认状态时已离开微信输入法", component: "WeType")
            return
        }
        
        // 不切换状态，只是重新触发通知以刷新显示
        Logger.logToggle(to: isChineseMode, type: .quickDoubleShiftConfirm, component: "WeType")
        onStateChange?(currentState)
        
        // 关键：重置 lastShiftTime，这样下一次 Shift 就是正常单击切换
        lastShiftTime = nil
        
        // 设置冷却期 0.8 秒，防止紧接着的第三次 Shift 误触发切换
        confirmationCooldownUntil = Date().addingTimeInterval(0.8)
        
        Logger.log("状态已确认，0.8秒内忽略下一次Shift", component: "WeType")
    }
    
    /// 执行实际的切换（在微信输入法内单击 Shift）
    private func executeToggle() {
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
