<#
    .SYNOPSIS
    Installs pyenv-win

    .DESCRIPTION
    Installs pyenv-win to $HOME\.pyenv
    If pyenv-win is already installed, try to update to the latest version.

    .PARAMETER Uninstall
    Uninstall pyenv-win. Note that this uninstalls any Python versions that were installed with pyenv-win.

    .INPUTS
    None.

    .OUTPUTS
    None.

    .EXAMPLE
    PS> install-pyenv-win.ps1

    .LINK
    Online version: https://pyenv-win.github.io/pyenv-win/
#>
    
param (
    [Switch] $Uninstall = $False
)
    
$PyEnvDir = "${env:USERPROFILE}\.pyenv"
$PyEnvWinDir = "${PyEnvDir}\pyenv-win"
$BinPath = "${PyEnvWinDir}\bin"
$ShimsPath = "${PyEnvWinDir}\shims"
    
Function Remove-PyEnvVars() {
    $PathParts = [System.Environment]::GetEnvironmentVariable('PATH', "User") -Split ";"
    $NewPathParts = $PathParts.Where{ $_ -ne $BinPath }.Where{ $_ -ne $ShimsPath }
    $NewPath = $NewPathParts -Join ";"
    [System.Environment]::SetEnvironmentVariable('PATH', $NewPath, "User")

    [System.Environment]::SetEnvironmentVariable('PYENV', $null, "User")
    [System.Environment]::SetEnvironmentVariable('PYENV_ROOT', $null, "User")
    [System.Environment]::SetEnvironmentVariable('PYENV_HOME', $null, "User")
}

Function Remove-PyEnv() {
    Write-Host "Removing $PyEnvDir..."
    If (Test-Path $PyEnvDir) {
        Remove-Item -Path $PyEnvDir -Recurse
    }
    Write-Host "Removing environment variables..."
    Remove-PyEnvVars
}

Function Get-PyenvWinGithubBaseUrl() {
#    $BaseUrl = "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master"
    $BaseUrl = "https://raw.githubusercontent.com/adrien-pain-01/pyenv-win-3.1.2/master"

    return $BaseUrl
}

Function Get-PyenvWinGithubZipArchive {
    param ($DownloadPath)

#    $ZipUrl = "https://github.com/pyenv-win/pyenv-win/archive/master.zip"
#    $ZipRootFolder = "pyenv-win-master"
    $ZipUrl = "https://github.com/adrien-pain-01/pyenv-win-3.1.2/archive/refs/heads/master.zip"
    $ZipRootFolder = "pyenv-win-3.1.2-master"

    Invoke-WebRequest -Uri $ZipUrl -OutFile $DownloadPath

    return $ZipRootFolder
}

Function Get-CurrentVersion() {
    $VersionFilePath = "$PyEnvDir\.version"
    If (Test-Path $VersionFilePath) {
        $CurrentVersion = Get-Content $VersionFilePath
    }
    Else {
        $CurrentVersion = ""
    }

    Return $CurrentVersion
}

Function Get-LatestVersion() {
    $LatestVersionFilePath = New-TemporaryFile

    $PyenvWinBaseUrl = "$(Get-PyenvWinGithubBaseUrl)/.version"
    Invoke-WebRequest -Uri $PyenvWinBaseUrl -OutFile $LatestVersionFilePath

    $LatestVersion = Get-Content $LatestVersionFilePath
    Remove-Item -Path $LatestVersionFilePath

    Return $LatestVersion
}

Function Main() {
    # uninstall only and exit
    If ($Uninstall) {
        Remove-PyEnv
        If ($? -eq $True) {
            Write-Host "pyenv-win successfully uninstalled."
        }
        Else {
            Write-Host "Uninstallation failed."
        }
        exit
    }

    # check current vs latest version
    $CurrentVersion = Get-CurrentVersion
    $LatestVersion = Get-LatestVersion

    If ($CurrentVersion -ne "") {
        Write-Host "Found pyenv-win version: $CurrentVersion"

        If ($CurrentVersion -eq $LatestVersion) {
            Write-Host "No updates available."
            exit
        }
        Else {
            Remove-PyEnv
        }
    }

    Write-Host "Installing pyenv-win version: $LatestVersion"

    # create PyenvDir
    New-Item -Path $PyEnvDir -ItemType Directory

    # Download PyenvWin archive (ZIP file)
    $DownloadPath = "$PyEnvDir\pyenv-win.zip"
    $ZipRootFolder = Get-PyenvWinGithubZipArchive $DownloadPath

    # Extract PyenvWin archive
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-Command `"Microsoft.PowerShell.Archive\Expand-Archive -Path \`"$DownloadPath\`" -DestinationPath \`"$PyEnvDir\`"`""
    ) -NoNewWindow -Wait

    Move-Item -Path "$PyEnvDir\$ZipRootFolder\*" -Destination "$PyEnvDir"
    Remove-Item -Path "$PyEnvDir\$ZipRootFolder" -Recurse
    Remove-Item -Path $DownloadPath

    # Update env vars
    [System.Environment]::SetEnvironmentVariable('PYENV', "${PyEnvWinDir}\", "User")
    [System.Environment]::SetEnvironmentVariable('PYENV_ROOT', "${PyEnvWinDir}\", "User")
    [System.Environment]::SetEnvironmentVariable('PYENV_HOME', "${PyEnvWinDir}\", "User")

    $PathParts = [System.Environment]::GetEnvironmentVariable('PATH', "User") -Split ";"

    # Remove existing paths, so we don't add duplicates
    $NewPathParts = $PathParts.Where{ $_ -ne $BinPath }.Where{ $_ -ne $ShimsPath }
    $NewPathParts = ($BinPath, $ShimsPath) + $NewPathParts
    $NewPath = $NewPathParts -Join ";"
    [System.Environment]::SetEnvironmentVariable('PATH', $NewPath, "User")

    If ($? -eq $True) {
        Write-Host "pyenv-win is successfully installed. You may need to close and reopen your terminal before using it."
    }
    Else {
        Write-Host "pyenv-win was not installed successfully. If this issue persists, please open a ticket: https://github.com/pyenv-win/pyenv-win/issues."
    }
}

Main
