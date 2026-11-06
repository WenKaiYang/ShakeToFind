@echo off
setlocal EnableExtensions

rem ShakeToFind build script (Inno Setup 6)
rem
rem Usage:
rem   build.cmd            build with the default version in installer\ShakeToFind.iss
rem   build.cmd 1.0.1      build with an explicit version

set "ROOT=%~dp0"
set "ISS=%ROOT%installer\ShakeToFind.iss"
set "PAYLOAD=%ROOT%installer\payload"
set "VERSION=%~1"

rem ---- 1. Locate the Inno Setup compiler ----
set "ISCC="
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not defined ISCC for %%I in (ISCC.exe) do if not "%%~$PATH:I"=="" set "ISCC=%%~$PATH:I"
if not defined ISCC (
    echo [ERROR] Inno Setup 6 not found.
    echo         Install it first: https://jrsoftware.org/isdl.php
    exit /b 1
)

rem ---- 2. Check bundled runtime files ----
for %%F in (AutoHotkey64.exe AutoHotkey32.exe license.txt stop-running.cmd) do (
    if not exist "%PAYLOAD%\%%F" (
        echo [ERROR] Missing installer\payload\%%F
        echo         See the "First-time setup" section of installer\BUILD.md.
        exit /b 1
    )
)

rem ---- 3. Compile ----
echo Compiler: %ISCC%
if defined VERSION (
    echo Version : %VERSION%
    "%ISCC%" "/DMyAppVersion=%VERSION%" "%ISS%"
) else (
    "%ISCC%" "%ISS%"
)
if errorlevel 1 (
    echo.
    echo [FAILED] Compilation failed, see the Inno Setup output above.
    exit /b 1
)

rem ---- 4. Report the artifact ----
if defined VERSION (
    set "VER=%VERSION%"
) else (
    for /f "tokens=3" %%V in ('findstr /b /c:"#define MyAppVersion" "%ISS%"') do set "VER=%%~V"
)
echo.
if defined VER (
    echo [OK] Installer: %ROOT%dist\ShakeToFind-Setup-%VER%.exe
) else (
    echo [OK] Installer written to: %ROOT%dist
)

endlocal
exit /b 0
