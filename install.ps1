# ============================================================
#  phpems 一键部署脚本 (PowerShell 版)
#  支持系统：Windows 10 / Windows 11
# ============================================================

# 需要管理员权限运行
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# ---------- 颜色输出函数 ----------
function Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Title   { param($msg) Write-Host "`n========== $msg ==========`n" -ForegroundColor Cyan }

$COMPOSE_URL  = "https://github.com/StephenJose-Dai/phpems_windows/releases/download/20260227_11/docker-compose.yml"
$COMPOSE_FILE = "D:\data\docker-compose.yml"

# ============================================================
# 第一步：检测系统与架构
# ============================================================
Title "步骤 1/5  检测系统与架构"

# 检测 CPU 架构
$arch = (Get-WmiObject Win32_Processor).AddressWidth
$archName = (Get-WmiObject Win32_Processor).Architecture
# Architecture: 9 = x64, 5 = ARM, 0 = x86
if ($archName -ne 9) {
    Err "当前 CPU 架构不是 x86_64（64位），脚本不支持此架构，退出。"
    exit 1
}
Success "CPU 架构检测通过：x86_64 (64位)"

# 检测 Windows 版本
$osInfo = Get-WmiObject Win32_OperatingSystem
$osBuild = [int]$osInfo.BuildNumber
$osCaption = $osInfo.Caption

# Windows 10 Build >= 10240, Windows 11 Build >= 22000
if ($osBuild -lt 10240) {
    Err "当前系统：$osCaption（Build $osBuild）"
    Err "不支持此 Windows 版本，仅支持 Windows 10 和 Windows 11，脚本退出。"
    exit 1
}

if ($osBuild -ge 22000) {
    $winVer = "Windows 11"
} elseif ($osBuild -ge 10240) {
    $winVer = "Windows 10"
} else {
    Err "无法识别 Windows 版本，脚本退出。"
    exit 1
}

Success "系统检测通过：$osCaption（$winVer，Build $osBuild）"

# ============================================================
# 第二步：检查依赖工具
# ============================================================
Title "步骤 2/5  检查依赖工具"

# 检查 Docker
$dockerOk = $false
try {
    $dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
    if ($dockerVersion) {
        Success "Docker 已安装：版本 $dockerVersion"
        $dockerOk = $true
    }
} catch {
    $dockerOk = $false
}

if (-not $dockerOk) {
    Err "未检测到 Docker 或 Docker 服务未启动。"
    Err "请先安装 Docker Desktop for Windows："
    Write-Host "  下载地址：https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    Write-Host "  安装完成后，启动 Docker Desktop，然后重新运行此脚本。" -ForegroundColor Yellow
    exit 1
}

# 检查 Docker Compose
$composeCmd = ""
try {
    docker compose version 2>$null | Out-Null
    $composeCmd = "docker compose"
    Success "Docker Compose 已可用（docker compose）"
} catch {
    try {
        docker-compose version 2>$null | Out-Null
        $composeCmd = "docker-compose"
        Success "Docker Compose 已可用（docker-compose）"
    } catch {
        Err "未检测到 docker compose 或 docker-compose 命令。"
        Err "请确保 Docker Desktop 已正确安装并启动，其中已内置 Docker Compose。"
        Err "下载地址：https://www.docker.com/products/docker-desktop/"
        exit 1
    }
}

# ============================================================
# 第三步：检查并创建目录结构
# ============================================================
Title "步骤 3/5  检查目录结构"

$requiredDirs = @(
    "D:\data\mysql",
    "D:\data\nginx\logs"
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        Warn "目录 $dir 不存在，正在创建..."
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Success "已创建：$dir"
    } else {
        Success "目录已存在：$dir"
    }
}

# ============================================================
# 第四步：选择镜像来源
# ============================================================
Title "步骤 4/5  选择镜像来源"

$IMAGE_NAME = "stephenjose/phpems_windows:11"

function Choose-ImageSource {
    while ($true) {
        Write-Host ""
        Write-Host "请选择镜像来源："
        Write-Host "  1) 在线拉取镜像（需要代理）"
        Write-Host "  2) 本地导入镜像"
        Write-Host ""
        $choice = Read-Host "请输入选项 [1/2]"

        switch ($choice) {
            "1" {
                Warn "【注意】在线拉取镜像需要配置代理，否则可能出现拉取失败的情况。"
                Write-Host ""
                $confirm = Read-Host "确认使用在线拉取方式？[y/N]"
                if ($confirm -match "^[yY]$") {
                    Info "开始在线拉取镜像：$IMAGE_NAME ..."
                    docker pull $IMAGE_NAME
                    if ($LASTEXITCODE -ne 0) {
                        Err "镜像拉取失败，请检查网络或代理配置后重试。"
                        exit 1
                    }
                    Success "镜像拉取完成：$IMAGE_NAME"
                    return
                } else {
                    Warn "已取消，返回重新选择..."
                    continue
                }
            }
            "2" {
                while ($true) {
                    Write-Host ""
                    $imageDir = Read-Host "请输入镜像包所在目录的完整路径（例如 D:\images）"
                    if (-not (Test-Path $imageDir)) {
                        Err "目录 $imageDir 不存在，请重新输入。"
                        continue
                    }

                    $imageFiles = Get-ChildItem -Path $imageDir -MaxDepth 1 -File | Where-Object {
                        $_.Extension -match "\.(tar|gz|tgz)$" -or $_.Name -match "\.tar\.gz$"
                    }

                    if ($imageFiles.Count -eq 0) {
                        Err "在 $imageDir 目录下未找到任何镜像包（.tar / .tar.gz / .tgz），请重新输入。"
                        continue
                    }

                    Info "在 $imageDir 下找到以下镜像包，共 $($imageFiles.Count) 个："
                    foreach ($f in $imageFiles) {
                        Write-Host "  - $($f.Name)"
                    }
                    Write-Host ""

                    foreach ($imageFile in $imageFiles) {
                        Info "正在导入：$($imageFile.Name) ..."
                        docker load -i $imageFile.FullName
                        if ($LASTEXITCODE -eq 0) {
                            Success "镜像导入完成：$($imageFile.Name)"
                        } else {
                            Err "镜像导入失败：$($imageFile.Name)"
                        }
                    }

                    Success "所有镜像处理完成"
                    return
                }
            }
            default {
                Warn "无效选项，请输入 1 或 2。"
            }
        }
    }
}

Choose-ImageSource

# ============================================================
# 第五步：下载 docker-compose.yml 并启动容器
# ============================================================
Title "步骤 5/5  启动容器"

# 确保 D:\data 目录存在
if (-not (Test-Path "D:\data")) {
    New-Item -ItemType Directory -Path "D:\data" -Force | Out-Null
}

# 生成 docker-compose.yml 内容（如果下载失败则使用内置模板）
$composeContent = @"
services:
  phpems:
    image: stephenjose/phpems_windows:11
    container_name: phpems
    restart: always
    ports:
      - "80:80"
    volumes:
      - mysql_data:/data/mysql
      - D:/data/nginx/logs:/data/nginx/logs

volumes:
  mysql_data:
"@

# 尝试下载 docker-compose.yml
$downloadOk = $false
Info "正在下载 docker-compose.yml ..."
try {
    Invoke-WebRequest -Uri $COMPOSE_URL -OutFile $COMPOSE_FILE -TimeoutSec 30 -UseBasicParsing
    if (Test-Path $COMPOSE_FILE) {
        Success "docker-compose.yml 下载成功：$COMPOSE_FILE"
        $downloadOk = $true
    }
} catch {
    $downloadOk = $false
}

if (-not $downloadOk) {
    Warn "下载失败，可能是网络不稳定。"
    Write-Host ""
    Write-Host "  您可以选择手动下载该文件，操作步骤如下：" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. 打开浏览器，输入以下地址下载文件：" -ForegroundColor Bold
    Write-Host "     $COMPOSE_URL" -ForegroundColor Cyan
    Write-Host "  2. 将下载的 docker-compose.yml 保存到本地" -ForegroundColor White
    Write-Host "  3. 将文件路径填写到下方" -ForegroundColor White
    Write-Host ""

    while ($true) {
        $manualConfirm = Read-Host "是否已手动下载文件？[y/N]"
        if ($manualConfirm -match "^[yY]$") {
            while ($true) {
                $manualPath = Read-Host "请输入 docker-compose.yml 文件的完整路径（例如 C:\Users\你的用户名\Downloads\docker-compose.yml）"
                if (-not (Test-Path $manualPath)) {
                    Err "文件 $manualPath 不存在，请确认路径后重新输入。"
                    continue
                }
                if ($manualPath -ne $COMPOSE_FILE) {
                    Copy-Item -Path $manualPath -Destination $COMPOSE_FILE -Force
                    Success "已将文件复制到：$COMPOSE_FILE"
                } else {
                    Success "文件路径正确：$COMPOSE_FILE"
                }
                $downloadOk = $true
                break
            }
            break
        } else {
            Err "请先完成文件下载后，再重新执行脚本。"
            exit 1
        }
    }
}

# 启动容器
Info "正在启动容器，请稍候..."
Set-Location "D:\data"

if ($composeCmd -eq "docker compose") {
    docker compose -f $COMPOSE_FILE up -d
} else {
    docker-compose -f $COMPOSE_FILE up -d
}

if ($LASTEXITCODE -ne 0) {
    Err "容器启动失败，请检查 docker-compose.yml 配置或 Docker Desktop 是否正常运行。"
    exit 1
}

Start-Sleep -Seconds 3

# 检查容器是否正常运行
$running = docker ps --filter "name=phpems" --format "{{.Names}}" 2>$null
if (-not $running) {
    Warn "容器可能未正常启动，请执行以下命令检查："
    Warn "  docker ps -a"
    Warn "  docker logs phpems"
}

# ============================================================
# 获取宿主机真实 IP
# ============================================================
$hostIP = $null

# 获取所有活动的、非虚拟的网络适配器 IP
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -ne "127.0.0.1" -and
    $_.PrefixOrigin -ne "WellKnown" -and
    $_.InterfaceAlias -notmatch "Loopback" -and
    $_.InterfaceAlias -notmatch "vEthernet" -and
    $_.InterfaceAlias -notmatch "Bluetooth" -and
    $_.InterfaceAlias -notmatch "VMware" -and
    $_.InterfaceAlias -notmatch "VirtualBox" -and
    $_.InterfaceAlias -notmatch "Teredo" -and
    $_.InterfaceAlias -notmatch "isatap" -and
    $_.InterfaceAlias -notmatch "6to4"
} | Where-Object {
    # 只保留已连接状态的网卡
    $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
    $adapter -and $adapter.Status -eq "Up"
}

if ($adapters) {
    # 优先选以太网，其次 WLAN
    $preferred = $adapters | Where-Object { $_.InterfaceAlias -match "以太网|Ethernet" } | Select-Object -First 1
    if (-not $preferred) {
        $preferred = $adapters | Where-Object { $_.InterfaceAlias -match "WLAN|Wi-Fi|无线" } | Select-Object -First 1
    }
    if (-not $preferred) {
        $preferred = $adapters | Select-Object -First 1
    }
    $hostIP = $preferred.IPAddress
}

if (-not $hostIP) {
    $hostIP = "<your-server-ip>"
}

# ============================================================
# 输出访问信息
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  phpems 部署完成！以下信息仅显示一次，请妥善保存！" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  访问地址：    http://$hostIP" -ForegroundColor White
Write-Host "  管理后台：    http://$hostIP/admin" -ForegroundColor White
Write-Host ""
Write-Host "  管理员账号：  peadmin" -ForegroundColor White
Write-Host "  管理员密码：  peadmin" -ForegroundColor White
Write-Host ""
Write-Host "  数据库账号：  root" -ForegroundColor White
Write-Host "  数据库密码：  Zdr5NSqnyjAPwNvL" -ForegroundColor White
Write-Host "  数据库名称：  phpems11" -ForegroundColor White
Write-Host ""
Write-Host "  ⚠️  该信息只显示一次，请立即截图或记录！" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
