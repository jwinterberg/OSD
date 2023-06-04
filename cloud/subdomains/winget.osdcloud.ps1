<#PSScriptInfo
.VERSION 23.6.3.1
.GUID 8aa84227-ddb5-4276-95fb-ffb2d6121bf8
.AUTHOR David Segura @SeguraOSD
.COMPANYNAME osdcloud.com
.COPYRIGHT (c) 2023 David Segura osdcloud.com. All rights reserved.
.TAGS OSDeploy OSDCloud WinGet PowerShell
.LICENSEURI 
.PROJECTURI https://github.com/OSDeploy/OSD
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
Script should be executed in a Command Prompt using the following command
powershell Invoke-Expression -Command (Invoke-RestMethod -Uri winget.osdcloud.com)
This is abbreviated as
powershell iex (irm winget.osdcloud.com)
#>
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    PowerShell Script which supports WinGet
.DESCRIPTION
    PowerShell Script which supports WinGet
.NOTES
    Version 23.6.3.1
.LINK
    https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/subdomains/winget.osdcloud.ps1
.EXAMPLE
    powershell iex (irm winget.osdcloud.com)
#>
[CmdletBinding()]
param()
$ScriptName = 'winget.osdcloud.com'
$ScriptVersion = '23.6.3.1'

#region Initialize
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-$ScriptName.log"
$null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore

if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
}
else {
    $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
    if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
    else {$WindowsPhase = 'Windows'}
}

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"
Invoke-Expression -Command (Invoke-RestMethod -Uri functions.osdcloud.com)
#endregion

#region Admin Elevation
$whoiam = [system.security.principal.windowsidentity]::getcurrent().name
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isElevated) {
    Write-Host -ForegroundColor Green "[+] Running as $whoiam (Admin Elevated)"
}
else {
    Write-Host -ForegroundColor Red "[!] Running as $whoiam (NOT Admin Elevated)"
    Break
}
#endregion

#region Transport Layer Security (TLS) 1.2
Write-Host -ForegroundColor Green "[+] Transport Layer Security (TLS) 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
#endregion

#region WinPE
if ($WindowsPhase -eq 'WinPE') {
    osdcloud-SetExecutionPolicy
    osdcloud-WinpeSetEnvironmentVariables
    osdcloud-SetPowerShellProfile
    #osdcloud-WinpeInstallNuget
    osdcloud-InstallPackageManagement
    osdcloud-WinpeInstallPowerShellGet
    osdcloud-TrustPSGallery
    Write-Host -ForegroundColor Cyan "To start a new PowerShell session, type 'start powershell' and press enter"
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion


#region Specialize
if ($WindowsPhase -eq 'Specialize') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion


#region AuditMode
if ($WindowsPhase -eq 'AuditMode') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion


#region OOBE
if ($WindowsPhase -eq 'OOBE') {
    osdcloud-SetExecutionPolicy
    osdcloud-SetPowerShellProfile
    osdcloud-InstallPackageManagement
    osdcloud-TrustPSGallery
    osdcloud-InstallModuleOSD
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion


#region Windows
if ($WindowsPhase -eq 'Windows') {
    osdcloud-SetExecutionPolicy
    osdcloud-SetPowerShellProfile
    osdcloud-InstallPackageManagement
    osdcloud-TrustPSGallery
    osdcloud-InstallModuleOSD
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion





#region Set Environment Variables
if ($WindowsPhase -eq 'WinPE') {
    if (Get-Item env:LocalAppData -ErrorAction Ignore) {
        Write-Host -ForegroundColor Green "[+] LocalAppData is set to $((Get-Item env:LOCALAPPDATA).Value)"
    }
    else {
        Write-Host -ForegroundColor Yellow "[-] Setting LocalAppData in System Environment"
        [System.Environment]::SetEnvironmentVariable('APPDATA',"$Env:UserProfile\AppData\Roaming",[System.EnvironmentVariableTarget]::Process)
        [System.Environment]::SetEnvironmentVariable('HOMEDRIVE',"$Env:SystemDrive",[System.EnvironmentVariableTarget]::Process)
        [System.Environment]::SetEnvironmentVariable('HOMEPATH',"$Env:UserProfile",[System.EnvironmentVariableTarget]::Process)
        [System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$Env:UserProfile\AppData\Local",[System.EnvironmentVariableTarget]::Process)
    }
}
#endregion

#region Nuget
if ($WindowsPhase -eq 'WinPE') {
    $NuGetClientSourceURL = 'https://nuget.org/nuget.exe'
    $NuGetExeName = 'NuGet.exe'
    $PSGetProgramDataPath = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
    $nugetExeBasePath = $PSGetProgramDataPath
    $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName

    if (-not (Test-Path -Path $nugetExeFilePath)) {
        if (-not (Test-Path -Path $nugetExeBasePath)) {
            $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        Write-Host -ForegroundColor Yellow "[-] Downloading NuGet to $nugetExeFilePath"
        $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
    }

    $PSGetAppLocalPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
    $nugetExeBasePath = $PSGetAppLocalPath
    $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
    if (-not (Test-Path -Path $nugetExeFilePath)) {
        if (-not (Test-Path -Path $nugetExeBasePath)) {
            $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        Write-Host -ForegroundColor Yellow "[-] Downloading NuGet to $nugetExeFilePath"
        $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
    }
}
else {
    if (Test-Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll") {
        #Write-Host -ForegroundColor Green "[+] Nuget 2.8.5.208+"
    }
    else {
        Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider NuGet -MinimumVersion 2.8.5.201"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
    }
    $InstalledModule = Get-PackageProvider -Name NuGet | Where-Object {$_.Version -ge '2.8.5.201'} | Sort-Object Version -Descending | Select-Object -First 1
    if ($InstalledModule) {
        Write-Host -ForegroundColor Green "[+] NuGet $([string]$InstalledModule.Version)"
    }
}
#endregion

#region PowerShellGet PackageManagement (OOBE and Windows)
if ($WindowsPhase -ne 'WinPE') {
    $InstalledModule = Get-PackageProvider -Name PowerShellGet | Where-Object {$_.Version -ge '2.2.5'} | Sort-Object Version -Descending | Select-Object -First 1
    if (-not ($InstalledModule)) {
        Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider PowerShellGet -MinimumVersion 2.2.5"
        Install-PackageProvider -Name PowerShellGet -MinimumVersion 2.2.5 -Force -Scope AllUsers | Out-Null
        Import-Module PowerShellGet -Force -Scope Global -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
    }

    $InstalledModule = Get-Module -Name PackageManagement -ListAvailable | Where-Object {$_.Version -ge '1.4.8.1'} | Sort-Object Version -Descending | Select-Object -First 1
    if (-not ($InstalledModule)) {
        Write-Host -ForegroundColor Yellow "[-] Install-Module PackageManagement -MinimumVersion 1.4.8.1"
        Install-Module -Name PackageManagement -MinimumVersion 1.4.8.1 -Force -Confirm:$false -Source PSGallery -Scope AllUsers
        Import-Module PackageManagement -Force -Scope Global -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
    }

    Import-Module PackageManagement -Force -Scope Global -ErrorAction SilentlyContinue
    $InstalledModule = Get-Module -Name PackageManagement -ListAvailable | Where-Object {$_.Version -ge '1.4.8.1'} | Sort-Object Version -Descending | Select-Object -First 1
    if ($InstalledModule) {
        Write-Host -ForegroundColor Green "[+] PackageManagement $([string]$InstalledModule.Version)"
    }
    Import-Module PowerShellGet -Force -Scope Global -ErrorAction SilentlyContinue
    $InstalledModule = Get-PackageProvider -Name PowerShellGet | Where-Object {$_.Version -ge '2.2.5'} | Sort-Object Version -Descending | Select-Object -First 1
    if ($InstalledModule) {
        Write-Host -ForegroundColor Green "[+] PowerShellGet $([string]$InstalledModule.Version)"
    }
}
#endregion

#region PowerShellGet PackageManagement (WinPE)
if ($WindowsPhase -eq 'WinPE') {
    $InstalledModule = Import-Module PackageManagement -PassThru -ErrorAction Ignore
    if (-not $InstalledModule) {
        Write-Host -ForegroundColor Yellow "[-] Install PackageManagement 1.4.8.1"
        $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.8.1.nupkg"
        Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "$env:TEMP\packagemanagement.1.4.8.1.zip"
        $null = New-Item -Path "$env:TEMP\1.4.8.1" -ItemType Directory -Force
        Expand-Archive -Path "$env:TEMP\packagemanagement.1.4.8.1.zip" -DestinationPath "$env:TEMP\1.4.8.1"
        $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
        Move-Item -Path "$env:TEMP\1.4.8.1" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.8.1"
        Import-Module PackageManagement -Force -Scope Global
    }

    $InstalledModule = Import-Module PowerShellGet -PassThru -ErrorAction Ignore
    if (-not (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'})) {
        Write-Host -ForegroundColor Yellow "[-] Install PowerShellGet 2.2.5"
        $PowerShellGetURL = "https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg"
        Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile "$env:TEMP\powershellget.2.2.5.zip"
        $null = New-Item -Path "$env:TEMP\2.2.5" -ItemType Directory -Force
        Expand-Archive -Path "$env:TEMP\powershellget.2.2.5.zip" -DestinationPath "$env:TEMP\2.2.5"
        $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
        Move-Item -Path "$env:TEMP\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
        Import-Module PowerShellGet -Force -Scope Global
    }
}
#endregion

#region Nuget
if ($WindowsPhase -eq 'WinPE') {
    if (Test-Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll") {
        Write-Host -ForegroundColor Green "[+] Nuget 2.8.5.208+"
    }
    else {
        Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider NuGet -MinimumVersion 2.8.5.201"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
    }
}
#endregion

#region PowerShell Gallery

#endregion

#region Install Curl
if (-not (Get-Command 'curl.exe' -ErrorAction SilentlyContinue)) {
    Write-Host -ForegroundColor Yellow "[-] Install Curl 8.1.2 for Windows"
    $Uri = 'https://curl.se/windows/dl-8.1.2_2/curl-8.1.2_2-win64-mingw.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile "$env:TEMP\curl.zip"

    $null = New-Item -Path "$env:TEMP\Curl" -ItemType Directory -Force
    Expand-Archive -Path "$env:TEMP\curl.zip" -DestinationPath "$env:TEMP\curl"

    Get-ChildItem "$env:TEMP\curl" -Include 'curl.exe' -Recurse | foreach {Copy-Item $_ -Destination "$env:SystemRoot\System32\curl.exe"}
}
#endregion

#region WinPE PowerShell Module OSD
if ($WindowsPhase -eq 'WinPE') {
    $InstallModule = $false
    $PSModuleName = 'OSD'
    $InstalledModule = Get-Module -Name $PSModuleName -ListAvailable -ErrorAction Ignore | Sort-Object Version -Descending | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore -WarningAction Ignore

    if ($GalleryPSModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            Write-Host -ForegroundColor Yellow "[-] Install-Module $PSModuleName $($GalleryPSModule.Version)"
            Install-Module $PSModuleName -Scope AllUsers -Force -SkipPublisherCheck
            Import-Module $PSModuleName -Force
        }
    }
    $InstalledModule = Get-Module -Name $PSModuleName -ListAvailable -ErrorAction Ignore | Sort-Object Version -Descending | Select-Object -First 1
    if ($GalleryPSModule) {
        if (($InstalledModule.Version -as [version]) -ge ($GalleryPSModule.Version -as [version])) {
            Write-Host -ForegroundColor Green "[+] $PSModuleName $($GalleryPSModule.Version)"
        }
    }
}
#endregion

#region PowerShell Module Pester
if ($WindowsPhase -eq 'WinPE') {
    #do nothing
}
else {
    $InstallModule = $false
    $PSModuleName = 'Pester'
    $InstalledModule = Get-Module -Name $PSModuleName -ListAvailable -ErrorAction Ignore | Sort-Object Version -Descending | Select-Object -First 1
    $GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore -WarningAction Ignore
    
    if ($GalleryPSModule) {
        if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
            Write-Host -ForegroundColor Yellow "[-] Install-Module $PSModuleName $($GalleryPSModule.Version)"
            Install-Module $PSModuleName -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber
            #Import-Module $PSModuleName -Force
        }
    }
    $InstalledModule = Get-Module -Name $PSModuleName -ListAvailable -ErrorAction Ignore | Sort-Object Version -Descending | Select-Object -First 1
    if ($GalleryPSModule) {
        if (($InstalledModule.Version -as [version]) -ge ($GalleryPSModule.Version -as [version])) {
            Write-Host -ForegroundColor Green "[+] $PSModuleName $($GalleryPSModule.Version)"
        }
    }
}
#endregion

#region PowerShell Module PSReadLine
$InstallModule = $false
$PSModuleName = 'PSReadLine'
$InstalledModule = Get-Module -Name $PSModuleName -ListAvailable -ErrorAction Ignore | Sort-Object Version -Descending | Select-Object -First 1
$GalleryPSModule = Find-Module -Name $PSModuleName -ErrorAction Ignore -WarningAction Ignore

if ($GalleryPSModule) {
    if (($GalleryPSModule.Version -as [version]) -gt ($InstalledModule.Version -as [version])) {
        Write-Host -ForegroundColor Yellow "[-] Install-Module $PSModuleName $($GalleryPSModule.Version)"
        Install-Module $PSModuleName -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber
        #Import-Module $PSModuleName -Force
    }
}
$InstalledModule = Get-Module -Name $PSModuleName -ListAvailable -ErrorAction Ignore | Sort-Object Version -Descending | Select-Object -First 1
if ($GalleryPSModule) {
    if (($InstalledModule.Version -as [version]) -ge ($GalleryPSModule.Version -as [version])) {
        Write-Host -ForegroundColor Green "[+] $PSModuleName $($GalleryPSModule.Version)"
    }
}
#endregion

#WinPE Exit
if ($WindowsPhase -eq 'WinPE') {
    Start PowerShell
    Stop-Transcript
    Break
}
#endregion

#region WinGet
# WinGet is not installed
if (-not (Get-Command 'WinGet' -ErrorAction SilentlyContinue)) {

    # Test if Microsoft.DesktopAppInstaller is present and install it
    if (Get-AppxPackage -Name Microsoft.DesktopAppInstaller) {
        Write-Host -ForegroundColor Yellow "[-] Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
    }
}

# Get Microsoft.DesktopAppInstaller version
$AppxPkg = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($AppxPkg.Version) {
    Write-Host -ForegroundColor Green "[+] Microsoft.DesktopAppInstaller $([string]$AppxPkg.Version)"
}

# Success
$WinGetEXE = Get-Command -Type Application -Name 'winget.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($WinGetEXE) {
    $WinGetVer = & winget.exe --version
    $WinGetVer = $WinGetVer -replace '[a-zA-Z\-]'
    Write-Host -ForegroundColor Green "[+] WinGet $([string]$WinGetVer)"
}
else {
    Write-Host -ForegroundColor Red "[!] WinGet"
}
#endregion

#region PowerShell 7
$PowerShellSeven = Get-ChildItem -Path "$env:ProgramFiles" pwsh.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($PowerShellSeven) {
    Write-Host -ForegroundColor Green "[+] PowerShell $($PowerShellSeven.VersionInfo.FileVersion)"
}
else {
    if ($WinGetEXE) {
        Write-Host -ForegroundColor Yellow "[-] winget install --id Microsoft.PowerShell --exact --scope machine --override '/quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ADD_PATH=1' --accept-source-agreements --accept-package-agreements"
        winget install --id Microsoft.PowerShell --exact --scope machine --override '/quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ADD_PATH=1' --accept-source-agreements --accept-package-agreements
    }
    else {
        Write-Host -ForegroundColor Yellow "[-] Invoke-Expression (Invoke-RestMethod https://aka.ms/install-powershell.ps1)"
        Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI"
    }
    $PowerShellSeven = Get-ChildItem -Path "$env:ProgramFiles" pwsh.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($PowerShellSeven) {
        Write-Host -ForegroundColor Green "[+] PowerShell $($PowerShellSeven.VersionInfo.FileVersion)"
    }
}
#endregion

#region WinGet Upgrade
if ($WinGetEXE) {
    Write-Host -ForegroundColor Green "[+] winget upgrade --all --accept-source-agreements --accept-package-agreements"
    winget upgrade --all --accept-source-agreements --accept-package-agreements
}
#endregion

#Write-Host -ForegroundColor Green "[+] opening PowerShell in a new window"
#start PowerShell

if ($PowerShellSeven) {
    #Write-Host -ForegroundColor Green "[+] opening PowerShell 7 in a new window"
    #start $($PowerShellSeven.FullName)
}

Write-Host -ForegroundColor Green "[+] pwsh.osdcloud.com Complete"
Stop-Transcript