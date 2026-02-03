import Foundation
import Carbon
import Cocoa

/// 标准输入法检测器（使用 TIS API）
class NativeDetector: InputMethodDetector {
    
    private(set) var currentState: InputState = .empty
    var onStateChange: ((InputState) -> Void)?
    
    init() {
        // 初始化当前状态
        updateCurrentState()
    }
    
    func start() {
        // 监听输入法变化通知
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: kTISNotifySelectedKeyboardInputSourceChanged as NSNotification.Name?,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }
    
    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    /// 更新当前状态
    @discardableResult
    func updateCurrentState() -> InputState {
        guard let source = getCurrentKeyboardInputSource(),
              let sourceID = source.inputSourceID else {
            currentState = .empty
            return currentState
        }
        
        // 对于 native 检测，mode 使用 sourceID 作为标识
        // 或者使用 "default" 模式
        currentState = InputState(sourceID: sourceID, mode: "default")
        return currentState
    }
    
    // MARK: - Private
    
    @objc private func inputSourceChanged() {
        let oldState = currentState
        updateCurrentState()
        
        if currentState != oldState {
            onStateChange?(currentState)
        }
    }
}
