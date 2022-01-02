
# WSL setup options
[CmdletBinding()]
param (
    # desired wsl user name
    [Parameter(Mandatory=$true)]
    [string]
    $wslUser,
    # desired wsl user password
    [Parameter(Mandatory=$true)]
    [SecureString]
    $wslPassword,
    # optional desired location debian data directory
    [Parameter(Mandatory=$true)]
    [AllowEmptyString()]
    [string]
    $wslDataDir,
    # remote dotfiles repo uri: must include username if password is required: https://justinsantoro@github.com/...
    [Parameter(Mandatory=$true)]
    [string]
    $dotfilesRepo,
    # optional password for cloning private dotfiles repo
    [Parameter(Mandatory=$true)]
    [SecureString]
    $githubPassword,
    # optional path to pdfxChange key file for automatic license activation
    [Parameter(Mandatory=$true)]
    [AllowEmptyString()]
    [string]
    $pdfxKeyFile
)

$Env:WSL_USER=$wslUser
$Env:WSL_PASSWORD=([Net.NetworkCredential]::new('', $wslPassword).Password)
$Env:GITHUB_PASSWORD=([Net.NetworkCredential]::new('', $githubPassword).Password)
$Env:DOTFILES_REPO=$dotfilesRepo

$pdfxKeyFile = $Env:PDFX_KEY_FILE  # location of pdfxchange key file

try {
    # install boxstarter
    Set-ExecutionPolicy Bypass -Scope Process -Force

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/justinsantoro/dev-env-setup/main/bootstrapper.ps1'))
    If (!(Test-Admin)) {throw "must run as admin"}
    Get-Boxstarter -Force
    
    # setup boxstarter environ
    # Chocolated module is imported first via Get-Boxstarter
    Resolve-Path C:\ProgramData\Boxstarter\Boxstarter.*\*.psd1 |
        % { Import-Module $_.ProviderPath -DisableNameChecking }

} catch {Write-Error $_; Exit}

Disable-UAC
Disable-MicrosoftUpdate

# configure windows
Disable-BingSearch
Enable-RemoteDesktop
Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowFileExtensions -EnableShowFullPathInTitleBar -DisableOpenFileExplorerToQuickAccess -DisableShowRecentFilesInQuickAccess -DisableShowFrequentFoldersInQuickAccess -EnableExpandToOpenFolder
Set-BoxstarterTaskbarOptions -Size Small -MultiMonitorOn -Combine Full -MultiMonitorMode Open
choco install -y Microsoft-Hyper-V-All --source="'windowsFeatures'"

# Install the OpenSSH Client
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
# Install the OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Install wsl2
cinst -y wsl2
RefreshEnv
# pass variables to wsl
$Env:WSLENV = 'WSL_PASSWORD/u:WSL_USER/u:GITHUB_PASSWORD/u:DOTFILES_REPO/u' 

# debian setup
Invoke-WebRequest -Uri https://aka.ms/wsl-debian-gnulinux -OutFile ~/Debian.appx -UseBasicParsing
Add-AppxPackage -Path ~/Debian.appx
# run the distro once and have it install locally with root user, unset password
RefreshEnv
Debian install --root
if (!($?)) {write-error "debian install failed"; Exit}

try {
    if ($wslDataDir) {
        # move debian data to desired data location
        write-host "moving debian data dir to: $wslDataDir ..." -ForegroundColor Green
        new-Item -Path $wslDataDir -ItemType Directory -Force | Out-Null
        wsl --export debian "./debian.tar"
        if (!($?)) {throw "error exporting debian"}
        wsl --unregister debian
        if (!($?)) {throw "error unregistering debian"}
        wsl --import debian $wslDataDir "./debian.tar"
        if (!($?)) {throw "error re-importing debian to new data location: $wslDataDir"}
        Remove-Item "./debian.tar" -Force
    }
    
    #run debian setup...
    if (!(Test-Path "./debiansetup.sh")) {
        # download script from github
        write-host "downloading debian setup script..." -ForegroundColor Green
        Invoke-Webrequest -Uri https://raw.githubusercontent.com/justinsantoro/dev-env-setup/main/debiansetup.sh -OutFile debiansetup.sh -UseBasicParsing
    } 
    Write-Host "copying debian setup script to wsl..."
    copy-item .\debiansetup.sh \\wsl$\debian\root\debiansetup.sh
    debian run "/bin/bash /root/debiansetup.sh"
    if (!($?)) {throw "error setting up debian"}
    
    debian config --default-user $ENV:WSL_USER
    if (!($?)) {throw "error setting default user for debian"}

    #add startup script to map wsl network drive
    Write-Output "net use W: \\wsl$" | Out-File -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\mapwsl.bat"
} catch {
    Write-Host "error configuring wsl" -ForegroundColor Red
    Write-Error $_
}

# common dev tools
choco install -y microsoft-windows-terminal
choco install -y git --package-parameters="'/GitOnlyOnPath /WindowsTerminal /NoShellIntegration /NoCredentialManager /NoOpenSSH /DefaultBranchName:main'"
choco install -y vscode --params "/NoDesktopIcon /NoContextMenuFiles"
choco install -y docker-desktop
choco install -y vscode-docker
choco install -y 7zip.install
choco install -y tortoisehg
choco install -y autohotkey
choco install -y kdiff3
choco install -y keepass
choco install -y vscode-mssql
choco install -y sql-server-management-studio
choco install -y github-desktop
choco install -y vscode-gitlens
choco install -y pwsh

# browsers
choco install chromium
choco install ublockorigin-chrome

# office tools
choco install -y clockify
choco install -y office365business --forcex86 --params='/exclude:"Groove Lync Publisher" /eula:"TRUE"'

# get pdfxchange key file
if ($pdfxKeyFile) {
    if (Test-Path $pdfxKeyFile) {
        $pdfxKeyFile = " /KeyFile:$pdfKeyFile"
    } else {
        $pdfKeyFile = ""
    }
}
choco install -y pdfxchangeeditor --params='"/NoSetAsDefault /NoProgramsMenuShortcuts /NoUpdater /NoDesktopShortcuts${pdfxKeyFile}"'

# messaging
choco install -y teams
choco install -y telegram
#choco install -y keybase

# media
choco install -y vlc
choco install -y obs-studio

# graphics
choco install -y corretto8jre
choco install -y freemind
#choco install -y pencil
choco install -y gimp
choco install -y inkscape

#--- Uninstall unnecessary applications that come with Windows out of the box ---
Write-Host "Uninstall some applications that come with Windows out of the box" -ForegroundColor "Yellow"

#Referenced to build script
# https://docs.microsoft.com/en-us/windows/application-management/remove-provisioned-apps-during-update
# https://github.com/jayharris/dotfiles-windows/blob/master/windows.ps1#L157
# https://gist.github.com/jessfraz/7c319b046daa101a4aaef937a20ff41f
# https://gist.github.com/alirobe/7f3b34ad89a159e6daa1
# https://github.com/W4RH4WK/Debloat-Windows-10/blob/master/scripts/remove-default-apps.ps1

function removeApp {
	Param ([string]$appName)
	write-host "Trying to remove $appName"
	Get-AppxPackage $appName -AllUsers | Remove-AppxPackage
	Get-AppXProvisionedPackage -Online | Where DisplayName -like $appName | Remove-AppxProvisionedPackage -Online
}

$applicationList = @(
	"Microsoft.BingFinance"
	"Microsoft.3DBuilder"
	"Microsoft.BingFinance"
	"Microsoft.BingNews"
	"Microsoft.BingSports"
	"Microsoft.BingWeather"
	"Microsoft.CommsPhone"
	"Microsoft.Getstarted"
	"Microsoft.WindowsMaps"
	"*MarchofEmpires*"
	"Microsoft.GetHelp"
	"Microsoft.Messaging"
	"*Minecraft*"
	"Microsoft.MicrosoftOfficeHub"
	"Microsoft.OneConnect"
	"Microsoft.WindowsPhone"
	"Microsoft.WindowsSoundRecorder"
	"*Solitaire*"
	"Microsoft.MicrosoftStickyNotes"
	"Microsoft.Office.Sway"
	"Microsoft.XboxApp"
	"Microsoft.XboxIdentityProvider"
	"Microsoft.ZuneMusic"
	"Microsoft.ZuneVideo"
	"Microsoft.NetworkSpeedTest"
	"Microsoft.FreshPaint"
	"Microsoft.Print3D"
	"*Autodesk*"
	"*BubbleWitch*"
    "king.com*"
    "G5*"
	"*Dell*"
	"*Facebook*"
	"*Keeper*"
	"*Netflix*"
	"*Twitter*"
	"*Plex*"
	"*.Duolingo-LearnLanguagesforFree"
	"*.EclipseManager"
	"ActiproSoftwareLLC.562882FEEB491" # Code Writer
	"*.AdobePhotoshopExpress"
);

foreach ($app in $applicationList) {
    removeApp $app
}

#--- reenabling critial items ---
Enable-UAC
Enable-MicrosoftUpdate
Install-WindowsUpdate -acceptEula
#Restart-Computer