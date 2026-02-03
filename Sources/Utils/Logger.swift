import Foundation

/// 日志工具
enum Logger {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    /// 切换类型
    enum ToggleType: String {
        case singleShift = "单击Shift"              // 单击 Shift 切换
        case doubleShift = "双击Shift"              // 双击 Shift（切换输入法）
        case toastButton = "Toast按钮"              // 用户点击 Toast 的切换按钮
        case quickDoubleShiftConfirm = "双Shift确认" // 3秒内两次 Shift（确认并保持状态）
        case inputSourceChange = "输入法切换"         // 从其他输入法切换回来
    }
    
    /// 记录普通日志
    static func log(_ message: String, component: String = "IMI") {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\(component)] \(message)")
    }
    
    /// 记录状态切换
    static func logToggle(
        to chineseMode: Bool,
        type: ToggleType,
        component: String = "WeType"
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let modeStr = chineseMode ? "中文(🔴)" : "英文(🟢)"
        print("[\(timestamp)] [\(component)] [切换] \(type.rawValue) → \(modeStr)")
    }
    
    /// 记录进入/离开输入法
    static func logInputSource(
        action: String,  // "进入" 或 "离开"
        source: String,
        mode: String? = nil,
        component: String = "WeType"
    ) {
        let timestamp = dateFormatter.string(from: Date())
        if let mode = mode {
            print("[\(timestamp)] [\(component)] [\(action)] \(source) - \(mode)")
        } else {
            print("[\(timestamp)] [\(component)] [\(action)] \(source)")
        }
    }
    
    /// 记录错误/异常
    static func logError(_ message: String, component: String = "IMI") {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\(component)] [错误] \(message)")
    }
}
