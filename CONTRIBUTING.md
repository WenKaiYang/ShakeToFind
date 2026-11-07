# 贡献指南

感谢你考虑为 ShakeToFind 做贡献。这个项目很小，欢迎任何形式的参与：报 bug、提改进想法、改 README、翻译、提 PR。

## 快速开始

```powershell
git clone https://github.com/WenKaiYang/ShakeToFind.git
cd ShakeToFind
.\build.cmd          # 需要 Inno Setup 6 + installer\payload 里的 AutoHotkey v2
```

改完记得重新生成图标（如果你动了 `assets\icon\build_icon.py`）：

```powershell
python assets\icon\build_icon.py
```

## 目录约定

| 路径 | 说明 |
| --- | --- |
| `ShakeToFind.ahk` | 主脚本，唯一的功能实现文件 |
| `assets\icon\build_icon.py` | 图标生成脚本，**不要手改 `.ico`** |
| `installer\ShakeToFind.iss` | Inno Setup 打包脚本 |
| `installer\BUILD.md` | 构建环境说明 |

## 代码风格

- 主脚本是 AutoHotkey **v2** 语法（注意 `FileExist` 不是 `FileExists`）。
- 缩进用 4 个空格，注释用中文，与现有代码保持一致。
- 参数集中在 `ShakeToFind.ahk` 顶部，改参数不要散落到各处。
- 换行符用 CRLF（仓库 `core.autocrlf=true`）。

## 提 Issue

请尽量附上：

- Windows 版本（`winver` 的输出）。
- 触发问题的操作步骤。
- 如与放大效果有关，附上 `trigger.log`（把 `ShakeToFind.ahk` 里的 `DEBUG` 改成 `true` 后复现，日志在脚本同目录）。

## 提 PR

1. 从 `main` 切一个分支：`git checkout -b feature/xxx`。
2. 改动后本地跑一次 `.\build.cmd` 确认能编译。
3. 提交信息用中文，描述「改了什么」和「为什么」。
4. PR 描述里写清楚验证方式；有截图更好。

## 不要做的事

- 不要提交 `dist\`、`installer\payload\AutoHotkey*.exe`（第三方运行时，已在 `.gitignore` 里）。
- 不要手改 `assets\icon\ShakeToFind.ico`，改生成脚本。
- 不要把 `trigger.log` 之类的运行日志提交进来。
