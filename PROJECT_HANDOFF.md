# FlClash 项目交接与上游更新维护手册

> 核心维护策略：**官方上游优先，PR #2237 修复必须持续存在。**
> 每次上游更新都执行本手册；不能只看提交是否还在，必须验证行为是否仍然正确。

## 1. 长期维护不变量

每个交付版本必须同时满足：

1. 父仓库基于当时最新的 FlClash 官方 `origin/main`。
2. `core/Clash.Meta` 基于 FlClash 官方在该版本指定的最新子模块状态。
3. `RawTun.AutoDetectInterface` 的 YAML 和 JSON 字段名均为 `auto-detect-interface`。
4. 运行配置不得出现 `AutoDetectInterface`。
5. `tun.enable: true`、`stack: gvisor` 时，FlClash TUN 网卡和路由真实建立。
6. BrowserLeaks 独立测试时不得混入 ClashMi 或其他代理客户端的进程、TUN、系统代理或 DNS。
7. Windows amd64 ZIP 内核心必须与完成 BrowserLeaks 实测的核心哈希一致。

## 2. PR #2237 追踪信息

```text
FlClash PR: #2237
父仓库 PR 提交: e55e92c58073a4bc7278f1fd9cdcfacb4619a7ff
Clash.Meta 修复提交: e6eb54620b18254b9d27f86b0b605b2097b1b3fe
```

修复内容：

```diff
- AutoDetectInterface bool `yaml:"auto-detect-interface"`
+ AutoDetectInterface bool `yaml:"auto-detect-interface" json:"auto-detect-interface"`
```

回归测试：

```text
core/Clash.Meta/config/raw_tun_test.go
TestRawTunJSONUsesMihomoAutoDetectInterfaceKey
```

## 3. 为什么不能每次直接 cherry-pick 父仓库 PR 提交

父仓库提交 `e55e92c` 的内容本质上是把子模块指针固定为：

```text
e6eb54620b18254b9d27f86b0b605b2097b1b3fe
```

未来官方更新后，`origin/main` 很可能已把 `core/Clash.Meta` 指向更晚的提交。此时直接 cherry-pick `e55e92c`，可能让子模块退回旧版本，丢失上游核心更新。

因此，“每次上游更新都合并这个 PR”的准确含义是：

> 每次基于最新上游重新确认并保留 PR #2237 的**修复语义**，而不是无条件复用旧子模块指针。

## 4. 每次同步上游的标准流程

### 4.1 保存当前状态

先确认没有遗漏的源码修改：

```powershell
Set-Location 'D:\Codex\FlClash'
git status --short --branch
git submodule status
```

构建目录如 `work/`、`build/` 不应混入源码提交。若存在真正需要保留的修改，先提交到独立分支。

### 4.2 获取父仓库官方更新

```powershell
git fetch origin --prune
git switch main
git pull --ff-only origin main
git submodule update --init --recursive
```

为新一轮维护创建分支，分支名可带日期或目标版本：

```powershell
git switch -c 'codex/upstream-pr2237-YYYYMMDD'
```

如果是在已有维护分支上更新，优先把维护分支 rebase 到最新 `origin/main`，并在冲突时保留最新上游子模块指针：

```powershell
git switch codex/merge-pr-2237
git rebase origin/main
```

发生 `core/Clash.Meta` 指针冲突时，不要直接选择旧 PR 一侧；先选择官方最新指针，再按下面步骤检查或重放修复。

### 4.3 检查官方是否已吸收修复

```powershell
git -C core/Clash.Meta grep -n 'AutoDetectInterface bool' -- config/config.go
git -C core/Clash.Meta grep -n 'TestRawTunJSONUsesMihomoAutoDetectInterfaceKey' -- config
```

合格实现至少应包含：

```go
AutoDetectInterface bool `yaml:"auto-detect-interface" json:"auto-detect-interface"`
```

也可以直接运行聚焦测试；若官方更名了测试，应运行覆盖相同行为的新测试：

```powershell
Push-Location core/Clash.Meta
go test ./config -run TestRawTunJSONUsesMihomoAutoDetectInterfaceKey -count=1
Pop-Location
```

判断分两种情况：

#### 情况 A：官方已包含等价修复

- 不重复 cherry-pick `e6eb5462`。
- 保留官方最新子模块指针。
- 确认测试覆盖 JSON 字段名；没有测试时可补充等价回归测试。
- 继续执行第 5、6、7 节的完整验证。

#### 情况 B：官方仍未包含修复

进入子模块，在最新上游核心上重新应用修复。

优先尝试 cherry-pick 子模块里的实际修复提交，而不是父仓库的指针提交：

```powershell
Push-Location core/Clash.Meta
git switch -c 'flclash-pr2237-YYYYMMDD'
git cherry-pick e6eb54620b18254b9d27f86b0b605b2097b1b3fe
Pop-Location
```

如果 cherry-pick 因上游文件演进产生冲突，则手工保留等价修改：

```go
AutoDetectInterface bool `yaml:"auto-detect-interface" json:"auto-detect-interface"`
```

并保留或重写覆盖同一行为的测试。解决冲突后：

```powershell
Push-Location core/Clash.Meta
git add config/config.go config/raw_tun_test.go
git cherry-pick --continue
Pop-Location
```

随后在父仓库记录新的子模块指针：

```powershell
git add core/Clash.Meta
git commit -m 'fix: retain PR #2237 TUN JSON serialization'
```

### 4.4 子模块提交的可获取性

父仓库只能保存子模块提交哈希。交付或推送维护分支前，必须保证新的 Clash.Meta 修复提交存在于团队可访问的远端分支，否则其他机器执行 `git submodule update` 会失败。

检查：

```powershell
git -C core/Clash.Meta status --short --branch
git -C core/Clash.Meta log -1 --oneline
git submodule status
```

若只是本机自用构建，可以保留本地提交；若要共享父仓库分支，应先将子模块维护分支推送到可访问远端，再推送父仓库分支。

## 5. 必做测试

### 5.1 Clash.Meta 聚焦回归测试

```powershell
Push-Location core/Clash.Meta
go test ./config -run TestRawTunJSONUsesMihomoAutoDetectInterfaceKey -count=1
Pop-Location
```

### 5.2 Flutter 验证

遵循仓库规则，使用 `flutter test`，不要使用 `dart test`：

```powershell
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded
```

若项目锁定的 Flutter/Dart 与依赖约束不一致，应选择满足当前 `pubspec.yaml` 的 SDK，并在交付记录中写明实际版本。

## 6. Windows amd64 构建

标准入口优先使用：

```powershell
dart setup.dart windows
```

如果 `flutter_distributor` 与当前 Flutter 版本不兼容，可使用已验证过的 Release 构建方式：

```powershell
flutter build windows --release `
  --dart-define-from-file=env.json `
  --build-name=<VERSION> `
  --build-number=<BUILD_NUMBER>
```

构建目录通常为：

```text
build\windows\x64\runner\Release
```

压缩时必须包含 Release 目录中的全部运行文件，不能只交付 `FlClash.exe`。

## 7. BrowserLeaks 独立验证

### 7.1 排除其他代理干扰

测试前检查：

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -match 'clash|mihomo' } |
  Select-Object Name, ProcessId, ExecutablePath
```

停止 ClashMi 和其他代理客户端后，结果中应只保留当前待测的：

```text
FlClash.exe
FlClashCore.exe
FlClashHelperService.exe
```

### 7.2 确认最终运行配置

检查：

```text
C:\Users\Rulio\AppData\Roaming\com.follow\clash\config.yaml
```

要求：

```yaml
tun:
  enable: true
  stack: "gvisor"
  dns-hijack:
    - "any:53"
  auto-route: true
  auto-detect-interface: true
```

必须确认不存在：

```yaml
AutoDetectInterface: true
```

### 7.3 确认 TUN 真实建立

```powershell
Get-NetAdapter -IncludeHidden |
  Where-Object {
    $_.Name -match 'FlClash' -or
    $_.InterfaceDescription -match 'FlClash|Meta Tunnel'
  }

Get-NetRoute |
  Where-Object { $_.InterfaceAlias -match 'FlClash' }

Get-DnsClientServerAddress -AddressFamily IPv4
```

不能仅凭 `config.yaml` 写着 `enable: true` 就判定 TUN 已生效；必须看到网卡为 `Up` 且路由已建立。

### 7.4 执行 BrowserLeaks

访问：

```text
https://browserleaks.com/dns
```

保存以下证据：

- 出口 IP、ISP、位置。
- DNS 服务器数量、ISP、位置。
- 页面截图。
- 页面文本或结构化结果。
- 测试时运行的代理进程清单。
- TUN 网卡、路由和运行配置片段。

判断 DNS 泄漏时，应结合用户选择的节点和 DNS 配置判断。至少不能出现本地 ISP DNS、路由器 DNS 对外解析结果或与代理出口明显无关的本地运营商解析器。

## 8. 打包与哈希一致性

生成 ZIP 后：

```powershell
Get-FileHash -Algorithm SHA256 '<ZIP_PATH>'
Get-FileHash -Algorithm SHA256 '<TESTED_INSTALL>\FlClashCore.exe'
```

重新解压 ZIP 并计算其中核心哈希：

```powershell
Expand-Archive -LiteralPath '<ZIP_PATH>' -DestinationPath '<VERIFY_DIR>' -Force
Get-FileHash -Algorithm SHA256 '<VERIFY_DIR>\...\FlClashCore.exe'
```

验收要求：

```text
ZIP 内 FlClashCore.exe SHA256 == BrowserLeaks 实测安装目录中的 FlClashCore.exe SHA256
```

同时生成：

- Windows amd64 ZIP。
- ZIP 的 `.sha256.txt`。
- BrowserLeaks 截图。
- BrowserLeaks 文本结果。
- 构建及验证记录。

## 9. 每轮更新后的提交审计

```powershell
git log --oneline --decorate --graph -10
git diff --submodule=log origin/main...HEAD
git status --short --branch
git submodule status
```

期望状态：

- 相对最新 `origin/main`，只有保留 PR #2237 所必需的修改。
- 若官方已经吸收修复，则维护分支可不再有额外修复差异。
- 不提交 `work/`、`build/`、临时 SDK、解压验证目录或本机输出文件。

## 10. Windows 便携模式长期维护

### 10.1 不变量

- Windows 工具页保留便携模式入口。
- 标记固定为 `<FlClash.exe目录>\FlClashData\.flclash-portable`。
- 标记存在时，应用支持目录、缓存目录、临时目录和 SharedPreferences 全部定位到 `FlClashData` 内。
- 启用迁移成功后删除 `%APPDATA%\com.follow\clash` 及原应用缓存；迁移失败必须回滚。
- 单实例锁位于系统临时目录，不能放入待迁移的数据目录。
- 重启直接执行当前 EXE 并携带 `--flclash-restart`，不得借助可能打开目录窗口的 shell 命令。
- 关闭按钮遵循 ClashMi 行为：仅提示退出后手动删除 `FlClashData`，不自动回迁、不自动删除、不开启半迁移状态。
- 主动停止核心不得当作崩溃显示 `core done`。

### 10.2 上游同步后重点检查文件

```text
lib/common/portable.dart
lib/common/portable_preferences.dart
lib/common/path.dart
lib/common/preferences.dart
lib/common/common.dart
lib/common/constant.dart
lib/main.dart
lib/providers/action.dart
lib/core/service.dart
lib/views/tools.dart
test/common/portable_test.dart
```

本地化与依赖文件：

```text
arb/intl_en.arb
arb/intl_zh_CN.arb
arb/intl_ja.arb
arb/intl_ru.arb
lib/l10n/l10n.dart
lib/l10n/intl/messages_all.dart
lib/l10n/intl/messages_en.dart
lib/l10n/intl/messages_zh_CN.dart
lib/l10n/intl/messages_ja.dart
lib/l10n/intl/messages_ru.dart
pubspec.yaml
pubspec.lock
```

### 10.3 便携模式回归

```powershell
flutter test test\common\portable_test.dart --reporter expanded
```

还需在 Windows Release 包中人工验证：

1. 从默认模式启用后，数据迁入 `FlClashData`，标记生成，程序和核心自动重启。
2. `%APPDATA%\com.follow\clash` 不再被重新生成或更新。
3. 程序目录改变后，仍以新 EXE 自身路径启动并使用新目录旁的 `FlClashData`。
4. 点击关闭只出现手动删除提示，开关保持开启。
5. 正常退出后不残留异常 FlClash/核心进程，不弹 `core done`，不打开 Explorer 目录窗口。

## 11. stable/pre 一键构建

`build_windows_amd64_zip.bat` 同时支持命令行和双击交互：

```powershell
.\build_windows_amd64_zip.bat stable
.\build_windows_amd64_zip.bat pre
.\build_windows_amd64_zip.bat
```

- `stable` 写入 `{"APP_ENV":"stable", ...}`，输出 `dist\FlClash-<VERSION>-windows-amd64.zip`。
- `pre` 写入 `{"APP_ENV":"pre", ...}`，输出 `dist\FlClash-<VERSION>-pre-windows-amd64.zip`。
- 无参数时选择 `1` 为 stable，选择 `2` 为 pre，直接回车默认 stable。
- 每个 ZIP 旁生成 `.sha256.txt`，参数值只允许 `stable` 或 `pre`。
- `setup.dart` 的默认环境保持 `stable`，上游同步时需检查它没有恢复为 `pre`。

构建后检查：

```powershell
Get-Content .\env.json
Get-FileHash -Algorithm SHA256 .\dist\FlClash-<VERSION>-windows-amd64.zip
Get-FileHash -Algorithm SHA256 .\dist\FlClash-<VERSION>-pre-windows-amd64.zip
```

## 12. 完整改动文件索引

便携模式、构建环境和交接文档涉及的文件：

```text
AGENTS.md
CHAT_HANDOFF.md
PROJECT_HANDOFF.md
analysis_options.yaml
arb/intl_en.arb
arb/intl_ja.arb
arb/intl_ru.arb
arb/intl_zh_CN.arb
build_windows_amd64_zip.bat
lib/common/common.dart
lib/common/constant.dart
lib/common/path.dart
lib/common/portable.dart
lib/common/portable_preferences.dart
lib/common/preferences.dart
lib/core/service.dart
lib/l10n/l10n.dart
lib/l10n/intl/messages_all.dart
lib/l10n/intl/messages_en.dart
lib/l10n/intl/messages_ja.dart
lib/l10n/intl/messages_ru.dart
lib/l10n/intl/messages_zh_CN.dart
lib/main.dart
lib/providers/action.dart
lib/views/tools.dart
pubspec.lock
pubspec.yaml
setup.dart
test/common/portable_test.dart
```

Flutter 工具运行时可能刷新但不含手写业务逻辑的生成文件：

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugin_registrant.h
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugin_registrant.h
windows/flutter/generated_plugins.cmake
```

PR #2237 位于 `core/Clash.Meta` 子模块的实际源码文件：

```text
core/Clash.Meta/config/config.go
core/Clash.Meta/config/raw_tun_test.go
```

子模块修复提交为 `e6eb54620b18254b9d27f86b0b605b2097b1b3fe`；父仓库 PR 提交为 `e55e92c58073a4bc7278f1fd9cdcfacb4619a7ff`，本地合并提交为 `d3702daf869aa08a41a1079b693659e27ef97b85`。`work/`、`build/`、`dist/` 是构建/验证产物，不纳入源码文件列表。

## 13. 每轮交付检查表

- [ ] 已获取最新 FlClash `origin/main`。
- [ ] 已使用官方最新的 Clash.Meta 子模块基线。
- [ ] 已检查官方是否吸收 PR #2237 的等价修复。
- [ ] 未吸收时，已在最新子模块基线上重新应用修复。
- [ ] `auto-detect-interface` JSON 序列化测试通过。
- [ ] `flutter analyze --no-fatal-infos` 通过或仅有已记录的非致命信息。
- [ ] `flutter test --reporter expanded` 通过。
- [ ] Windows amd64 Release 构建完成。
- [ ] 测试时已停止 ClashMi 和其他代理客户端。
- [ ] FlClash gVisor TUN 网卡及路由真实建立。
- [ ] 最终运行配置使用 `auto-detect-interface: true`。
- [ ] BrowserLeaks 未显示本地运营商 DNS。
- [ ] ZIP 内核心与实测核心 SHA256 一致。
- [ ] 已交付 ZIP、SHA256 和验证记录。
- [ ] 便携模式迁移、EXE 自重启、关闭提示及 AppData 无回写均通过。
- [ ] `setup.dart` 默认环境仍为 stable。
- [ ] stable/pre 两种脚本参数均写入正确 `APP_ENV` 并生成各自 ZIP 与 SHA256。
## 14. 2026-08-13 已验证构建记录

`	ext
stable: D:\Codex\FlClash\dist\FlClash-0.8.94-windows-amd64.zip
SHA256: 3D1072706B26F01DCE5269D8D5C20A5A21A6080C49465DBB90D03D0ADE07888F
pre: D:\Codex\FlClash\dist\FlClash-0.8.94-pre-windows-amd64.zip
SHA256: 79B72B3005BE5BDCDD256B1320B6C70F5E2785415A7BB71ADBC6D33669D5A72B
`

两种构建均完成，ZIP 均包含 FlClash.exe，各自 .sha256.txt 与重新计算结果一致；最终 nv.json 为 APP_ENV=stable。便携模式专项测试 4 项通过。
