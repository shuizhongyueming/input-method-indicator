import Foundation
import Carbon

/// CLI 命令
enum Commands {
    
    /// 列出系统安装的所有输入法
    static func list() {
        print("Installed Input Sources:")
        print("=======================")
        
        let sources = getAllKeyboardInputSources()
        
        // 按名称排序
        let sortedSources = sources.sorted { a, b in
            let nameA = a.localizedName ?? a.inputSourceID ?? ""
            let nameB = b.localizedName ?? b.inputSourceID ?? ""
            return nameA < nameB
        }
        
        // 计算最大 ID 长度用于对齐
        let maxIDLength = sortedSources.compactMap { $0.inputSourceID?.count }.max() ?? 36
        
        for source in sortedSources {
            guard let id = source.inputSourceID,
                  let name = source.localizedName else { continue }
            
            print(String(format: "%-*s   %@", maxIDLength, (id as NSString).utf8String!, name))
        }
        
        print("\nTip: Copy the ID to your config.toml file")
    }
    
    /// 显示帮助信息
    static func help() {
        print("""
        Input Method Indicator
        
        Usage:
          input-method-indicator [command]
        
        Commands:
          run       Run the indicator (default)
          list      List all installed input sources
          help      Show this help message
        
        Configuration:
          Config file: ~/.config/imi/config.toml
        """)
    }
}
