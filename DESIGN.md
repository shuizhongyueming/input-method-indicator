# 输入法状态指示器设计方案

## 1. 项目概述

一个轻量级的 macOS 输入法状态指示器，在屏幕顶部/底部显示彩色条来标识当前输入法和输入模式。

## 2. 技术原理（参考 ShowyEdge）

### 2.1 核心机制

| 技术点 | 实现方式 | 说明 |
|-------|---------|------|
| 颜色条显示 | `NSWindow` + `NSView` | 无边框窗口，透明背景，彩色内容 |
| 窗口层级 | `NSWindow.Level.statusBar + 1` | 显示在菜单栏上方 |
| 窗口位置 | 覆盖全屏宽度，固定在顶部/底部 | 不受窗口切换影响 |
| 输入法监听 | `kTISNotifySelectedKeyboardInputSourceChanged` | 系统标准通知 |
| WeType 检测 | CGEventTap 监听 Shift 键 | 推断内部中英文状态 |

### 2.2 ShowyEdge 源码关键参考

```swift
// 创建无边框窗口（参考 ShowyEdge 的 PanelWindow）
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: screen.width, height: config.bar.height),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)

// 关键属性设置
window.level = .statusBar + 1        // 窗口层级
window.isOpaque = false              // 透明背景
window.backgroundColor = .clear
window.ignoresMouseEvents = true     // 不拦截鼠标事件
window.collectionBehavior = [.canJoinAllSpaces, .stationary]  // 所有桌面空间显示
```

## 3. 配置设计（TOML）

### 3.1 完整配置示例

```toml
# config.toml

[bar]
# 颜色条外观
height = 3                    # 高度（像素）
position = "top"              # 位置: "top" | "bottom"
opacity = 1.0                 # 透明度: 0.0 - 1.0
radius = 0                    # 圆角半径（0 = 直角）

# 行为设置
hide_delay = 0.0              # 切换后自动隐藏延迟（秒），0 = 不隐藏
animation_duration = 0.15     # 颜色过渡动画时长（秒）

# 多显示器设置
show_on_all_displays = true   # 是否在所有显示器上显示

[[input_sources]]
# 微信输入法 - 中文模式
id = "com.tencent.inputmethod.wetype"
name = "WeType"
mode = "chinese"              # 模式标识
detect_method = "shift_key"   # 检测方式: "native" | "shift_key"
color = "#FF0000"             # 红色

[[input_sources]]
# 微信输入法 - 英文模式
id = "com.tencent.inputmethod.wetype"
name = "WeType"
mode = "english"
detect_method = "shift_key"
color = "#00FF00"             # 绿色

[[input_sources]]
# 系统 ABC 输入法
id = "com.apple.keylayout.ABC"
name = "ABC"
mode = "default"
detect_method = "native"      # 使用系统 API 检测
color = "#00FF00"             # 绿色

[[input_sources]]
# 搜狗拼音
id = "com.sogou.inputmethod.pinyin"
name = "搜狗拼音"
mode = "default"
detect_method = "native"
color = "#FF0000"             # 红色

# 支持自定义颜色格式
[[input_sources]]
id = "com.apple.inputmethod.Kotoeri.Roman"
name = "日文罗马字"
mode = "default"
detect_method = "native"
color = "rgb(0, 255, 255)"    # 也支持 rgb() 格式
```

### 3.2 配置 Schema

```toml
# bar 段 - 颜色条外观和行为
[bar]
height = { type = "integer", min = 1, max = 20, default = 3 }
position = { type = "string", enum = ["top", "bottom"], default = "top" }
opacity = { type = "float", min = 0.0, max = 1.0, default = 1.0 }
radius = { type = "integer", min = 0, max = 10, default = 0 }
hide_delay = { type = "float", min = 0.0, max = 5.0, default = 0.0 }
animation_duration = { type = "float", min = 0.0, max = 1.0, default = 0.15 }
show_on_all_displays = { type = "boolean", default = true }

# input_sources 数组 - 输入法配置
[[input_sources]]
id = { type = "string", required = true }           # Bundle ID
name = { type = "string", required = true }         # 显示名称
mode = { type = "string", default = "default" }     # 模式标识
detect_method = { type = "string", enum = ["native", "shift_key"], default = "native" }
color = { type = "string", required = true }        # 颜色值
```

## 4. 项目架构

### 4.1 目录结构

```
input-method-indicator/
├── Sources/
│   ├── main.swift                    # 入口
│   ├── AppController.swift           # 主控制器（协调 Bar + Toast）
│   ├── Config/
│   │   ├── Config.swift              # 配置模型（BarConfig + ToastConfig）
│   │   └── ConfigLoader.swift        # TOML 解析
│   ├── UI/
│   │   ├── IndicatorBar.swift        # 颜色条窗口（顶部/底部）
│   │   ├── ToastWindow.swift         # Toast 通知窗口（底部居中）
│   │   └── ToastManager.swift        # Toast 显示/隐藏管理
│   ├── InputMethod/
│   │   ├── InputMethodDetector.swift # 输入法检测器基类
│   │   ├── NativeDetector.swift      # 标准输入法检测
│   │   └── WeTypeDetector.swift      # 微信输入法检测（Shift 键监听）
│   └── Utils/
│       └── ColorParser.swift         # 颜色解析工具
├── Resources/
│   └── config.toml                   # 默认配置
├── Package.swift                     # SPM 配置
└── DESIGN.md                         # 本设计文档
```

### 4.2 核心类设计

```swift
// MARK: - 配置模型

struct Config: Codable {
    let bar: BarConfig
    let inputSources: [InputSourceConfig]
}

struct BarConfig: Codable {
    let height: Int
    let position: Position
    let opacity: Double
    let radius: Int
    let hideDelay: Double
    let animationDuration: Double
    let showOnAllDisplays: Bool
    
    enum Position: String, Codable {
        case top, bottom
    }
}

struct InputSourceConfig: Codable {
    let id: String          // Bundle ID
    let name: String        // 显示名称
    let mode: String        // 模式标识
    let detectMethod: DetectMethod
    let color: String       // 颜色值（支持 #RRGGBB 或 rgb(r,g,b)）
    
    enum DetectMethod: String, Codable {
        case native          // 使用 TIS API
        case shiftKey        // 监听 Shift 键（用于 WeType）
    }
}

// MARK: - 指示器窗口

class IndicatorBar: NSWindow {
    private let colorView: NSView
    private let config: BarConfig
    
    init(screen: NSScreen, config: BarConfig) {
        // 初始化窗口...
    }
    
    func updateColor(_ color: NSColor, animated: Bool) {
        // 更新颜色，支持动画
    }
}

// MARK: - 输入法检测器协议

protocol InputMethodDetector {
    var currentState: InputState { get }
    var onStateChange: ((InputState) -> Void)? { get set }
    func start()
    func stop()
}

struct InputState {
    let sourceID: String
    let mode: String        // 对于 WeType: "chinese"/"english"
}

// MARK: - 主控制器

class AppController {
    private let config: Config
    private var indicatorBars: [IndicatorBar] = []
    private let toastManager: ToastManager
    private var detectors: [InputMethodDetector] = []
    
    func start() {
        // 1. 为每个屏幕创建颜色条
        // 2. 初始化 ToastManager
        // 3. 启动输入法检测器
        // 4. 监听状态变化，同步更新 Bar 和 Toast
    }
    
    private func handleStateChange(_ state: InputState) {
        // 更新所有 IndicatorBar
        // 触发 Toast 显示（如果启用）
    }
}

// MARK: - 微信输入法检测器

class WeTypeDetector: InputMethodDetector {
    // 复用当前 MVP 的实现
    // 增加：根据配置返回对应的 mode 标识
    // 增加：状态变化时触发 Toast
}
```

## 5. 实现计划

### Phase 1: 基础框架（1 天）
- [ ] 创建 Swift Package 项目
- [ ] 实现 TOML 配置解析
- [ ] 创建 IndicatorBar 窗口（参考 ShowyEdge）

### Phase 2: 输入法检测（1 天）
- [ ] 实现标准输入法检测（NativeDetector）
- [ ] 移植 WeType 检测逻辑（WeTypeDetector）
- [ ] 状态管理和切换逻辑

### Phase 3: Toast 通知系统（1 天）
- [ ] 创建 ToastWindow（底部居中、圆角、动画）
- [ ] 实现 ToastManager（显示/隐藏/定时器管理）
- [ ] 添加翻转按钮和交互逻辑
- [ ] 检测状态变化时触发 Toast

### Phase 4: 完善功能（0.5 天）
- [ ] 多显示器支持（Toast 跟随 active screen）
- [ ] 颜色过渡动画
- [ ] 自动隐藏功能
- [ ] 鼠标悬停暂停倒计时

### Phase 4: 打包发布（可选）
- [ ] 创建 .app  bundle
- [ ] 签名和公证
- [ ] Homebrew Formula

## 6. 依赖库

| 库 | 用途 | 版本 |
|---|------|------|
| [TOMLKit](https://github.com/LebJe/TOMLKit) | TOML 解析 | ^1.0 |

## 7. 使用方式

```bash
# 1. 克隆仓库
git clone https://github.com/yourname/input-method-indicator
cd input-method-indicator

# 2. 构建
swift build

# 3. 列出系统输入法（获取 ID 用于配置）
.build/debug/input-method-indicator list
# 输出示例：
# com.apple.keylayout.ABC          ABC
# com.apple.inputmethod.SCIM.ITABC 拼音 - 简体
# com.tencent.inputmethod.wetype   微信输入法

# 4. 编辑配置
cp Resources/config.example.toml ~/.config/imi/config.toml
vim ~/.config/imi/config.toml

# 5. 运行
.build/debug/input-method-indicator

# 6. 后台运行（生产环境）
.build/release/input-method-indicator &
```

## 8. 与 ShowyEdge 对比

| 特性 | ShowyEdge | 本方案 |
|-----|-----------|--------|
| 配置方式 | GUI 设置面板 | TOML 配置文件 |
| 代码量 | ~15k 行（含完整 UI） | 预计 ~500 行 |
| 功能 | 完整（多语言、图标等） | 精简（仅颜色条） |
| WeType 支持 | 需修改源码 | 内置支持 |
| 依赖 | 多（Sparkle 等） | 仅 TOMLKit |

## 9. 风险与注意事项

1. **Accessibility 权限**: WeType 检测需要辅助功能权限
2. **CGEventTap 性能**: 全局按键监听对性能影响极小，但需正确处理
3. **状态同步**: WeType 的实际状态与推断状态可能不一致（如用户用鼠标切换）

---

**下一步**: 如果你同意这个方案，我可以开始实现 Phase 1。

## 10. Toast 通知功能（状态确认与纠正）

### 10.1 功能说明

当 `detect_method` 触发切换时（如 WeType 的 Shift 键），在**当前活动屏幕底部正中**显示 Toast，展示当前模式并允许用户手动翻转。

**目的**：
- 给用户明确的模式切换反馈
- 提供手动纠正机制（应对推断错误）

### 10.2 配置设计

```toml
[bar]
# ... 原有配置 ...

[toast]
# Toast 外观
enabled = true                # 是否启用 Toast
width = 180                   # 宽度（像素）
height = 50                   # 高度（像素）
corner_radius = 10            # 圆角半径
background_color = "#333333"  # 背景色
text_color = "#FFFFFF"        # 文字颜色
accent_color = "#007AFF"      # 强调色（按钮/边框）

# 行为设置
position = "bottom_center"    # 位置: "bottom_center" | "top_center"
offset_y = 20                 # 距离屏幕边缘的偏移（像素）
display_duration = 2.0        # 自动消失时间（秒），0 = 不自动消失
animation_duration = 0.2      # 出现/消失动画时长（秒）

# 按钮设置
show_flip_button = true       # 是否显示翻转按钮
flip_button_text = "切换"     # 翻转按钮文字
```

### 10.3 UI 设计

```
┌─────────────────────────┐
│  🔴 中文模式     [切换]  │  ← 点击"切换"翻转状态
└─────────────────────────┘
       ↑
    屏幕底部正中
```

**状态对应**：
- 中文模式：🔴 红色圆点/边框
- 英文模式：🟢 绿色圆点/边框

### 10.4 交互逻辑

```
触发条件（满足任一）：
1. WeType Shift 键切换（isChineseMode 改变）
2. 用户点击 Toast 的"切换"按钮
3. 其他 detect_method 触发

显示逻辑：
- 在当前鼠标所在的 screen 显示（或 keyWindow 所在的 screen）
- 出现后，如果 display_duration > 0，自动消失
- 鼠标悬停时暂停倒计时
- 点击"切换"按钮：立即翻转状态，更新颜色条，Toast 刷新内容

消失逻辑：
- 倒计时结束自动淡出
- 用户点击 Toast 外部区域立即消失
- 输入法再次切换时，旧 Toast 立即消失，新 Toast 出现
```

### 10.5 类设计

```swift
// MARK: - Toast 窗口

class ToastWindow: NSWindow {
    private let titleLabel: NSTextField
    private let flipButton: NSButton
    private let indicatorView: NSView  // 颜色指示器（红/绿圆点）
    
    init(screen: NSScreen, config: ToastConfig, state: InputState)
    
    func show()
    func hide(animated: Bool)
    func updateState(_ state: InputState)  // 刷新内容（不重新显示）
}

// MARK: - Toast 管理器

class ToastManager {
    private var currentToast: ToastWindow?
    private var hideTimer: Timer?
    private let config: ToastConfig
    
    /// 显示 Toast（自动处理位置、动画）
    func showToast(for state: InputState, on screen: NSScreen? = nil)
    
    /// 隐藏当前 Toast
    func hideToast()
    
    /// 用户点击翻转按钮
    var onFlip: (() -> Void)?
}

// MARK: - 与 InputMethodDetector 集成

class WeTypeDetector: InputMethodDetector {
    private let toastManager: ToastManager
    
    private func toggleMode() {
        isChineseMode.toggle()
        
        // 触发 Toast 显示
        let state = InputState(sourceID: weTypeBundleID, 
                              mode: isChineseMode ? "chinese" : "english")
        toastManager.showToast(for: state)
        
        onStateChange?(state)
    }
}
```

### 10.6 与颜色条的联动

```swift
// 主控制器协调两者
class AppController {
    private let indicatorBars: [IndicatorBar]      // 每个屏幕一个
    private let toastManager: ToastManager
    
    func handleStateChange(_ state: InputState) {
        // 1. 更新所有屏幕的颜色条
        let color = config.getColor(for: state)
        indicatorBars.forEach { $0.updateColor(color) }
        
        // 2. 显示 Toast（如果启用且是 detect_method 触发）
        if config.toast.enabled {
            toastManager.showToast(for: state)
        }
    }
}
```

### 10.7 完整配置示例（含 Toast）

```toml
[bar]
height = 3
position = "top"
opacity = 1.0

[toast]
enabled = true
width = 160
height = 44
corner_radius = 8
background_color = "#2C2C2E"
text_color = "#FFFFFF"
accent_color = "#0A84FF"      # iOS 风格蓝色
position = "bottom_center"
offset_y = 16
display_duration = 2.5
animation_duration = 0.2
show_flip_button = true
flip_button_text = "⇄ 切换"

# 微信输入法 - 需要 detect_method = "shift_key"
[[input_sources]]
id = "com.tencent.inputmethod.wetype"
name = "微信输入法"
mode = "chinese"
detect_method = "shift_key"
color = "#FF3B30"             # iOS 红色

[[input_sources]]
id = "com.tencent.inputmethod.wetype"
name = "微信输入法"
mode = "english"
detect_method = "shift_key"
color = "#34C759"             # iOS 绿色

# 系统 ABC 输入法 - 使用 detect_method = "native"
[[input_sources]]
id = "com.apple.keylayout.ABC"
name = "ABC"
mode = "default"
detect_method = "native"
color = "#34C759"             # 英文：绿色

# 系统拼音输入法
[[input_sources]]
id = "com.apple.inputmethod.SCIM.ITABC"
name = "拼音 - 简体"
mode = "default"
detect_method = "native"
color = "#FF3B30"             # 中文：红色
```


## 11. CLI 命令

### 11.1 list 命令

列出系统安装的所有输入法，方便用户获取 `id` 配置项。

```bash
$ input-method-indicator list

Installed Input Sources:
=======================
com.apple.keylayout.ABC              ABC
com.apple.inputmethod.SCIM.ITABC     拼音 - 简体
com.tencent.inputmethod.wetype       微信输入法
com.sogou.inputmethod.pinyin         搜狗拼音
```

**实现**：

```swift
// Sources/CLI/Commands.swift

func listCommand() {
    let sources = TISCreateInputSourceList(nil, false).takeRetainedValue()
    
    print("Installed Input Sources:")
    print("=======================")
    
    for i in 0..<CFArrayGetCount(sources) {
        let source = Unmanaged<TISInputSource>.fromOpaque(
            CFArrayGetValueAtIndex(sources, i)
        ).takeUnretainedValue()
        
        guard let id = source.inputSourceID,
              let name = source.localizedName else { continue }
        
        // 过滤掉非键盘输入法
        guard isKeyboardInputSource(source) else { continue }
        
        print(String(format: "%-36s %@", id, name))
    }
}
```
