#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
;  ShakeToFind —— 快速移动鼠标时放大指针：越快越大，慢下来变小
;  放大后的指针「替换」真实指针：屏幕上只剩放大的那一个，看不到小光标
; ============================================================

; ==================== 可调参数 ====================
global SPEED_WINDOW := 120     ; 测速窗口（毫秒）
global SPEED_MIN    := 2500    ; 超过该速度（像素/秒）才开始放大，调小更灵敏
global SPEED_FULL   := 6000    ; 达到该速度时放大到 SCALE_MAX，调小更易到最大
global SCALE_MIN    := 1.8     ; 刚超过 SPEED_MIN 时的放大倍数
global SCALE_MAX    := 6.0     ; 最大放大倍数
global SCALE_SMOOTH := 0.35    ; 大小变化平滑系数（0~1，越大越跟手）
global DEBUG        := false   ; true 时把速度/倍数记录到 trigger.log

; 放大显示期间的采样间隔更小，跟随更跟手
global TIMER_IDLE   := 10
global TIMER_ACTIVE := 5

; ==================== 运行状态 ====================
global gLastX := 0, gLastY := 0
global gSamples := []          ; 最近的位置采样 {t, x, y}
global gOverlay := 0           ; 放大光标窗口（Gui 对象），0 表示未显示
global gScale := 1.0           ; 当前显示倍数
global gDrawnScale := 0        ; 已绘制的倍数
global gMargin := 0            ; 窗口内热点位置的边距
global gWinW := 0, gWinH := 0
global gHdcWin := 0, gMemDC := 0, gHbm := 0, gOldBmp := 0, gKeyBrush := 0
global gHCursor := 0, gHx := 0, gHy := 0, gCw := 0, gCh := 0
global gTimerFast := false
global gIconBig := 0, gIconSmall := 0   ; 品牌图标句柄（窗口图标用）

; ==================== 命令行参数 ====================
; --demo       预览放大效果
; --lang xx    临时指定界面语言（auto / zh / en），只影响本次运行，不写入配置文件
global gCmdDemo := false, gCmdLang := ""
for i, arg in A_Args {
    if (arg = "--demo")
        gCmdDemo := true
    else if (arg = "--lang" && i < A_Args.Length) {
        v := StrLower(A_Args[i + 1])
        if (v = "auto" || v = "zh" || v = "en")
            gCmdLang := v
    }
}

; ==================== 界面语言 ====================
; 默认跟随系统语言；托盘「语言」子菜单可切换，选择保存在脚本目录的 ShakeToFind.ini
global gLang := ""              ; 当前生效语言：zh / en
global gLangPref := "auto"      ; 用户偏好：auto / zh / en
global gLangMenu := 0           ; 「语言」子菜单（Menu 对象）
global gLangMenuItem := ""      ; 「语言」菜单项的当前文本
global gMenuLabels := Map()     ; 标准菜单项 key -> 当前显示文本

; 图标：托盘、任务栏按钮、Alt+Tab、窗口预览统一用同一枚品牌图标（与安装包 / 快捷方式同一枚）
iconFile := FindIconFile()
if (iconFile)
    TraySetIcon(iconFile)

; 脚本主窗口（托盘菜单「打开」时显示）默认是 AutoHotkey 的绿色 H 图标，
; 这里也换成品牌图标，任务栏 / Alt+Tab / 窗口预览里的图标才一致
LoadWindowIcons()
ApplyWindowIcon(A_ScriptHwnd)

CoordMode("Mouse", "Screen")
MouseGetPos(&gLastX, &gLastY)

; 演示模式（预览放大效果）：
; AutoHotkey64.exe ShakeToFind.ahk --demo
if (gCmdDemo) {
    RunDemo()
    ExitApp
}

; 应用界面语言：--lang 优先，其次读配置；auto 时跟随系统
ApplyLanguage(gCmdLang != "" ? gCmdLang : ReadLangPref())

SetTimer(SampleMouse, TIMER_IDLE)

; ==================== 测速、缩放、跟随 ====================
SampleMouse() {
    global gLastX, gLastY, gSamples, gOverlay, gScale, gDrawnScale, gHCursor

    MouseGetPos(&x, &y)
    now := A_TickCount

    if (x != gLastX || y != gLastY) {
        gLastX := x
        gLastY := y
        gSamples.Push({t: now, x: x, y: y})
    }
    while (gSamples.Length && now - gSamples[1].t > SPEED_WINDOW)
        gSamples.RemoveAt(1)

    ; 窗口内平均速度（像素/秒）
    dist := 0
    if (gSamples.Length > 1) {
        loop gSamples.Length - 1 {
            a := gSamples[A_Index]
            b := gSamples[A_Index + 1]
            ddx := b.x - a.x
            ddy := b.y - a.y
            dist += Sqrt(ddx * ddx + ddy * ddy)
        }
    }
    span := gSamples.Length > 1 ? gSamples[gSamples.Length].t - gSamples[1].t : 0
    speed := span > 0 ? dist * 1000 / span : 0

    ; 速度 -> 目标倍数（低于 SPEED_MIN 时为 1.0，即恢复原大小）
    target := 1.0
    if (speed >= SPEED_MIN) {
        target := SCALE_MIN + (speed - SPEED_MIN) / (SPEED_FULL - SPEED_MIN) * (SCALE_MAX - SCALE_MIN)
        if (target > SCALE_MAX)
            target := SCALE_MAX
    }

    if (DEBUG && speed > 200)
        FileAppend(FormatTime() " speed=" Round(speed) " target=" Round(target, 2) "`n", A_ScriptDir "\trigger.log")

    if (!gOverlay) {
        if (target <= 1.0)
            return
        CreateOverlay(x, y)
        if (!gOverlay)
            return
        EnableFastTimer()
    }

    ; 显示期间若光标形状变了（箭头 / I 型 / 手型），实时换图
    ; 注意：形状变了必须重画，否则 1:1 遮盖层仍是旧形状，系统新光标会露出来
    ci := Buffer(A_PtrSize = 8 ? 24 : 20, 0)
    NumPut("UInt", ci.Size, ci, 0)
    if (DllCall("GetCursorInfo", "Ptr", ci)) {
        hCur := NumGet(ci, 8, "Ptr")
        if (hCur && hCur != gHCursor) {
            UpdateCursorShape(hCur)
            gDrawnScale := 0
        }
    }

    ; 平滑过渡，避免倍数跳变
    gScale += (target - gScale) * SCALE_SMOOTH

    if (target <= 1.0 && gScale < 1.05) {
        HideOverlay()
        DisableFastTimer()
        return
    }

    ; 像素尺寸变化超过 1 才重绘（gDrawnScale = 0 时会强制重画一次）
    if (Abs(gScale - gDrawnScale) * gCw >= 1) {
        DrawOverlay(gScale)
        gDrawnScale := gScale
    }
    MoveOverlay(x, y)
}

; ==================== 光标形状 ====================
UpdateCursorShape(hCur) {
    global gHCursor, gHx, gHy

    hx := 0, hy := 0
    ii := Buffer(A_PtrSize = 8 ? 32 : 20, 0)
    if DllCall("GetIconInfo", "Ptr", hCur, "Ptr", ii) {
        hx := NumGet(ii, 4, "UInt")
        hy := NumGet(ii, 8, "UInt")
        hbmMask := NumGet(ii, A_PtrSize = 8 ? 16 : 12, "Ptr")
        hbmColor := NumGet(ii, A_PtrSize = 8 ? 24 : 16, "Ptr")
        if (hbmMask)
            DllCall("DeleteObject", "Ptr", hbmMask)
        if (hbmColor)
            DllCall("DeleteObject", "Ptr", hbmColor)
    }

    gHCursor := hCur
    gHx := hx
    gHy := hy
}

; ==================== 放大光标窗口 ====================
CreateOverlay(x, y) {
    global gOverlay, gScale, gDrawnScale, gMargin, gWinW, gWinH
    global gHdcWin, gMemDC, gHbm, gOldBmp, gKeyBrush
    global gCw, gCh, gHCursor, SCALE_MAX

    ; 当前光标的图形与热点
    ci := Buffer(A_PtrSize = 8 ? 24 : 20, 0)
    NumPut("UInt", ci.Size, ci, 0)
    hCursor := 0
    if DllCall("GetCursorInfo", "Ptr", ci)
        hCursor := NumGet(ci, 8, "Ptr")
    if (!hCursor)
        return

    UpdateCursorShape(hCursor)
    gCw := DllCall("GetSystemMetrics", "Int", 13)   ; SM_CXCURSOR
    gCh := DllCall("GetSystemMetrics", "Int", 14)   ; SM_CYCURSOR

    ; 窗口按最大倍数预留，热点固定在窗口中心
    gMargin := Ceil(Max(gCw, gCh) * SCALE_MAX) + 4
    gWinW := gMargin * 2
    gWinH := gMargin * 2

    ; 小窗口 + 颜色键透明，鼠标穿透、不抢焦点
    g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "ShakeToFind")
    g.BackColor := "010101"
    DetectHiddenWindows(true)
    WinSetExStyle("+0x20 +0x80000 +0x08000000", "ahk_id " g.Hwnd)
    WinSetTransColor("010101", "ahk_id " g.Hwnd)
    DetectHiddenWindows(false)
    g.Show("NoActivate x" (x - gMargin) " y" (y - gMargin) " w" gWinW " h" gWinH)
    ApplyWindowIcon(g.Hwnd)
    ; 置于置顶窗口组的最上层
    DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0
        , "UInt", 0x0001 | 0x0002 | 0x0010)   ; NOSIZE | NOMOVE | NOACTIVATE

    gOverlay := g
    gHdcWin := DllCall("GetDC", "Ptr", g.Hwnd, "Ptr")
    gMemDC := DllCall("CreateCompatibleDC", "Ptr", gHdcWin, "Ptr")
    gHbm := DllCall("CreateCompatibleBitmap", "Ptr", gHdcWin, "Int", gWinW, "Int", gWinH, "Ptr")
    gOldBmp := DllCall("SelectObject", "Ptr", gMemDC, "Ptr", gHbm, "Ptr")
    gKeyBrush := DllCall("CreateSolidBrush", "UInt", 0x00010101, "Ptr")
    ; HALFTONE 让放大后的光标边缘更平滑（接近系统缩放的观感）
    DllCall("gdi32\SetStretchBltMode", "Ptr", gMemDC, "Int", 4)
    DllCall("gdi32\SetBrushOrgEx", "Ptr", gMemDC, "Int", 0, "Int", 0, "Ptr", 0)

    gScale := 1.0
    gDrawnScale := 0
}

; 放大显示期间提高定时器精度：跟随间隔 10ms -> 5ms
EnableFastTimer() {
    global gTimerFast, TIMER_ACTIVE
    if (!gTimerFast) {
        DllCall("winmm\timeBeginPeriod", "UInt", 1)
        gTimerFast := true
    }
    SetTimer(SampleMouse, TIMER_ACTIVE)
}

DisableFastTimer() {
    global gTimerFast, TIMER_IDLE
    if (gTimerFast) {
        DllCall("winmm\timeEndPeriod", "UInt", 1)
        gTimerFast := false
    }
    SetTimer(SampleMouse, TIMER_IDLE)
}

; 按指定倍数把光标画到内存位图，再一次性贴到窗口（避免闪烁）
;
; 关键：系统光标永远画在屏幕最上层，我们无法「擦除」它。
; 但可以在覆盖层上先用 1:1 的原始光标形状画一遍 —— 这一笔和系统光标完全重叠，
; 颜色键透明让只有光标笔画部分不透明，正好把系统光标盖住；
; 随后再在同一位置画放大的光标。于是屏幕上只剩放大的那一个，看不到小光标。
DrawOverlay(scaleFactor) {
    global gMemDC, gHdcWin, gWinW, gWinH, gKeyBrush
    global gHCursor, gHx, gHy, gCw, gCh, gMargin

    rect := Buffer(16)
    NumPut("Int", 0, rect, 0)
    NumPut("Int", 0, rect, 4)
    NumPut("Int", gWinW, rect, 8)
    NumPut("Int", gWinH, rect, 12)
    DllCall("FillRect", "Ptr", gMemDC, "Ptr", rect, "Ptr", gKeyBrush)

    ; 第一步：按 1:1 画一遍当前光标，用来遮住系统光标（热点对齐到窗口中心）
    if (gHCursor) {
        DllCall("DrawIconEx", "Ptr", gMemDC, "Int", gMargin - gHx, "Int", gMargin - gHy
            , "Ptr", gHCursor, "Int", gCw, "Int", gCh, "UInt", 0, "Ptr", 0, "UInt", 3)   ; DI_NORMAL
    }

    ; 第二步：画放大的光标
    dw := Round(gCw * scaleFactor)
    dh := Round(gCh * scaleFactor)
    dx := gMargin - Round(gHx * scaleFactor)
    dy := gMargin - Round(gHy * scaleFactor)
    DllCall("DrawIconEx", "Ptr", gMemDC, "Int", dx, "Int", dy, "Ptr", gHCursor
        , "Int", dw, "Int", dh, "UInt", 0, "Ptr", 0, "UInt", 3)   ; DI_NORMAL

    DllCall("BitBlt", "Ptr", gHdcWin, "Int", 0, "Int", 0, "Int", gWinW, "Int", gWinH
        , "Ptr", gMemDC, "Int", 0, "Int", 0, "UInt", 0x00CC0020)   ; SRCCOPY
}

MoveOverlay(x, y) {
    global gOverlay, gMargin
    if (!gOverlay)
        return
    DllCall("SetWindowPos", "Ptr", gOverlay.Hwnd, "Ptr", 0
        , "Int", x - gMargin, "Int", y - gMargin, "Int", 0, "Int", 0
        , "UInt", 0x0001 | 0x0004 | 0x0010)   ; NOSIZE | NOZORDER | NOACTIVATE
}

HideOverlay() {
    global gOverlay, gScale, gDrawnScale
    global gHdcWin, gMemDC, gHbm, gOldBmp, gKeyBrush

    if (gMemDC) {
        if (gOldBmp)
            DllCall("SelectObject", "Ptr", gMemDC, "Ptr", gOldBmp)
        if (gHbm)
            DllCall("DeleteObject", "Ptr", gHbm)
        DllCall("DeleteDC", "Ptr", gMemDC)
        gMemDC := 0
    }
    gHbm := 0
    gOldBmp := 0
    if (gKeyBrush) {
        DllCall("DeleteObject", "Ptr", gKeyBrush)
        gKeyBrush := 0
    }
    if (gHdcWin && IsObject(gOverlay)) {
        DllCall("ReleaseDC", "Ptr", gOverlay.Hwnd, "Ptr", gHdcWin)
        gHdcWin := 0
    }
    if (IsObject(gOverlay)) {
        try gOverlay.Destroy()
    }
    gOverlay := 0
    gScale := 1.0
    gDrawnScale := 0
}

; ==================== 图标 ====================
; 品牌图标路径：安装目录优先（与安装包 / 快捷方式同一枚），开发目录兜底
FindIconFile() {
    for iconPath in [A_ScriptDir "\ShakeToFind.ico", A_ScriptDir "\assets\icon\ShakeToFind.ico"] {
        if FileExist(iconPath)
            return iconPath
    }
    return ""
}

; 加载品牌图标的大 / 小两档句柄（供窗口图标使用；句柄保留到进程结束）
LoadWindowIcons() {
    global gIconBig, gIconSmall
    iconFile := FindIconFile()
    if (!iconFile)
        return
    ; IMAGE_ICON = 1，LR_LOADFROMFILE = 0x10
    ; SM_CXICON / SM_CYICON = 11 / 12，SM_CXSMICON / SM_CYSMICON = 49 / 50
    gIconBig := DllCall("LoadImageW", "Ptr", 0, "Str", iconFile, "UInt", 1
        , "Int", DllCall("GetSystemMetrics", "Int", 11), "Int", DllCall("GetSystemMetrics", "Int", 12)
        , "UInt", 0x10, "Ptr", 0)
    gIconSmall := DllCall("LoadImageW", "Ptr", 0, "Str", iconFile, "UInt", 1
        , "Int", DllCall("GetSystemMetrics", "Int", 49), "Int", DllCall("GetSystemMetrics", "Int", 50)
        , "UInt", 0x10, "Ptr", 0)
}

; 给窗口设置品牌图标：任务栏按钮、Alt+Tab、窗口预览都会用它
ApplyWindowIcon(hwnd) {
    global gIconBig, gIconSmall
    if (gIconBig)
        DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x80, "Ptr", 1, "Ptr", gIconBig)     ; WM_SETICON, ICON_BIG
    if (gIconSmall)
        DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x80, "Ptr", 0, "Ptr", gIconSmall)   ; WM_SETICON, ICON_SMALL
}

; ==================== 界面语言 ====================
; 界面文案。新增一种语言：在 UiStrings 里加一个分支，并把语言代码加进菜单
UiStrings(lang) {
    if (lang = "zh")
        return Map(
            "tip",       "ShakeToFind — 快速移动放大指针",
            "open",      "打开(&O)",
            "help",      "帮助(&H)",
            "windowSpy", "窗口探测(&W)",
            "reload",    "重新加载脚本(&R)",
            "edit",      "编辑脚本(&E)",
            "suspend",   "挂起热键(&S)",
            "pause",     "暂停脚本(&P)",
            "exit",      "退出(&X)",
            "language",  "语言(&L)",
            "langAuto",  "跟随系统（自动）",
            "langZh",    "简体中文",
            "langEn",    "English")
    return Map(
        "tip",       "ShakeToFind — Enlarge the pointer when you move fast",
        "open",      "&Open",
        "help",      "&Help",
        "windowSpy", "&Window Spy",
        "reload",    "&Reload Script",
        "edit",      "&Edit Script",
        "suspend",   "&Suspend Hotkeys",
        "pause",     "&Pause Script",
        "exit",      "E&xit",
        "language",  "&Language",
        "langAuto",  "Follow system (automatic)",
        "langZh",    "简体中文",
        "langEn",    "English")
}

; AHK 内置托盘菜单项的英文名。只改显示文本、保留内置 ID，所以 Reload / Suspend / Pause 等功能不变
StandardTrayItems() {
    return Map(
        "open",      "&Open",
        "help",      "&Help",
        "windowSpy", "&Window Spy",
        "reload",    "&Reload Script",
        "edit",      "&Edit Script",
        "suspend",   "&Suspend Hotkeys",
        "pause",     "&Pause Script",
        "exit",      "E&xit")
}

; 系统用户界面语言 -> 界面语言代码
DetectSystemLanguage() {
    static detected := ""
    if (detected)
        return detected
    langId := 0
    try langId := DllCall("GetUserDefaultUILanguage", "UShort")
    primary := langId & 0x3FF
    ; 0x04 = 中文；本项目目前只提供简体中文，繁体系统也先显示简体中文
    detected := (primary = 0x04) ? "zh" : "en"
    return detected
}

; 界面语言偏好存在脚本同目录的 ShakeToFind.ini
IniPath() {
    return A_ScriptDir "\ShakeToFind.ini"
}

; 说明：这里先用 FileRead("UTF-8") 自己解析，因为 AHK 的 IniRead 不认带 BOM 的 UTF-8 ini
; （记事本等编辑器可能这样保存），而 FileRead 会自动跳过/识别 BOM。
ReadLangPref() {
    ini := IniPath()
    if (!FileExist(ini))
        return "auto"
    text := ""
    try
        text := FileRead(ini, "UTF-8")
    catch
        text := ""
    ; 手工编辑的文件只认 Language= 这一行，不要求 [General] 段格式完全正确
    if (RegExMatch(text, "im)^[ \t]*Language[ \t]*=[ \t]*([A-Za-z]+)", &m)) {
        pref := StrLower(m[1])
        if (pref = "zh" || pref = "en" || pref = "auto")
            return pref
    }
    ; 兜底：旧版本 IniWrite 或某些编辑器会存成 UTF-16，此时上面的文本读取可能拿不到，
    ; 再用 IniRead 试一次（它对 UTF-16 友好；UTF-8 BOM 的情况已由上面的正则命中）
    pref := ""
    try
        pref := IniRead(ini, "General", "Language", "")
    catch
        return "auto"
    pref := StrLower(Trim(pref))
    return (pref = "zh" || pref = "en" || pref = "auto") ? pref : "auto"
}

WriteLangPref(pref) {
    try {
        f := FileOpen(IniPath(), "w", "UTF-8")
        f.Write("[General]`r`nLanguage=" pref "`r`n")
        f.Close()
    }
}

; 应用界面语言：pref = auto / zh / en（auto 表示跟随系统）
ApplyLanguage(pref, persist := false) {
    global gLang, gLangPref, gLangMenu, gLangMenuItem, gMenuLabels

    pref := StrLower(Trim(pref))
    if (pref != "auto" && pref != "zh" && pref != "en")
        pref := "auto"
    gLangPref := pref
    if (persist)
        WriteLangPref(pref)

    gLang := (pref = "auto") ? DetectSystemLanguage() : pref
    s := UiStrings(gLang)

    ; 第一次：记下内置菜单项原名，并在「退出」上方插入分隔线和「语言」子菜单
    if (gLangMenu = 0) {
        for key, name in StandardTrayItems()
            gMenuLabels[key] := name
        gLangMenuItem := "&Language"
        gLangMenu := Menu()
        A_TrayMenu.Insert("E&xit")                          ; 语言上方的分隔线
        A_TrayMenu.Insert("E&xit", gLangMenuItem, gLangMenu)
        A_TrayMenu.Insert("E&xit")                          ; 退出上方的分隔线
    }

    ; 重命名内置菜单项（内置 ID 不变，Suspend/Pause 的勾选状态仍由 AHK 维护）
    for key, officialName in StandardTrayItems() {
        oldName := gMenuLabels.Has(key) ? gMenuLabels[key] : officialName
        newName := s[key]
        if (newName != oldName) {
            try A_TrayMenu.Rename(oldName, newName)
            gMenuLabels[key] := newName
        }
    }

    ; 重建「语言」子菜单（勾选当前选择）
    if (gLangMenuItem != s["language"]) {
        try A_TrayMenu.Rename(gLangMenuItem, s["language"])
        gLangMenuItem := s["language"]
    }
    gLangMenu.Delete()
    gLangMenu.Add(s["langAuto"], ChooseLanguage.Bind("auto"), "Radio")
    gLangMenu.Add(s["langZh"], ChooseLanguage.Bind("zh"), "Radio")
    gLangMenu.Add(s["langEn"], ChooseLanguage.Bind("en"), "Radio")
    checked := (gLangPref = "zh") ? s["langZh"] : ((gLangPref = "en") ? s["langEn"] : s["langAuto"])
    gLangMenu.Check(checked)

    ; 托盘图标提示也跟着切换
    A_IconTip := s["tip"]
}

; 用户从菜单切换语言：先保存偏好，再稍后重建菜单（避免在菜单回调里直接改动菜单本身）
ChooseLanguage(pref, *) {
    SetTimer(ApplyLanguage.Bind(pref, true), -30)
}

; ==================== 演示模式 ====================
RunDemo() {
    global SCALE_MAX
    x := A_ScreenWidth // 2
    y := A_ScreenHeight // 2
    CreateOverlay(x, y)
    loop 25 {
        DrawOverlay(1.0 + A_Index * (SCALE_MAX - 1.0) / 25)
        Sleep 25
    }
    DrawOverlay(SCALE_MAX)
    Sleep 900
    HideOverlay()
}
