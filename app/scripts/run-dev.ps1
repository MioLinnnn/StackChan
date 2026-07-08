#Requires -Version 5.1
<#
.SYNOPSIS
  Run StackChan on a connected Android device with Hot Reload support.

.DESCRIPTION
  Wraps flutter pub get + flutter run with local native deps and PATH setup.
  Keep the terminal open after launch; press r to Hot Reload, R to Hot Restart, q to quit.

.EXAMPLE
  .\scripts\run-dev.ps1

.EXAMPLE
  .\scripts\run-dev.ps1 -DeviceId 3B15AJ01ZT500000

.EXAMPLE
  .\scripts\run-dev.ps1 -Clean
#>
param(
    [string]$DeviceId,
    [switch]$Clean,
    [switch]$SkipPubGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$AppRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$AndroidDir = Join-Path $AppRoot "android"
$LocalPropertiesPath = Join-Path $AndroidDir "local.properties"
$KeystorePath = Join-Path $AndroidDir "app\release.jks"
$DepsRoot = Join-Path $env:USERPROFILE ".cache\stackchan-native-deps"

$DefaultFlutterSdk = "C:\DevEnv\Flutter_Env\flutter"
$DefaultAndroidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$ProxyUrl = "http://127.0.0.1:7897"

function Read-LocalProperty {
    param([string]$Name)

    if (-not (Test-Path $LocalPropertiesPath)) {
        return $null
    }

    foreach ($line in Get-Content $LocalPropertiesPath) {
        if ($line -match "^\s*$Name\s*=\s*(.+)\s*$") {
            return $Matches[1].Trim().Trim('"').Replace("\\", "\")
        }
    }

    return $null
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$Destination
    )

    Write-Host "Downloading $Url ..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -Proxy $ProxyUrl -UseBasicParsing
    }
    catch {
        Write-Host "Proxy download failed, retrying without proxy ..."
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    }
}

function Ensure-NativeDeps {
    Ensure-Directory $DepsRoot

    $deps = @(
        @{
            Name = "opus"
            CheckPath = Join-Path $DepsRoot "opus-1.5.2\CMakeLists.txt"
            Archive = Join-Path $DepsRoot "opus-1.5.2.tar.gz"
            Url = "https://github.com/xiph/opus/archive/refs/tags/v1.5.2.tar.gz"
            EnvVar = "FETCHCONTENT_SOURCE_DIR_OPUS"
            SourceDir = Join-Path $DepsRoot "opus-1.5.2"
        },
        @{
            Name = "opencv"
            CheckPath = Join-Path $DepsRoot "libopencv-arm64\sdk\native\jni\OpenCVConfig.cmake"
            Archive = Join-Path $DepsRoot "libopencv-android-arm64-v8a.tar.gz"
            Url = "https://github.com/rainyl/opencv.full/releases/download/4.12.0.0/libopencv-android-arm64-v8a.tar.gz"
            EnvVar = "FETCHCONTENT_SOURCE_DIR_LIBOPENCV"
            SourceDir = Join-Path $DepsRoot "libopencv-arm64"
        },
        @{
            Name = "dartcv"
            CheckPath = Join-Path $DepsRoot "dartcv-4.12.0.2\CMakeLists.txt"
            Archive = Join-Path $DepsRoot "dartcv-4.12.0.2.zip"
            Url = "https://github.com/rainyl/dartcv/archive/refs/tags/4.12.0.2.zip"
            EnvVar = "FETCHCONTENT_SOURCE_DIR_LIBDARTCV"
            SourceDir = Join-Path $DepsRoot "dartcv-4.12.0.2"
            IsZip = $true
        }
    )

    foreach ($dep in $deps) {
        if (-not (Test-Path $dep.CheckPath)) {
            Write-Host "Preparing native dependency: $($dep.Name)"
            if (-not (Test-Path $dep.Archive)) {
                Download-File -Url $dep.Url -Destination $dep.Archive
            }

            if ($dep.IsZip) {
                Expand-Archive -Path $dep.Archive -DestinationPath $DepsRoot -Force
            }
            elseif ($dep.Name -eq "opencv") {
                Ensure-Directory $dep.SourceDir
                tar -xzf $dep.Archive -C $dep.SourceDir
            }
            else {
                tar -xzf $dep.Archive -C $DepsRoot
            }
        }

        if (-not (Test-Path $dep.CheckPath)) {
            throw "Native dependency '$($dep.Name)' is still missing at $($dep.CheckPath)"
        }

        Set-Item -Path "Env:$($dep.EnvVar)" -Value $dep.SourceDir
        Write-Host "$($dep.EnvVar)=$($dep.SourceDir)"
    }
}

function Ensure-Keystore {
    if (Test-Path $KeystorePath) {
        return
    }

    Write-Host "Keystore not found, generating release.jks ..."
    Push-Location (Join-Path $AndroidDir "app")
    try {
        keytool -genkeypair -v `
            -keystore release.jks `
            -storepass 123456 `
            -keypass 123456 `
            -alias key0 `
            -keyalg RSA `
            -keysize 2048 `
            -validity 10000 `
            -dname "CN=StackChan, OU=Dev, O=StackChan, L=Shanghai, S=Shanghai, C=CN"
        Copy-Item .\release.jks .\debug.jks -Force
    }
    finally {
        Pop-Location
    }
}

function Ensure-AndroidDevice {
    $adbOutput = (adb devices 2>&1 | Out-String).Trim()
    $connected = @(
        $adbOutput -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match "^\S+\s+device$" }
    )

    if ($connected.Count -eq 0) {
        throw @"
No Android device detected. Connect a phone via USB and enable USB debugging, then run:
  adb devices
"@
    }

    Write-Host "Connected device(s):"
    foreach ($line in $connected) {
        Write-Host "  $line"
    }
}

Write-Host "App root: $AppRoot"

$flutterSdk = Read-LocalProperty "flutter.sdk"
if (-not $flutterSdk) {
    $flutterSdk = $DefaultFlutterSdk
    Write-Host "flutter.sdk not found in local.properties, using default: $flutterSdk"
}

$androidSdk = Read-LocalProperty "sdk.dir"
if (-not $androidSdk) {
    $androidSdk = $DefaultAndroidSdk
    Write-Host "sdk.dir not found in local.properties, using default: $androidSdk"
}

$flutterBin = Join-Path $flutterSdk "bin"
$platformTools = Join-Path $androidSdk "platform-tools"
$env:Path = "$flutterBin;$platformTools;$env:Path"

Ensure-NativeDeps
Ensure-Keystore
Ensure-AndroidDevice

Push-Location $AppRoot
try {
    if ($Clean) {
        Write-Host "Running flutter clean ..."
        flutter clean
    }

    if (-not $SkipPubGet) {
        Write-Host "Running flutter pub get ..."
        flutter pub get
    }

    $runArgs = @("run")
    if ($DeviceId) {
        $runArgs += @("-d", $DeviceId)
    }

    Write-Host ""
    Write-Host "Starting flutter run (debug mode with Hot Reload) ..."
    Write-Host "  r  = Hot Reload   (apply Dart/UI changes)"
    Write-Host "  R  = Hot Restart  (re-run main(), reset app state)"
    Write-Host "  q  = Quit"
    Write-Host ""

    & flutter @runArgs
}
finally {
    Pop-Location
}
