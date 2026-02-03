# Input Method Indicator

A lightweight macOS input method status indicator that displays a colored bar at the top or bottom of the screen to identify the current input method and input mode.

[中文说明](#输入法状态指示器)

## Features

- 🔴🟡🟢 **Color Bar Indicator** - Display at top or bottom of screen
- 💬 **Toast Notification** - Shows current mode with manual flip button
- ⏱️ **Timestamped Logs** - Detailed logs for debugging sync issues
- ⚡ **Quick Double Shift** - Press Shift twice within 3 seconds to confirm/correct state
- ⚙️ **TOML Configuration** - Easy to customize
- 🔍 **`list` Command** - View all system input methods
- 🎯 **WeType Optimized** - Special handling for WeChat Input Method (Shift key detection)

## Installation

```bash
git clone <your-repo-url>
cd input-method-indicator
swift build -c release
```

## Usage

### 1. List System Input Methods

```bash
.build/release/input-method-indicator list
```

Output example:
```
Installed Input Sources:
=======================
com.apple.keylayout.ABC                 ABC
com.tencent.inputmethod.wetype.pinyin   WeType
com.apple.inputmethod.SCIM.ITABC        Pinyin - Simplified
```

### 2. First Run (Creates Default Config)

```bash
.build/release/input-method-indicator
# Automatically creates ~/.config/imi/config.toml
```

### 3. Edit Configuration

```bash
vim ~/.config/imi/config.toml
```

### 4. Run

```bash
.build/release/input-method-indicator
```

## Configuration

```toml
[bar]
height = 3
position = "top"          # top | bottom
opacity = 1.0

[toast]
enabled = true
width = 180
height = 50
display_duration = 3.0
flip_button_text = "Switch"

# Quick double Shift threshold (seconds)
# Press Shift twice within this time to confirm/correct state
quick_double_shift_threshold = 3.0

# WeChat Input Method (WeType)
[[input_sources]]
id = "com.tencent.inputmethod.wetype"
name = "WeType"
mode = "chinese"
detect_method = "shift_key"
color = "#FF3B30"         # Red

[[input_sources]]
id = "com.tencent.inputmethod.wetype"
name = "WeType"
mode = "english"
detect_method = "shift_key"
color = "#34C759"         # Green

# System ABC - Yellow for distinction
[[input_sources]]
id = "com.apple.keylayout.ABC"
name = "ABC"
mode = "default"
detect_method = "native"
color = "#FFCC00"         # Yellow

# System Pinyin
[[input_sources]]
id = "com.apple.inputmethod.SCIM.ITABC"
name = "Pinyin - Simplified"
mode = "default"
detect_method = "native"
color = "#FF3B30"         # Red
```

## Shift Key Operations

| Operation | Effect | Log Type |
|-----------|--------|----------|
| **Single Shift** | Toggle Chinese/English | `单击Shift` |
| **Double Shift** | Switch input method | None (for switching IM) |
| **Two Shifts within 3s** | Confirm/correct state | `双Shift确认` |
| **Shift + Other Key** | No toggle | None (combo key) |

## Log Format

All logs include timestamps and clear toggle types:

```
[14:32:15.234] [WeType] [进入] WeChat Input Method - Chinese(🔴)
[14:32:18.567] [WeType] [切换] 单击Shift → English(🟢)
[14:32:20.123] [WeType] [切换] Toast按钮 → Chinese(🔴)  <- User clicked
[14:32:25.891] [WeType] [切换] 双Shift确认 → English(🟢)  <- State confirm
[14:32:30.456] [WeType] [离开] WeChat Input Method - English
```

## Troubleshooting

If you encounter state sync issues, check the logs for:
- Toggle type (Toast按钮, 单击Shift, 双Shift确认)
- Timestamps (to verify quick double Shift)
- Enter/Leave events

## Permissions

Requires **Accessibility Permission** on first run:

System Settings → Privacy & Security → Accessibility → Add `input-method-indicator`

## How It Works

### WeChat Input Method Detection

WeChat Input Method's Chinese/English state cannot be obtained through macOS API, so we infer it by monitoring Shift key:

- **Single Shift press** → Toggle mode
- **Shift + other key** (e.g., `?`, `:`) → Not a toggle (combo key)
- **Double Shift** (<300ms) → Switch input method, no mode toggle
- **Two Shifts within 3s** → Confirm/correct current state

### State Persistence

When switching away from WeChat Input Method, the current state is saved. When switching back, the previous state is restored.

## License

MIT

---

# 输入法状态指示器

轻量级 macOS 输入法状态指示器，在屏幕顶部或底部显示彩色条来标识当前输入法和输入模式。

## 特性

- 🔴🟡🟢 **颜色条指示器** - 显示在屏幕顶部或底部
- 💬 **Toast 通知** - 显示当前模式，带手动翻转按钮
- ⏱️ **时间戳日志** - 详细日志便于调试同步问题
- ⚡ **快速双 Shift** - 3秒内按两次 Shift 确认/纠正状态
- ⚙️ **TOML 配置** - 易于自定义
- 🔍 **`list` 命令** - 查看所有系统输入法
- 🎯 **微信输入法优化** - 针对微信输入法的特殊处理（Shift 键检测）

## 安装

```bash
git clone <你的仓库地址>
cd input-method-indicator
swift build -c release
```

## 使用方法

### 1. 查看系统输入法

```bash
.build/release/input-method-indicator list
```

输出示例：
```
Installed Input Sources:
=======================
com.apple.keylayout.ABC                 ABC
com.tencent.inputmethod.wetype.pinyin   微信输入法
com.apple.inputmethod.SCIM.ITABC        拼音 - 简体
```

### 2. 首次运行（创建默认配置）

```bash
.build/release/input-method-indicator
# 自动创建 ~/.config/imi/config.toml
```

### 3. 编辑配置

```bash
vim ~/.config/imi/config.toml
```

### 4. 运行

```bash
.build/release/input-method-indicator
```

## 配置文件

```toml
[bar]
height = 3
position = "top"          # top | bottom
opacity = 1.0

[toast]
enabled = true
width = 180
height = 50
display_duration = 3.0
flip_button_text = "切换"

# 快速双 Shift 阈值（秒）
# 在此时间内按两次 Shift 用于确认/纠正状态
quick_double_shift_threshold = 3.0

# 微信输入法
[[input_sources]]
id = "com.tencent.inputmethod.wetype"
name = "微信输入法"
mode = "chinese"
detect_method = "shift_key"
color = "#FF3B30"         # 红色

[[input_sources]]
id = "com.tencent.inputmethod.wetype"
name = "微信输入法"
mode = "english"
detect_method = "shift_key"
color = "#34C759"         # 绿色

# 系统 ABC - 使用黄色以便区分
[[input_sources]]
id = "com.apple.keylayout.ABC"
name = "ABC"
mode = "default"
detect_method = "native"
color = "#FFCC00"         # 黄色

# 系统拼音输入法
[[input_sources]]
id = "com.apple.inputmethod.SCIM.ITABC"
name = "拼音 - 简体"
mode = "default"
detect_method = "native"
color = "#FF3B30"         # 红色
```

## Shift 键操作说明

| 操作 | 效果 | 日志类型 |
|-----|------|---------|
| **单击 Shift** | 切换中英文 | `单击Shift` |
| **双击 Shift** | 切换输入法 | 无（用于切换输入法） |
| **3秒内两次 Shift** | 确认/纠正状态 | `双Shift确认` |
| **Shift + 其他键** | 不切换 | 无（组合键） |

## 日志格式

所有日志都带时间戳，切换类型清晰标注：

```
[14:32:15.234] [WeType] [进入] 微信输入法 - 中文(🔴)
[14:32:18.567] [WeType] [切换] 单击Shift → 英文(🟢)
[14:32:20.123] [WeType] [切换] Toast按钮 → 中文(🔴)  <- 用户点击
[14:32:25.891] [WeType] [切换] 双Shift确认 → 英文(🟢)  <- 状态确认
[14:32:30.456] [WeType] [离开] 微信输入法 - 英文
```

## 故障排查

如果遇到状态不同步问题，请检查日志中的：
- 切换类型（Toast按钮、单击Shift、双Shift确认）
- 时间戳（判断是否为快速双 Shift）
- 进入/离开事件

## 权限设置

首次运行需要**辅助功能权限**：

系统设置 → 隐私与安全性 → 辅助功能 → 添加 `input-method-indicator`

## 工作原理

### 微信输入法检测

微信输入法的中英文状态无法通过 macOS API 获取，因此通过监听 Shift 键来推断：

- **单独按 Shift** → 切换中英文模式
- **Shift + 其他键**（如 `?`、`:`）→ 不切换（识别为组合键）
- **双击 Shift**（<300ms）→ 用于切换输入法，不触发模式切换
- **3秒内两次 Shift** → 确认/纠正当前状态

### 状态持久化

离开微信输入法时保存当前状态，切换回来时恢复之前的状态。

## 许可证

MIT
