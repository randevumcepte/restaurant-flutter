; ResteOS Windows kurulum sihirbazi (Inno Setup)
; Derleme: ISCC.exe ResteOS.iss  ->  ..\ResteOS-Kurulum.exe uretir

#define AppName "ResteOS"
#define AppExe "restoos_patron.exe"
#define AppVersion "1.0.0"
#define AppPublisher "ResteOS"
#define SrcDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B3E7C9A1-4D2F-4E8B-9F1A-RESTEOS00001}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://www.resteos.com
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..
OutputBaseFilename=ResteOS-Kurulum
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaustune kisayol olustur"; GroupDescription: "Ek kisayollar:"; Flags: checkedonce

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\{#AppName} Kaldir"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{#AppName} uygulamasini simdi baslat"; Flags: nowait postinstall skipifsilent
