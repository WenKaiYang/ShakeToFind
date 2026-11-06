# 构建安装包

## 目录结构

```
ShakeToFind\
├─ ShakeToFind.ahk       主脚本
├─ README.md             用户说明
├─ installer\
│  ├─ ShakeToFind.iss    Inno Setup 脚本
│  ├─ BUILD.md           本文件
│  └─ payload\           构建依赖（第三方运行时，不提交到仓库）
│     ├─ AutoHotkey64.exe / AutoHotkey32.exe
│     ├─ license.txt     AutoHotkey 许可
│     └─ stop-running.cmd  卸载/升级前结束正在运行的实例
└─ dist\                 构建产物（不提交到仓库）
```

## 首次准备

构建机需要安装 [Inno Setup 6](https://jrsoftware.org/isdl.php)。

把 AutoHotkey v2 便携版放进 `installer\payload\`：

1. 下载 <https://www.autohotkey.com/download/ahk-v2.zip>
2. 解压后复制 `AutoHotkey64.exe`、`AutoHotkey32.exe`、`license.txt` 到 `installer\payload\`
3. `stop-running.cmd` 已包含在仓库中

## 重新打包

1. 修改根目录的 `ShakeToFind.ahk` 或 `README.md`（`.iss` 直接引用这两个文件，无需复制）。
2. 在 `installer` 目录下运行编译器：

```powershell
cd installer
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" "ShakeToFind.iss"
```

也可以双击 `ShakeToFind.iss` 用 Inno Setup 图形界面编译。

3. 产物在 `dist\ShakeToFind-Setup-<版本>.exe`。版本号在 `.iss` 顶部的 `MyAppVersion` 修改。

## 安装包行为

- 安装到 `%LOCALAPPDATA%\Programs\ShakeToFind`，当前用户权限，无需管理员。
- 默认创建开机自启快捷方式（安装向导「附加任务」里可取消）。
- 开始菜单创建启动和卸载快捷方式。
- 卸载或覆盖安装前，会运行 `stop-running.cmd` 结束正在运行的 ShakeToFind 实例。
- 卸载会删除快捷方式和安装目录；`trigger.log` 等调试文件也会清理。

## 注意

- 安装包未做代码签名，其他电脑首次运行可能触发 SmartScreen 提示：点「更多信息」→「仍要运行」。
- 安装包自带便携版 AutoHotkey v2，目标电脑无需安装任何依赖。
