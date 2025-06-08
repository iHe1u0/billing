[Setup]
AppName=账本
AppVersion=1.0.0
DefaultDirName={userpf}\BillingApp
DefaultGroupName=KcSoft
OutputDir=dist
OutputBaseFilename=账本（安装程序）
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\billing.exe
SetupIconFile=..\windows\runner\resources\app_icon.ico
DisableWelcomePage=no
AppPublisher=KcSoft
LicenseFile=LICENSE.txt
CreateAppDir=yes
CreateUninstallRegKey=yes
ShowLanguageDialog=yes

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs
Source: "windows\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\账本"; Filename: "{app}\billing.exe"
Name: "{commondesktop}\账本"; Filename: "{app}\billing.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "额外任务:"

[Run]
Filename: "{app}\billing.exe"; Description: "运行 账本 应用程序"; Flags: nowait postinstall skipifsilent
