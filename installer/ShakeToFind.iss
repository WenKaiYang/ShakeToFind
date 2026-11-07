; ShakeToFind installer script (Inno Setup 6)
; Build: 在项目根目录运行 build.cmd（或 build.cmd 1.0.1 指定版本号）
; Manual: "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" installer\ShakeToFind.iss

#define MyAppName "ShakeToFind"
#ifndef MyAppVersion
#define MyAppVersion "1.0.2"
#endif
#define MyAppPublisher "ShakeToFind"
; 品牌图标：安装包、开始菜单、开机启动、卸载项、托盘都用这一枚
#define MyIcon "..\assets\icon\ShakeToFind.ico"

[Setup]
AppId={{6B1F6C2E-5C1A-4B7E-9B7B-2A0B9B0C6E21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\ShakeToFind
DefaultGroupName=ShakeToFind
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=ShakeToFind-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#MyIcon}
UninstallDisplayIcon={app}\ShakeToFind.ico
UninstallDisplayName={#MyAppName}

[Tasks]
Name: "startup"; Description: "Start ShakeToFind automatically when Windows starts"; GroupDescription: "Additional tasks:"

[Files]
Source: "..\ShakeToFind.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyIcon}"; DestDir: "{app}"; DestName: "ShakeToFind.ico"; Flags: ignoreversion
Source: "payload\AutoHotkey64.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\AutoHotkey32.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\license.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\stop-running.cmd"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userstartup}\ShakeToFind"; Filename: "{app}\AutoHotkey64.exe"; Parameters: """{app}\ShakeToFind.ahk"""; WorkingDir: "{app}"; IconFilename: "{app}\ShakeToFind.ico"; IconIndex: 0; Tasks: startup; Check: IsWin64
Name: "{userstartup}\ShakeToFind"; Filename: "{app}\AutoHotkey32.exe"; Parameters: """{app}\ShakeToFind.ahk"""; WorkingDir: "{app}"; IconFilename: "{app}\ShakeToFind.ico"; IconIndex: 0; Tasks: startup; Check: not IsWin64
Name: "{group}\ShakeToFind"; Filename: "{app}\AutoHotkey64.exe"; Parameters: """{app}\ShakeToFind.ahk"""; WorkingDir: "{app}"; IconFilename: "{app}\ShakeToFind.ico"; IconIndex: 0; Check: IsWin64
Name: "{group}\ShakeToFind"; Filename: "{app}\AutoHotkey32.exe"; Parameters: """{app}\ShakeToFind.ahk"""; WorkingDir: "{app}"; IconFilename: "{app}\ShakeToFind.ico"; IconIndex: 0; Check: not IsWin64
Name: "{group}\Uninstall ShakeToFind"; Filename: "{uninstallexe}"; IconFilename: "{app}\ShakeToFind.ico"; IconIndex: 0

[Run]
Filename: "{app}\AutoHotkey64.exe"; Parameters: """{app}\ShakeToFind.ahk"""; WorkingDir: "{app}"; Description: "Start ShakeToFind now"; Flags: nowait postinstall skipifsilent; Check: IsWin64
Filename: "{app}\AutoHotkey32.exe"; Parameters: """{app}\ShakeToFind.ahk"""; WorkingDir: "{app}"; Description: "Start ShakeToFind now"; Flags: nowait postinstall skipifsilent; Check: not IsWin64

[UninstallDelete]
Type: files; Name: "{app}\trigger.log"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    if FileExists(ExpandConstant('{app}\stop-running.cmd')) then
      Exec(ExpandConstant('{app}\stop-running.cmd'), '', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    if FileExists(ExpandConstant('{app}\stop-running.cmd')) then
      Exec(ExpandConstant('{app}\stop-running.cmd'), '', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
