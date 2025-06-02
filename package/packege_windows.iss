; 脚本由 ChatGPT 美化 - Flutter Windows 应用安装程序打包

[Setup]
AppName=账本
AppVersion=1.0.0
DefaultDirName={commonpf}\billing
DefaultGroupName=KcSoft
OutputDir=dist
OutputBaseFilename=账本（安装程序）
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
; DefaultLanguage=chinesesimp
UninstallDisplayIcon={app}\billing.exe
SetupIconFile=..\windows\runner\resources\app_icon.ico
DisableWelcomePage=no
AppPublisher=KcSoft
; AppPublisherURL=https://example.com
; AppSupportURL=https://example.com/support
; AppUpdatesURL=https://example.com/update
LicenseFile=LICENSE.txt
CreateAppDir=yes
CreateUninstallRegKey=yes
ShowLanguageDialog=yes

; [Languages]
; Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
; Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\账本"; Filename: "{app}\billing.exe"
Name: "{commondesktop}\账本"; Filename: "{app}\billing.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "额外任务:"

[Run]
Filename: "{app}\billing.exe"; Description: "运行 账本 应用程序"; Flags: nowait postinstall skipifsilent

