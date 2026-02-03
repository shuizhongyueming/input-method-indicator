import Cocoa

// MARK: - 应用委托

class AppDelegate: NSObject, NSApplicationDelegate {
    private let config: Config
    private var controller: AppController?
    
    init(config: Config) {
        self.config = config
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = AppController(config: config)
        controller?.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}

// MARK: - 主程序

struct InputMethodIndicator {
    static func main() {
        // 解析命令行参数
        let arguments = CommandLine.arguments
        
        if arguments.count > 1 {
            let command = arguments[1]
            switch command {
            case "list":
                Commands.list()
                return
            case "help", "-h", "--help":
                Commands.help()
                return
            case "run":
                break  // 继续运行程序
            default:
                print("Unknown command: \(command)")
                print("Use 'help' for usage information")
                return
            }
        }
        
        // 运行主程序
        run()
    }
    
    static func run() {
        // 检查权限（WeType 检测需要）
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        if !hasPermission {
            print("[IMI] 需要辅助功能权限")
            print("[IMI] 请在 系统设置 > 隐私与安全性 > 辅助功能 中添加此应用")
        }
        
        // 加载配置
        let config: Config
        do {
            config = try ConfigLoader.load()
            print("[IMI] 配置已加载: \(config.inputSources.count) 个输入法")
        } catch ConfigError.fileNotFound(let path) {
            print("[IMI] 配置文件不存在: \(path)")
            print("[IMI] 正在创建默认配置...")
            
            do {
                try ConfigLoader.createDefaultConfig(at: path)
                print("[IMI] 默认配置已创建: \(path)")
                print("[IMI] 请编辑配置后重新运行")
            } catch {
                print("[IMI] 创建配置失败: \(error)")
            }
            return
        } catch {
            print("[IMI] 加载配置失败: \(error)")
            return
        }
        
        // 创建应用
        let app = NSApplication.shared
        let delegate = AppDelegate(config: config)
        app.delegate = delegate
        
        // 设置为后台应用（不显示 Dock 图标）
        app.setActivationPolicy(.accessory)
        
        // 运行
        app.run()
    }
}

// 程序入口
InputMethodIndicator.main()
