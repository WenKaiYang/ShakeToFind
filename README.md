# ShakeToFind —— 快速移动就放大指针（越快越大）

Windows 版「找鼠标」工具：鼠标移动速度超过正常速度后，指针开始放大；**速度越快放大倍数越大**，慢下来按速度连续缩小，最终恢复原大小。

## 效果

- 慢速移动 / 停住：正常大小，不干扰。
- 速度超过 2500 像素/秒：开始放大（约 1.8 倍）。
- 达到 6000 像素/秒：放大到最大 6 倍。
- 中间速度按比例连续变化，快变大、慢变小，平滑过渡。
- 放大的光标实时跟随鼠标；显示期间每 5ms 更新一次，比平时更跟手。
- 跟随过程中会自动同步当前光标形状（箭头 / I 型 / 手型）。
- 覆盖层鼠标穿透、不抢焦点，不影响点击。

## 与 macOS 的对比

| 维度 | macOS | 本工具 |
| --- | --- | --- |
| 触发方式 | 摇一摇 | 按移动速度（本工具设计） |
| 放大规则 | 固定倍数 | 随速度连续变化（本工具设计） |
| 跟随 | 系统直接渲染，零延迟 | 覆盖层跟随，约 5ms 更新（仍有极短延迟） |
| 渲染 | 系统级平滑缩放、真透明 | GDI 位图放大 + HALFTONE 平滑 + 颜色键透明 |
| 光标形状 | 永远是当前真实光标 | 已实时同步 |
| 热点 / 点击穿透 | 一致 | 一致 |

macOS 是在系统层面直接放大光标本身，Windows 没有对应接口，因此这里用「穿透覆盖层 + 实时跟随」来逼近；缩放边缘为位图放大，仍不如系统渲染锐利。

## 安装 / 卸载

- 安装：运行 `dist\ShakeToFind-Setup-<版本>.exe`（构建方法见 `installer/BUILD.md`），安装到 `%LOCALAPPDATA%\Programs\ShakeToFind`，无需管理员权限；默认勾选「开机自动启动」。
- 卸载：Windows 设置 → 应用 → ShakeToFind → 卸载（或开始菜单里的 Uninstall ShakeToFind）。
- 迁移：把安装包复制到其他电脑直接运行即可。

## 使用

- 安装包默认设置开机自启：`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ShakeToFind.lnk`
- 退出：托盘区 AutoHotkey 图标（H）右键 → Exit。
- 修改脚本后：托盘图标右键 → Reload。
- 预览放大效果（安装版）：

```powershell
& "$env:LOCALAPPDATA\Programs\ShakeToFind\AutoHotkey64.exe" "$env:LOCALAPPDATA\Programs\ShakeToFind\ShakeToFind.ahk" --demo
```

## 调整灵敏度 / 外观

用记事本打开 `ShakeToFind.ahk`，改顶部的参数并保存，然后 Reload：

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `SPEED_WINDOW` | 120 | 测速窗口（毫秒） |
| `SPEED_MIN` | 2500 | 超过该速度（像素/秒）才开始放大，调小更灵敏 |
| `SPEED_FULL` | 6000 | 达到该速度时放大到最大倍数，调小更易到最大 |
| `SCALE_MIN` | 1.8 | 刚超过阈值时的放大倍数 |
| `SCALE_MAX` | 6.0 | 最大放大倍数 |
| `SCALE_SMOOTH` | 0.35 | 大小变化平滑系数（0~1，越大越跟手） |
| `DEBUG` | false | true 时把速度/倍数记录到 `trigger.log` |

> 觉得太容易触发就调高 `SPEED_MIN`（如 3500）；觉得甩得很快还不出现就调低（如 1500）。
> 想更夸张就把 `SCALE_MAX` 调到 8，嫌太大调到 4。

## 项目结构

- `ShakeToFind.ahk` —— 主脚本（源码）
- `installer\` —— Inno Setup 打包脚本与构建说明
- `dist\` —— 本地构建产物（不提交到仓库）

安装后位于 `%LOCALAPPDATA%\Programs\ShakeToFind\`，包含脚本、便携版 AutoHotkey v2 和 `license.txt`。

## 开发 / 构建

安装包使用 Inno Setup 6 构建，具体步骤见 `installer/BUILD.md`。

## 第三方组件

- AutoHotkey v2（GPLv2），许可文本随安装包分发（`license.txt`）。

## 关闭开机自启

删除启动文件夹里的 `ShakeToFind.lnk` 即可：

```powershell
Remove-Item "$env:APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ShakeToFind.lnk"
```
