import Cocoa

// MARK: - 根配置

struct Config: Codable {
    let bar: BarConfig
    let toast: ToastConfig
    let inputSources: [InputSourceConfig]
    let quickDoubleShiftThreshold: Double  // 快速双 Shift 阈值（秒）
}

// MARK: - 颜色条配置

struct BarConfig: Codable {
    let height: Int
    let position: BarPosition
    let opacity: Double
    let radius: Int
    let hideDelay: Double
    let animationDuration: Double
    let showOnAllDisplays: Bool
    
    enum BarPosition: String, Codable {
        case top, bottom
    }
    
    static let `default` = BarConfig(
        height: 3,
        position: .top,
        opacity: 1.0,
        radius: 0,
        hideDelay: 0.0,
        animationDuration: 0.15,
        showOnAllDisplays: true
    )
}

// MARK: - Toast 配置

struct ToastConfig: Codable {
    let enabled: Bool
    let width: Int
    let height: Int
    let cornerRadius: Int
    let backgroundColor: String
    let textColor: String
    let accentColor: String
    let hPosition: HorizontalPosition  // 水平位置: left, center, right
    let vPosition: VerticalPosition    // 垂直位置: top, center, bottom
    let offsetX: Int                   // 水平偏移
    let offsetY: Int                   // 垂直偏移
    let displayDuration: Double
    let animationDuration: Double
    let showFlipButton: Bool
    let flipButtonText: String
    
    enum HorizontalPosition: String, Codable {
        case left, center, right
    }
    
    enum VerticalPosition: String, Codable {
        case top, center, bottom
    }
    
    static let `default` = ToastConfig(
        enabled: true,
        width: 180,
        height: 50,
        cornerRadius: 8,
        backgroundColor: "#2C2C2E",
        textColor: "#FFFFFF",
        accentColor: "#0A84FF",
        hPosition: .center,
        vPosition: .bottom,
        offsetX: 0,
        offsetY: 20,
        displayDuration: 3.0,
        animationDuration: 0.2,
        showFlipButton: true,
        flipButtonText: "切换"
    )
}

// MARK: - 输入法配置

struct InputSourceConfig: Codable {
    let id: String
    let name: String
    let mode: String
    let detectMethod: DetectMethod
    let color: String
    
    enum DetectMethod: String, Codable {
        case native
        case shiftKey = "shift_key"
    }
}

// MARK: - 输入状态

struct InputState: Equatable {
    let sourceID: String
    let mode: String
    
    var isEmpty: Bool {
        return sourceID.isEmpty
    }
    
    static let empty = InputState(sourceID: "", mode: "")
}

// MARK: - 配置查找扩展

extension Config {
    /// 根据当前状态查找对应的颜色
    func color(for state: InputState) -> NSColor? {
        let match = inputSources.first { config in
            config.id == state.sourceID && config.mode == state.mode
        }
        
        return match.flatMap { ColorParser.parse($0.color) }
    }
    
    /// 查找输入法的显示名称
    func name(for sourceID: String) -> String? {
        return inputSources.first { $0.id == sourceID }?.name
    }
    
    /// 检查是否需要特殊检测方法
    func detectMethod(for sourceID: String) -> InputSourceConfig.DetectMethod? {
        return inputSources.first { $0.id == sourceID }?.detectMethod
    }
}
