# FlClash 对话交接

> 更新日期：2026-08-13
> 工作目录：`D:\Codex\FlClash`
> 当前维护目标：保留 PR #2237 的 TUN 配置序列化修复，同时维护 Windows 便携模式和 stable/pre 一键构建。

## 1. 用户目标

用户使用同一份 Clash 配置时发现：

- ClashMi 的 TUN/DNS 配置正常生效，BrowserLeaks 未显示本地运营商 DNS。
- FlClash 曾把 `auto-detect-interface` 错误序列化为 `AutoDetectInterface`，导致 Mihomo 未按预期识别该字段。
- 用户要求合并 FlClash PR #2237，验证 DNS，再编译 Windows amd64 成品。
- 后续每次同步 FlClash 官方上游，都必须继续保留这项修复，直到官方上游已正式包含等价修复。

## 2. 当前源码状态

父仓库：

```text
origin: https://github.com/chen08209/FlClash.git
branch: codex/merge-pr-2237
官方基线: 7c831855efedceb1a72bd0b4c18da026593d0853
PR #2237 提交: e55e92c58073a4bc7278f1fd9cdcfacb4619a7ff
本地合并提交: d3702daf869aa08a41a1079b693659e27ef97b85
```

Clash.Meta 子模块：

```text
路径: core/Clash.Meta
修复提交: e6eb54620b18254b9d27f86b0b605b2097b1b3fe
修复前指针: 80362fc1895dcf60b79b562896653046e0687413
```

相对当时官方基线，父仓库只更新了 `core/Clash.Meta` 子模块指针，没有其他业务源码修改。

当前可能存在未跟踪的 `work/`，它只包含构建 staging 和解压验证内容，不属于源码提交。

## 3. PR #2237 的实际修复

文件：`core/Clash.Meta/config/config.go`

```go
// 修复前
AutoDetectInterface bool `yaml:"auto-detect-interface"`

// 修复后
AutoDetectInterface bool `yaml:"auto-detect-interface" json:"auto-detect-interface"`
```

测试文件：

```text
core/Clash.Meta/config/raw_tun_test.go
```

此测试确认 JSON 中存在：

```json
{"auto-detect-interface": true}
```

并且不存在错误字段：

```json
{"AutoDetectInterface": true}
```

## 4. 已完成验证

最终运行配置已确认包含：

```yaml
tun:
  enable: true
  stack: "gvisor"
  dns-hijack:
    - "any:53"
  auto-route: true
  auto-detect-interface: true
```

独立验证时已停止 ClashMi，只保留修复后的 FlClash：

- `FlClash / Meta Tunnel` 网卡状态为 `Up`。
- TUN 路由已建立。
- 系统 DNS 中出现 FlClash 的 `198.18.0.2`。
- BrowserLeaks 出口 IP：`216.40.85.151`。
- BrowserLeaks：41 个 DNS，均为 Google LLC / United States, Los Angeles。
- 未发现 ChinaNet、中国联通、中国移动等本地运营商 DNS。

验证材料：

```text
C:\Users\Rulio\Documents\Codex\2026-08-13\new-chat\outputs\BrowserLeaks-FlClash-PR2237-gvisor.png
C:\Users\Rulio\Documents\Codex\2026-08-13\new-chat\outputs\BrowserLeaks-FlClash-PR2237-gvisor.txt
C:\Users\Rulio\Documents\Codex\2026-08-13\new-chat\outputs\FlClash-0.8.94-PR2237-verification.txt
```

## 5. 已交付成品

```text
C:\Users\Rulio\Documents\Codex\2026-08-13\new-chat\outputs\FlClash-0.8.94-PR2237-windows-amd64.zip
```

ZIP SHA256：

```text
D6C6A27B6921857F1F8A687A1E82DB8BB372A018F7093F2E3F229922048EFDD9
```

ZIP 内 `FlClashCore.exe` SHA256：

```text
84D9BB922B9BB80B3E87D652E46BEB2DC33EB1F6652603D62F0EAA97A25387C4
```

已确认 ZIP 内核心与 BrowserLeaks 实测所用核心一致。

## 6. 后续接手的首要规则

**每次更新 FlClash 官方上游后，都要确认 PR #2237 的效果仍然存在。**

但不要机械地把父仓库提交 `e55e92c` cherry-pick 到未来版本。该提交固定指向旧的 Clash.Meta 提交 `e6eb5462`，机械应用可能覆盖官方后来更新的子模块指针。

正确流程见 [`PROJECT_HANDOFF.md`](PROJECT_HANDOFF.md)：

1. 同步父仓库官方 `origin/main`。
2. 初始化并同步最新 `core/Clash.Meta`。
3. 检查官方最新 Clash.Meta 是否已经包含正确 JSON tag 和回归测试。
4. 若尚未包含，在最新子模块基线上重新应用 PR #2237 的等价补丁。
5. 在父仓库提交新的子模块指针。
6. 运行 Go、Flutter、Windows amd64 构建及 BrowserLeaks 验证。

如果官方已包含完全等价的修复，则保留官方实现，不再叠加重复提交；验收标准仍然是生成配置使用 `auto-detect-interface`，且回归测试和 DNS 实测通过。

## 7. Windows 便携模式最终行为

工具页在 Windows 上增加“便携模式”开关。启用后：

```text
程序目录\FlClashData
程序目录\FlClashData\.flclash-portable
```

- `.flclash-portable` 是下次启动判断便携模式的标记。
- 数据库、配置、订阅、偏好、图片缓存索引、缓存和临时文件均转到 `FlClashData`。
- 启用时先保存当前配置、停止系统代理和核心、关闭数据库，再复制数据并删除原 AppData 数据。
- 迁移失败时回滚到原目录并删除未完成的便携目录。
- 重启使用当前 `FlClash.exe --flclash-restart`，新进程延迟 1500ms 初始化；不经过 PowerShell、CMD 或 Explorer。
- 关闭行为按 ClashMi 逻辑处理：点击关闭只提示退出程序后手动删除 `FlClashData`，开关不会立即关闭，也不会自动回迁或删除用户数据。
- 默认应用数据目录仍是 `%APPDATA%\com.follow\clash`；便携运行时不应继续写入该目录。
- 单实例锁固定在系统临时目录中的 `FlClash.lock`，避免迁移过程中锁文件占用数据目录。
- 主动停止核心时抑制断连崩溃通知，避免出现误报的 `core done`。

## 8. 本轮全部源码与工程文件

### 8.1 便携模式实现

| 文件 | 作用 |
|---|---|
| `lib/common/portable.dart` | 便携标记、数据/缓存迁移、失败回滚。 |
| `lib/common/portable_preferences.dart` | Windows 下替换 PathProvider 和 SharedPreferences 路径，使插件也写入便携目录。 |
| `lib/common/path.dart` | 根据标记选择数据、缓存、临时目录；锁文件改用系统临时目录。 |
| `lib/common/preferences.dart` | SharedPreferences 改为延迟获取，确保便携路径提供器先完成注册。 |
| `lib/common/common.dart` | 导出便携模式模块。 |
| `lib/common/constant.dart` | 增加 `--flclash-restart` 参数常量。 |
| `lib/main.dart` | 启动早期注册便携路径实现，并处理延迟重启参数。 |
| `lib/providers/action.dart` | 保存状态、停止服务、迁移数据并通过 EXE 重启。 |
| `lib/core/service.dart` | 区分主动停核与异常断连，消除 `core done` 误报竞态。 |
| `lib/views/tools.dart` | 工具页便携模式开关、启用确认和关闭提示。 |
| `test/common/portable_test.dart` | 覆盖启用迁移、标记、失败回滚和关闭标记逻辑。 |

### 8.2 本地化

源 ARB：

```text
arb/intl_en.arb
arb/intl_zh_CN.arb
arb/intl_ja.arb
arb/intl_ru.arb
```

生成输出（由本地化生成器更新，不手工维护）：

```text
lib/l10n/l10n.dart
lib/l10n/intl/messages_all.dart
lib/l10n/intl/messages_en.dart
lib/l10n/intl/messages_zh_CN.dart
lib/l10n/intl/messages_ja.dart
lib/l10n/intl/messages_ru.dart
```

新增键：`portableMode`、`portableModeDesc`、`portableModeTip`、`portableModeDisableTip`。

### 8.3 依赖、环境与构建

| 文件 | 作用 |
|---|---|
| `pubspec.yaml` | 将 Windows PathProvider/SharedPreferences 及平台接口声明为直接依赖。 |
| `pubspec.lock` | 锁定对应依赖解析结果。 |
| `setup.dart` | 默认应用环境由 `pre` 改为 `stable`。 |
| `build_windows_amd64_zip.bat` | 一键构建 Windows amd64 ZIP；支持 stable/pre 参数和无参数交互选择。 |
| `CHAT_HANDOFF.md` | 当前实现、文件清单和验证交接。 |
| `PROJECT_HANDOFF.md` | 长期上游维护和回归检查手册。 |
| `AGENTS.md` | 要求后续维护者读取 `PROJECT_HANDOFF.md` 并保留 PR #2237。 |

`flutter pub get` 可能刷新以下 Flutter 工具生成文件；它们不是手写业务逻辑：

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugin_registrant.h
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugin_registrant.h
windows/flutter/generated_plugins.cmake
```

`analysis_options.yaml` 曾增加平台生成目录排除项，用于避免分析 Flutter 生成代码；提交前应按最终 diff 判断是否保留。`work/`、`build/`、`dist/` 属于验证或构建产物，不是源码改动。

### 8.4 PR #2237 文件

父仓库通过 `core/Clash.Meta` 子模块指针包含提交 `e6eb54620b18254b9d27f86b0b605b2097b1b3fe`，该提交修改：

```text
core/Clash.Meta/config/config.go
core/Clash.Meta/config/raw_tun_test.go
```

父仓库记录：官方基线 `7c831855efedceb1a72bd0b4c18da026593d0853`、PR 提交 `e55e92c58073a4bc7278f1fd9cdcfacb4619a7ff`、本地合并提交 `d3702daf869aa08a41a1079b693659e27ef97b85`。

## 9. 一键构建 stable/pre

```powershell
# 正式版：env.json 写入 APP_ENV=stable
.\build_windows_amd64_zip.bat stable

# 预发布/测试版：env.json 写入 APP_ENV=pre
.\build_windows_amd64_zip.bat pre

# 双击或无参数运行时显示 1/2 选择菜单
.\build_windows_amd64_zip.bat
```

输出约定：

```text
stable: dist\FlClash-<VERSION>-windows-amd64.zip
pre:    dist\FlClash-<VERSION>-pre-windows-amd64.zip
```

每个 ZIP 同时生成 `<ZIP>.sha256.txt`。脚本只接受 `stable` 和 `pre`，并把选择写入：

```json
{"APP_ENV":"stable 或 pre","CORE_SHA256":"<CORE_SHA256>"}
```
## 10. 2026-08-13 最终脚本验证

两种环境均已实际执行完整 Windows amd64 Release 构建，ZIP 可读取且内含 FlClash.exe；仓库最终 nv.json 保持 stable：

`	ext
stable ZIP: D:\Codex\FlClash\dist\FlClash-0.8.94-windows-amd64.zip
stable SHA256: 3D1072706B26F01DCE5269D8D5C20A5A21A6080C49465DBB90D03D0ADE07888F
pre ZIP: D:\Codex\FlClash\dist\FlClash-0.8.94-pre-windows-amd64.zip
pre SHA256: 79B72B3005BE5BDCDD256B1320B6C70F5E2785415A7BB71ADBC6D33669D5A72B
`

便携模式专项测试：lutter test test\common\portable_test.dart --reporter expanded，4 项全部通过。
