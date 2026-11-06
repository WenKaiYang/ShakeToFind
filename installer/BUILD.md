# 构建安装包

## 目录结构

```
ShakeToFind\
├─ ShakeToFind.ahk       主脚本
├─ README.md             用户说明
├─ build.cmd             一键打包命令
├─ assets\
│  └─ icon\              品牌图标（安装包 / 快捷方式 / 托盘共用）
│     ├─ build_icon.py   图标生成脚本（Python + Pillow）
│     ├─ ShakeToFind.ico 多尺寸图标（16–256）
│     └─ preview.png     设计预览图
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

品牌图标 `assets\icon\ShakeToFind.ico` 已随仓库提供，正常情况下无需处理。只有想改图标时才需要 Python + Pillow 重新生成（见下文「图标」）。

## 重新打包

1. 修改根目录的 `ShakeToFind.ahk` 或 `README.md`（`.iss` 直接引用这两个文件，无需复制）。
2. 在项目根目录执行打包命令：

```powershell
.\build.cmd            # 使用 .iss 里 MyAppVersion 的默认版本
.\build.cmd 1.0.1      # 指定版本号，不必改 .iss
```

`build.cmd` 会自动查找 Inno Setup 6（依次检查 `%LOCALAPPDATA%\Programs\Inno Setup 6`、Program Files 和 PATH），检查 `payload\` 里的运行时文件和 `assets\icon\ShakeToFind.ico` 是否存在，然后调用 `ISCC.exe` 编译。

3. 产物在 `dist\ShakeToFind-Setup-<版本>.exe`。不传版本号时，版本号取 `.iss` 顶部的 `MyAppVersion`。

> PowerShell 中要写 `.\build.cmd`；cmd 中直接输入 `build.cmd` 即可。也可以用 Inno Setup 图形界面打开 `ShakeToFind.iss` 手动编译。

## 安装包行为

- 安装到 `%LOCALAPPDATA%\Programs\ShakeToFind`，当前用户权限，无需管理员。
- 默认创建开机自启快捷方式（安装向导「附加任务」里可取消）。
- 开始菜单创建启动和卸载快捷方式。
- 安装包、快捷方式、卸载项和托盘图标共用同一枚品牌图标，安装时会把 `ShakeToFind.ico` 一并装进安装目录。
- 卸载或覆盖安装前，会运行 `stop-running.cmd` 结束正在运行的 ShakeToFind 实例。
- 卸载会删除快捷方式和安装目录；`trigger.log` 等调试文件也会清理。

## 图标

图标是「放大镜 + 放大的指针」，全部由 `assets\icon\build_icon.py` 生成：

- `assets\icon\ShakeToFind.ico` —— 16 / 20 / 24 / 32 / 40 / 48 / 64 / 96 / 128 / 256 共 10 个尺寸。24px 及以下使用单独绘制的简化版本（镜圈更细、指针留白更多），保证托盘小图标清楚。
- `assets\icon\preview.png` —— 设计预览图（浅色 / 深色背景、尺寸阶梯、小尺寸像素检查、配色）。

安装包里的使用位置：`ShakeToFind.iss` 的 `SetupIconFile`（安装包 exe 图标）、`UninstallDisplayIcon`（卸载项图标）、`[Icons]` 里的 `IconFilename`（开始菜单 / 开机启动 / 卸载快捷方式）；程序运行后由 `ShakeToFind.ahk` 里的 `TraySetIcon` 设置托盘图标。

改图标流程（需要 Python + Pillow）：

```powershell
python assets\icon\build_icon.py   # 重新生成 .ico 和 preview.png
.\build.cmd                        # 重新打包
```

不要手工修改 `.ico` 文件；颜色、形状、尺寸都改 `build_icon.py`，再重新生成。

## 注意

- 安装包未做代码签名，其他电脑首次运行可能触发 SmartScreen 提示：点「更多信息」→「仍要运行」。
- 安装包自带便携版 AutoHotkey v2，目标电脑无需安装任何依赖。
