import Foundation
import Carbon

// MARK: - 输入法检测器协议

@MainActor
protocol InputMethodDetector: AnyObject {
    var currentState: InputState { get }
    var onStateChange: ((InputState) -> Void)? { get set }
    func start()
    func stop()
}

// MARK: - TISInputSource 扩展

extension TISInputSource {
    var inputSourceID: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var inputModeID: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputModeID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var localizedName: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyLocalizedName) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var category: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceCategory) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var isKeyboardInputSource: Bool {
        return category == kTISCategoryKeyboardInputSource as String
    }
}

// MARK: - 工具函数

/// 获取当前键盘输入源
func getCurrentKeyboardInputSource() -> TISInputSource? {
    return TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
}

/// 获取所有键盘输入源
func getAllKeyboardInputSources() -> [TISInputSource] {
    guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
        return []
    }
    
    var sources: [TISInputSource] = []
    let count = CFArrayGetCount(list)
    
    for i in 0..<count {
        let source = Unmanaged<TISInputSource>.fromOpaque(
            CFArrayGetValueAtIndex(list, i)
        ).takeUnretainedValue()
        
        if source.isKeyboardInputSource {
            sources.append(source)
        }
    }
    
    return sources
}
