# dev-env-setup

full setup script for my windows-wsl2 (debian) dev environment leaning heavily on docker and vscode devcontainers

## Run in elevated Windows Powershell console:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/justinsantoro/dev-env-setup/main/setup.ps1'))
```