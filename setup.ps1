
# WSL setup options

# $Env:WSL_PASSWORD                desired wsl user password
# $Env:WSL_USER                    desired wsl user name
# $Env:GITHUB_PASSWORD             optional password for cloning private dotfiles repo
# $Env:DOTFILES_REPO               remote dotfiles repo url: must include username if password is required: https://justinsantoro@github.com/...
$wslDataDir = $Env:WSL_DATA_DIR    # ooptional desired location of wsl data directory

$pdfxKeyFile = $Env:PDFX_KEY_FILE  # location of pdfxchange key file

try {
    # install boxstarter
    Set-ExecutionPolicy Bypass -Scope Process -Force

    If (!($Env:BOXSTARTER_INSTALLED)) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://boxstarter.org/bootstrapper.ps1'))
        Get-Boxstarter -Force
        setx.exe BOXSTARTER_INSTALLED=1
    }
    # setup boxstarter environ
    $here = C:\ProgramData\Boxstarter

    # Import the Chocolatey module first so that $Boxstarter properties
    # are initialized correctly and then import everything else.
    Import-Module $here\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1 -DisableNameChecking -ErrorAction SilentlyContinue
    Resolve-Path $here\Boxstarter.*\*.psd1 |
        % { Import-Module $_.ProviderPath -DisableNameChecking -ErrorAction SilentlyContinue }
    Import-Module $here\Boxstarter.Common\Boxstarter.Common.psd1 -Function Test-Admin

    # if(!(Test-Admin)) {
    #     Write-BoxstarterMessage "Not running with administrative rights. Attempting to elevate..."
    #     $command = "-ExecutionPolicy bypass -noexit -command &'$here\BoxstarterShell.ps1'"
    #     Start-Process powershell -verb runas -argumentlist $command
    #     Exit
    # }

    Disable-UAC
    Disable-MicrosoftUpdate
} catch {Write-Error $_; Exit}

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
    if (Test-Path "./debiansetup.sh") {
        # copy file to debian
        Write-Host "copying debian setup script to wsl..."
        copy-item .\debiansetup.sh \\wsl$\debian\root\debiansetup.sh
        debian run "/bin/bash /root/debiansetup.sh"
    } else {
        #download it from github
        write-error "not implemented"
    }
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