; Random Suite (FT & Desktop) Installer Script
#define MyAppName "Random Suite"
#define MyAppVersion "4.0.1" ; 每次发版更新这里
#define MyAppPublisher "Infinity"
#define MyAppExeNameFT "Random_FloatingTool.exe"
#define MyAppExeNameDesktop "random_desktop.exe"

[Setup]
; AppId极其关键，不要更改它！这保证了后续安装能够完美覆盖升级。
AppId={{745b39e7-349d-4717-9175-7f4446e8bcd7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\Output
OutputBaseFilename=RandomSuite_Setup_v{#MyAppVersion}
Compression=lzma
SolidCompression=yes
; 指定在安装前如果程序在运行，提示用户关闭（支持静默关闭）
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; 打包 FT (Random_FloatingTool)
Source: "..\Random_FloatingTool\Random_FloatingTool\bin\Release\net8.0-windows10.0.19041.0\publish\*"; DestDir: "{app}\FT"; Excludes: "*.zip"; Flags: ignoreversion recursesubdirs createallsubdirs
; 打包 Desktop (random-desktop)
Source: "..\random-desktop\build\windows\x64\runner\Release\*"; DestDir: "{app}\Desktop"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; 桌面快捷方式
Name: "{autodesktop}\Random Floating Tool"; Filename: "{app}\FT\{#MyAppExeNameFT}"
Name: "{autodesktop}\Random Desktop"; Filename: "{app}\Desktop\{#MyAppExeNameDesktop}"

; 开始菜单快捷方式
Name: "{group}\Random Floating Tool"; Filename: "{app}\FT\{#MyAppExeNameFT}"
Name: "{group}\Random Desktop"; Filename: "{app}\Desktop\{#MyAppExeNameDesktop}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\FT\{#MyAppExeNameFT}"; Description: "启动 Random Floating Tool"; Flags: nowait postinstall skipifsilent
Filename: "{app}\Desktop\{#MyAppExeNameDesktop}"; Description: "启动 Random Desktop"; Flags: nowait postinstall skipifsilent unchecked
