# phpems deploy script
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

function Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Title   { param($msg) Write-Host "" ; Write-Host "========== $msg ==========" -ForegroundColor Cyan ; Write-Host "" }

$COMPOSE_URL  = "https://github.com/StephenJose-Dai/phpems_windows/releases/download/20260227_11/docker-compose.yml"
$COMPOSE_FILE = "D:\data\docker-compose.yml"
$IMAGE_NAME   = "stephenjose/phpems_windows:11"

# Step 1
Title "Step 1/5  Check System and Architecture"

$archName = (Get-WmiObject Win32_Processor).Architecture
if ($archName -ne 9) {
    Err "CPU is not x86_64 (64-bit). Not supported. Exiting."
    exit 1
}
Success "CPU architecture OK: x86_64 (64-bit)"

$osInfo    = Get-WmiObject Win32_OperatingSystem
$osBuild   = [int]$osInfo.BuildNumber
$osCaption = $osInfo.Caption

if ($osBuild -lt 10240) {
    Err "Unsupported Windows version: $osCaption (Build $osBuild)"
    Err "Only Windows 10 and Windows 11 are supported."
    exit 1
}

if ($osBuild -ge 22000) {
    $winVer = "Windows 11"
} else {
    $winVer = "Windows 10"
}
Success "OS OK: $osCaption ($winVer, Build $osBuild)"

# Step 2
Title "Step 2/5  Check Dependencies"

$dockerOk = $false
try {
    $null = docker version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerOk = $true
        Success "Docker is installed and running."
    }
} catch {
    $dockerOk = $false
}

if (-not $dockerOk) {
    Err "Docker not found or not running."
    Write-Host "  Please install Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

$composeCmd = ""
$null = docker compose version 2>&1
if ($LASTEXITCODE -eq 0) {
    $composeCmd = "docker compose"
    Success "Docker Compose OK (docker compose)"
} else {
    $null = docker-compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $composeCmd = "docker-compose"
        Success "Docker Compose OK (docker-compose)"
    } else {
        Err "Docker Compose not found."
        Write-Host "  Please install Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
        exit 1
    }
}

# Step 3
Title "Step 3/5  Check Directories"

$dirs = @("D:\data\mysql", "D:\data\nginx\logs")
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        Warn "Directory not found, creating: $dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Success "Created: $dir"
    } else {
        Success "Directory exists: $dir"
    }
}

# Step 4
Title "Step 4/5  Select Image Source"

$sourceSelected = $false
while (-not $sourceSelected) {
    Write-Host ""
    Write-Host "Please select image source:"
    Write-Host "  1) Pull from Docker Hub (requires proxy/VPN)"
    Write-Host "  2) Load from local file"
    Write-Host ""
    $choice = Read-Host "Enter [1/2]"

    if ($choice -eq "1") {
        Warn "Note: You may need a proxy to pull from Docker Hub."
        Write-Host ""
        $confirm = Read-Host "Confirm pull? [y/N]"
        if ($confirm -match "^[yY]$") {
            Info "Pulling image: $IMAGE_NAME ..."
            docker pull $IMAGE_NAME
            if ($LASTEXITCODE -ne 0) {
                Err "Pull failed. Please check your network or proxy settings."
                exit 1
            }
            Success "Image pulled: $IMAGE_NAME"
            $sourceSelected = $true
        } else {
            Warn "Cancelled. Please choose again."
        }
    } elseif ($choice -eq "2") {
        $dirSelected = $false
        while (-not $dirSelected) {
            Write-Host ""
            $imageDir = Read-Host "Enter the directory path containing image files (e.g. D:\images)"
            if (-not (Test-Path $imageDir)) {
                Err "Directory not found: $imageDir"
                continue
            }
            $imageFiles = Get-ChildItem -Path $imageDir -File | Where-Object { $_.Name -match "\.(tar|tar\.gz|tgz)$" }
            if ($imageFiles.Count -eq 0) {
                Err "No image files (.tar / .tar.gz / .tgz) found in: $imageDir"
                continue
            }
            Info "Found $($imageFiles.Count) image file(s):"
            foreach ($f in $imageFiles) { Write-Host "  - $($f.Name)" }
            Write-Host ""
            foreach ($f in $imageFiles) {
                Info "Loading: $($f.Name) ..."
                docker load -i $f.FullName
                if ($LASTEXITCODE -eq 0) {
                    Success "Loaded: $($f.Name)"
                } else {
                    Err "Failed to load: $($f.Name)"
                }
            }
            Success "All images processed."
            $dirSelected = $true
        }
        $sourceSelected = $true
    } else {
        Warn "Invalid option. Please enter 1 or 2."
    }
}

# Step 5
Title "Step 5/5  Start Container"

if (-not (Test-Path "D:\data")) {
    New-Item -ItemType Directory -Path "D:\data" -Force | Out-Null
}

$downloadOk = $false
Info "Downloading docker-compose.yml ..."
try {
    Invoke-WebRequest -Uri $COMPOSE_URL -OutFile $COMPOSE_FILE -TimeoutSec 30 -UseBasicParsing
    if (Test-Path $COMPOSE_FILE) {
        Success "Downloaded: $COMPOSE_FILE"
        $downloadOk = $true
    }
} catch {
    $downloadOk = $false
}

if (-not $downloadOk) {
    Warn "Download failed."
    Write-Host ""
    Write-Host "  Please download the file manually:" -ForegroundColor White
    Write-Host "  URL: $COMPOSE_URL" -ForegroundColor Cyan
    Write-Host ""
    $confirmed = $false
    while (-not $confirmed) {
        $ans = Read-Host "Have you downloaded the file? [y/N]"
        if ($ans -match "^[yY]$") {
            $pathOk = $false
            while (-not $pathOk) {
                $manualPath = Read-Host "Enter full path of docker-compose.yml"
                if (-not (Test-Path $manualPath)) {
                    Err "File not found: $manualPath"
                    continue
                }
                if ($manualPath -ne $COMPOSE_FILE) {
                    Copy-Item -Path $manualPath -Destination $COMPOSE_FILE -Force
                    Success "Copied to: $COMPOSE_FILE"
                } else {
                    Success "File path OK: $COMPOSE_FILE"
                }
                $pathOk = $true
            }
            $confirmed = $true
        } else {
            Err "Please download the file first, then re-run this script."
            exit 1
        }
    }
}

Info "Starting container ..."
Set-Location "D:\data"

if ($composeCmd -eq "docker compose") {
    docker compose -f $COMPOSE_FILE up -d
} else {
    docker-compose -f $COMPOSE_FILE up -d
}

if ($LASTEXITCODE -ne 0) {
    Err "Container failed to start. Check docker-compose.yml or Docker Desktop."
    exit 1
}

Start-Sleep -Seconds 3

$running = docker ps --filter "name=phpems" --format "{{.Names}}" 2>$null
if (-not $running) {
    Warn "Container may not be running. Check with:"
    Warn "  docker ps -a"
    Warn "  docker logs phpems"
}

# Get Host IP
$hostIP = $null
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -ne "127.0.0.1" -and
    $_.PrefixOrigin -ne "WellKnown" -and
    $_.InterfaceAlias -notmatch "Loopback|vEthernet|Bluetooth|VMware|VirtualBox|Teredo|isatap|6to4"
} | Where-Object {
    $a = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
    $a -and $a.Status -eq "Up"
}

if ($adapters) {
    $preferred = $adapters | Where-Object { $_.InterfaceAlias -match "Ethernet" } | Select-Object -First 1
    if (-not $preferred) { $preferred = $adapters | Where-Object { $_.InterfaceAlias -match "WLAN|Wi-Fi" } | Select-Object -First 1 }
    if (-not $preferred) { $preferred = $adapters | Select-Object -First 1 }
    $hostIP = $preferred.IPAddress
}
if (-not $hostIP) { $hostIP = "<your-ip>" }

# Print result
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  phpems deployed! Save this information now!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  URL:           http://$hostIP" -ForegroundColor White
Write-Host "  Admin Panel:   http://$hostIP/admin" -ForegroundColor White
Write-Host ""
Write-Host "  Admin User:    peadmin" -ForegroundColor White
Write-Host "  Admin Pass:    peadmin" -ForegroundColor White
Write-Host ""
Write-Host "  DB User:       root" -ForegroundColor White
Write-Host "  DB Pass:       Zdr5NSqnyjAPwNvL" -ForegroundColor White
Write-Host "  DB Name:       phpems11" -ForegroundColor White
Write-Host ""
Write-Host "  This info is only shown once. Please take a screenshot!" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
