import Cocoa

enum ColorParser {
    
    /// 解析颜色字符串
    /// 支持格式：#RRGGBB, #RRGGBBAA, rgb(r,g,b), rgba(r,g,b,a)
    static func parse(_ string: String) -> NSColor? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Hex 格式: #RRGGBB 或 #RRGGBBAA
        if trimmed.hasPrefix("#") {
            return parseHex(trimmed)
        }
        
        // RGB 格式: rgb(r,g,b) 或 rgba(r,g,b,a)
        if trimmed.lowercased().hasPrefix("rgb") {
            return parseRGB(trimmed)
        }
        
        return nil
    }
    
    // MARK: - Private
    
    private static func parseHex(_ string: String) -> NSColor? {
        var hex = string
        hex.removeFirst() // 移除 #
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1.0
        
        switch hex.count {
        case 6: // RRGGBB
            guard let value = UInt64(hex, radix: 16) else { return nil }
            r = CGFloat((value >> 16) & 0xFF) / 255.0
            g = CGFloat((value >> 8) & 0xFF) / 255.0
            b = CGFloat(value & 0xFF) / 255.0
            
        case 8: // RRGGBBAA
            guard let value = UInt64(hex, radix: 16) else { return nil }
            r = CGFloat((value >> 24) & 0xFF) / 255.0
            g = CGFloat((value >> 16) & 0xFF) / 255.0
            b = CGFloat((value >> 8) & 0xFF) / 255.0
            a = CGFloat(value & 0xFF) / 255.0
            
        case 3: // RGB (short)
            guard let value = UInt64(hex, radix: 16) else { return nil }
            r = CGFloat((value >> 8) & 0xF) / 15.0
            g = CGFloat((value >> 4) & 0xF) / 15.0
            b = CGFloat(value & 0xF) / 15.0
            
        default:
            return nil
        }
        
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }
    
    private static func parseRGB(_ string: String) -> NSColor? {
        // 提取括号内的数字
        guard let start = string.firstIndex(of: "("),
              let end = string.lastIndex(of: ")") else {
            return nil
        }
        
        let content = string[string.index(after: start)..<end]
        let components = content.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let hasAlpha = string.lowercased().hasPrefix("rgba")
        let expectedCount = hasAlpha ? 4 : 3
        
        guard components.count == expectedCount else { return nil }
        
        guard let r = parseComponent(components[0]),
              let g = parseComponent(components[1]),
              let b = parseComponent(components[2]) else {
            return nil
        }
        
        let a: CGFloat
        if hasAlpha, let alpha = Double(components[3]) {
            a = CGFloat(alpha)
        } else {
            a = 1.0
        }
        
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }
    
    private static func parseComponent(_ string: String) -> CGFloat? {
        // 支持 0-255 或 0%-100% 或 0.0-1.0
        if string.hasSuffix("%") {
            guard let value = Double(string.dropLast()) else { return nil }
            return CGFloat(value / 100.0)
        }
        
        guard let value = Double(string) else { return nil }
        
        // 如果大于 1，假设是 0-255 范围
        if value > 1.0 {
            return CGFloat(value / 255.0)
        }
        
        return CGFloat(value)
    }
}
