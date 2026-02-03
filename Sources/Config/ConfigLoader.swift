import Foundation
import TOMLKit

enum ConfigError: Error {
    case fileNotFound(path: String)
    case parseError(String)
    case invalidValue(String)
}

struct ConfigLoader {
    
    /// 加载配置文件
    static func load(from path: String? = nil) throws -> Config {
        let configPath = path ?? defaultConfigPath()
        
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw ConfigError.fileNotFound(path: configPath)
        }
        
        let tomlString = try String(contentsOfFile: configPath, encoding: .utf8)
        let table = try TOMLTable(string: tomlString)
        
        return try parseConfig(table)
    }
    
    /// 创建默认配置文件
    static func createDefaultConfig(at path: String) throws {
        let config = defaultConfigContent()
        let configDir = (path as NSString).deletingLastPathComponent
        
        if !FileManager.default.fileExists(atPath: configDir) {
            try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        }
        
        try config.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Private
    
    private static func defaultConfigPath() -> String {
        let home = NSHomeDirectory()
        return "\(home)/.config/imi/config.toml"
    }
    
    private static func parseConfig(_ table: TOMLTable) throws -> Config {
        let barTable = table["bar"]?.table ?? TOMLTable()
        let toastTable = table["toast"]?.table ?? TOMLTable()
        
        // Parse bar config
        let barConfig = BarConfig(
            height: barTable["height"]?.int ?? 3,
            position: BarConfig.BarPosition(rawValue: barTable["position"]?.string ?? "top") ?? .top,
            opacity: barTable["opacity"]?.double ?? 1.0,
            radius: barTable["radius"]?.int ?? 0,
            hideDelay: barTable["hide_delay"]?.double ?? 0.0,
            animationDuration: barTable["animation_duration"]?.double ?? 0.15,
            showOnAllDisplays: barTable["show_on_all_displays"]?.bool ?? true
        )
        
        // Parse toast config
        let toastConfig = ToastConfig(
            enabled: toastTable["enabled"]?.bool ?? true,
            width: toastTable["width"]?.int ?? 180,
            height: toastTable["height"]?.int ?? 50,
            cornerRadius: toastTable["corner_radius"]?.int ?? 8,
            backgroundColor: toastTable["background_color"]?.string ?? "#2C2C2E",
            textColor: toastTable["text_color"]?.string ?? "#FFFFFF",
            accentColor: toastTable["accent_color"]?.string ?? "#0A84FF",
            hPosition: ToastConfig.HorizontalPosition(rawValue: toastTable["h_position"]?.string ?? "center") ?? .center,
            vPosition: ToastConfig.VerticalPosition(rawValue: toastTable["v_position"]?.string ?? "bottom") ?? .bottom,
            offsetX: toastTable["offset_x"]?.int ?? 0,
            offsetY: toastTable["offset_y"]?.int ?? 20,
            displayDuration: toastTable["display_duration"]?.double ?? 3.0,
            animationDuration: toastTable["animation_duration"]?.double ?? 0.2,
            showFlipButton: toastTable["show_flip_button"]?.bool ?? true,
            flipButtonText: toastTable["flip_button_text"]?.string ?? "切换"
        )
        
        // Parse quick double shift threshold
        let quickDoubleShiftThreshold = table["quick_double_shift_threshold"]?.double ?? 3.0
        
        // Parse input sources
        var inputSources: [InputSourceConfig] = []
        if let sourcesArray = table["input_sources"]?.array {
            for (index, element) in sourcesArray.enumerated() {
                guard let sourceTable = element.table else {
                    throw ConfigError.parseError("input_sources[\(index)] 不是有效的表")
                }
                
                guard let id = sourceTable["id"]?.string else {
                    throw ConfigError.parseError("input_sources[\(index)] 缺少 id")
                }
                
                guard let name = sourceTable["name"]?.string else {
                    throw ConfigError.parseError("input_sources[\(index)] 缺少 name")
                }
                
                guard let color = sourceTable["color"]?.string else {
                    throw ConfigError.parseError("input_sources[\(index)] 缺少 color")
                }
                
                let mode = sourceTable["mode"]?.string ?? "default"
                let detectMethod = InputSourceConfig.DetectMethod(
                    rawValue: sourceTable["detect_method"]?.string ?? "native"
                ) ?? .native
                
                inputSources.append(InputSourceConfig(
                    id: id,
                    name: name,
                    mode: mode,
                    detectMethod: detectMethod,
                    color: color
                ))
            }
        }
        
        return Config(
            bar: barConfig,
            toast: toastConfig,
            inputSources: inputSources,
            quickDoubleShiftThreshold: quickDoubleShiftThreshold
        )
    }
    
    private static func defaultConfigContent() -> String {
        return """
        [bar]
        height = 3
        position = "top"
        opacity = 1.0
        radius = 0
        hide_delay = 0.0
        animation_duration = 0.15
        show_on_all_displays = true

        [toast]
        enabled = true
        width = 180
        height = 50
        corner_radius = 10
        background_color = "#2C2C2E"
        text_color = "#FFFFFF"
        accent_color = "#0A84FF"
        
        # Toast 位置配置（9宫格）
        # 水平位置: left | center | right
        # 垂直位置: top | center | bottom
        h_position = "center"
        v_position = "bottom"
        
        # 偏移量（像素）
        offset_x = 0
        offset_y = 20
        
        display_duration = 3.0
        animation_duration = 0.2
        show_flip_button = true
        flip_button_text = "切换"

        # 快速双 Shift 检测阈值（秒）
        # 3 秒内两次 Shift 用于确认/纠正状态
        quick_double_shift_threshold = 3.0

        # 微信输入法 - 需要 detect_method = "shift_key"
        [[input_sources]]
        id = "com.tencent.inputmethod.wetype"
        name = "微信输入法"
        mode = "chinese"
        detect_method = "shift_key"
        color = "#FF3B30"

        [[input_sources]]
        id = "com.tencent.inputmethod.wetype"
        name = "微信输入法"
        mode = "english"
        detect_method = "shift_key"
        color = "#34C759"

        # 系统 ABC 输入法 - 使用黄色以便区分
        [[input_sources]]
        id = "com.apple.keylayout.ABC"
        name = "ABC"
        mode = "default"
        detect_method = "native"
        color = "#FFCC00"

        # 系统拼音输入法
        [[input_sources]]
        id = "com.apple.inputmethod.SCIM.ITABC"
        name = "拼音 - 简体"
        mode = "default"
        detect_method = "native"
        color = "#FF3B30"
        """
    }
}
