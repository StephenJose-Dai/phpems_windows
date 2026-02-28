@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
::  phpems 一键部署脚本 (bat 版)
::  支持系统：Windows 10 / Windows 11
:: ============================================================

set "COMPOSE_URL=https://github.com/StephenJose-Dai/phpems_windows/releases/download/20260227_11/docker-compose.yml"
set "COMPOSE_FILE=D:\data\docker-compose.yml"
set "IMAGE_NAME=stephenjose/phpems_windows:11"

:: ---------- 检查管理员权限 ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] 请以管理员身份运行此脚本！
    echo         右键点击脚本 → 以管理员身份运行
    pause
    exit /b 1
)

:: ============================================================
:: 第一步：检测系统与架构
:: ============================================================
echo.
echo ========== 步骤 1/5  检测系统与架构 ==========
echo.

:: 检测 CPU 架构
for /f "tokens=*" %%a in ('wmic cpu get Architecture /value ^| find "="') do set "%%a"
:: Architecture=9 表示 x64
if "%Architecture%" neq "9" (
    echo [ERROR] 当前 CPU 架构不是 x86_64（64位），脚本不支持此架构，退出。
    pause
    exit /b 1
)
echo [OK]    CPU 架构检测通过：x86_64（64位）

:: 检测 Windows 版本（通过 Build 号）
for /f "tokens=*" %%a in ('wmic os get BuildNumber /value ^| find "="') do set "%%a"
set /a BUILD=%BuildNumber%

if %BUILD% lss 10240 (
    echo [ERROR] 当前 Windows Build 号为 %BuildNumber%，不支持此版本。
    echo [ERROR] 仅支持 Windows 10 和 Windows 11，脚本退出。
    pause
    exit /b 1
)

if %BUILD% geq 22000 (
    set "WIN_VER=Windows 11"
) else (
    set "WIN_VER=Windows 10"
)

echo [OK]    系统检测通过：!WIN_VER!（Build %BuildNumber%）

:: ============================================================
:: 第二步：检查依赖工具
:: ============================================================
echo.
echo ========== 步骤 2/5  检查依赖工具 ==========
echo.

:: 检查 Docker
docker version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] 未检测到 Docker 或 Docker 服务未启动。
    echo [ERROR] 请先安装 Docker Desktop for Windows：
    echo         下载地址：https://www.docker.com/products/docker-desktop/
    echo         安装完成后，启动 Docker Desktop，然后重新运行此脚本。
    pause
    exit /b 1
)
echo [OK]    Docker 已安装并运行

:: 检查 Docker Compose
set "COMPOSE_CMD="
docker compose version >nul 2>&1
if %errorlevel% equ 0 (
    set "COMPOSE_CMD=docker compose"
    echo [OK]    Docker Compose 已可用（docker compose）
) else (
    docker-compose version >nul 2>&1
    if %errorlevel% equ 0 (
        set "COMPOSE_CMD=docker-compose"
        echo [OK]    Docker Compose 已可用（docker-compose）
    ) else (
        echo [ERROR] 未检测到 docker compose 或 docker-compose 命令。
        echo [ERROR] 请确保 Docker Desktop 已正确安装并启动。
        echo         下载地址：https://www.docker.com/products/docker-desktop/
        pause
        exit /b 1
    )
)

:: ============================================================
:: 第三步：检查并创建目录结构
:: ============================================================
echo.
echo ========== 步骤 3/5  检查目录结构 ==========
echo.

if not exist "D:\data\mysql" (
    echo [WARN]  目录 D:\data\mysql 不存在，正在创建...
    mkdir "D:\data\mysql"
    echo [OK]    已创建：D:\data\mysql
) else (
    echo [OK]    目录已存在：D:\data\mysql
)

if not exist "D:\data\nginx\logs" (
    echo [WARN]  目录 D:\data\nginx\logs 不存在，正在创建...
    mkdir "D:\data\nginx\logs"
    echo [OK]    已创建：D:\data\nginx\logs
) else (
    echo [OK]    目录已存在：D:\data\nginx\logs
)

:: ============================================================
:: 第四步：选择镜像来源
:: ============================================================
echo.
echo ========== 步骤 4/5  选择镜像来源 ==========
echo.

:CHOOSE_SOURCE
echo 请选择镜像来源：
echo   1) 在线拉取镜像（需要代理）
echo   2) 本地导入镜像
echo.
set /p SOURCE_CHOICE=请输入选项 [1/2]：

if "%SOURCE_CHOICE%"=="1" goto ONLINE_PULL
if "%SOURCE_CHOICE%"=="2" goto LOCAL_IMPORT
echo [WARN]  无效选项，请输入 1 或 2。
goto CHOOSE_SOURCE

:ONLINE_PULL
echo.
echo [WARN]  【注意】在线拉取镜像需要配置代理，否则可能出现拉取失败的情况。
echo.
set /p CONFIRM=确认使用在线拉取方式？[y/N]：
if /i "%CONFIRM%"=="y" (
    echo [INFO]  开始在线拉取镜像：%IMAGE_NAME% ...
    docker pull %IMAGE_NAME%
    if %errorlevel% neq 0 (
        echo [ERROR] 镜像拉取失败，请检查网络或代理配置后重试。
        pause
        exit /b 1
    )
    echo [OK]    镜像拉取完成
    goto START_CONTAINER
) else (
    echo [WARN]  已取消，返回重新选择...
    goto CHOOSE_SOURCE
)

:LOCAL_IMPORT
echo.
:INPUT_IMAGE_DIR
set /p IMAGE_DIR=请输入镜像包所在目录的完整路径（例如 D:\images）：
if not exist "%IMAGE_DIR%" (
    echo [ERROR] 目录 %IMAGE_DIR% 不存在，请重新输入。
    goto INPUT_IMAGE_DIR
)

set "FOUND_FILES=0"
for %%f in ("%IMAGE_DIR%\*.tar" "%IMAGE_DIR%\*.tgz") do (
    if exist "%%f" set /a FOUND_FILES+=1
)

if "%FOUND_FILES%"=="0" (
    echo [ERROR] 在 %IMAGE_DIR% 目录下未找到任何镜像包（.tar / .tgz），请重新输入。
    goto INPUT_IMAGE_DIR
)

echo [INFO]  找到以下镜像包：
for %%f in ("%IMAGE_DIR%\*.tar" "%IMAGE_DIR%\*.tgz") do (
    if exist "%%f" echo   - %%~nxf
)
echo.

for %%f in ("%IMAGE_DIR%\*.tar" "%IMAGE_DIR%\*.tgz") do (
    if exist "%%f" (
        echo [INFO]  正在导入：%%~nxf ...
        docker load -i "%%f"
        if %errorlevel% equ 0 (
            echo [OK]    镜像导入完成：%%~nxf
        ) else (
            echo [ERROR] 镜像导入失败：%%~nxf
        )
    )
)

echo [OK]    所有镜像处理完成

:: ============================================================
:: 第五步：下载 docker-compose.yml 并启动容器
:: ============================================================
:START_CONTAINER
echo.
echo ========== 步骤 5/5  启动容器 ==========
echo.

if not exist "D:\data" mkdir "D:\data"

:: 尝试用 PowerShell 下载 docker-compose.yml
echo [INFO]  正在下载 docker-compose.yml ...
powershell -Command "try { Invoke-WebRequest -Uri '%COMPOSE_URL%' -OutFile '%COMPOSE_FILE%' -TimeoutSec 30 -UseBasicParsing; exit 0 } catch { exit 1 }"

if %errorlevel% equ 0 (
    if exist "%COMPOSE_FILE%" (
        echo [OK]    docker-compose.yml 下载成功：%COMPOSE_FILE%
        goto DO_COMPOSE_UP
    )
)

:: 下载失败，提示手动处理
echo [WARN]  下载失败，可能是网络不稳定。
echo.
echo   您可以手动下载该文件，步骤如下：
echo.
echo   1. 打开浏览器，输入以下地址下载文件：
echo      %COMPOSE_URL%
echo   2. 将下载的 docker-compose.yml 保存到本地
echo   3. 将文件路径填写到下方
echo.

:MANUAL_CONFIRM
set /p MANUAL=是否已手动下载文件？[y/N]：
if /i "%MANUAL%"=="y" goto INPUT_MANUAL_PATH
echo [ERROR] 请先完成文件下载后，再重新执行脚本。
pause
exit /b 1

:INPUT_MANUAL_PATH
set /p MANUAL_PATH=请输入 docker-compose.yml 文件的完整路径：
if not exist "%MANUAL_PATH%" (
    echo [ERROR] 文件 %MANUAL_PATH% 不存在，请确认路径后重新输入。
    goto INPUT_MANUAL_PATH
)
if /i "%MANUAL_PATH%" neq "%COMPOSE_FILE%" (
    copy /y "%MANUAL_PATH%" "%COMPOSE_FILE%" >nul
    echo [OK]    已将文件复制到：%COMPOSE_FILE%
) else (
    echo [OK]    文件路径正确：%COMPOSE_FILE%
)

:DO_COMPOSE_UP
echo [INFO]  正在启动容器，请稍候...
cd /d "D:\data"
%COMPOSE_CMD% -f "%COMPOSE_FILE%" up -d

if %errorlevel% neq 0 (
    echo [ERROR] 容器启动失败，请检查 docker-compose.yml 或 Docker Desktop 是否正常运行。
    pause
    exit /b 1
)

timeout /t 3 /nobreak >nul

:: 检查容器状态
for /f %%a in ('docker ps --filter "name=phpems" --format "{{.Names}}" 2^>nul') do set "RUNNING=%%a"
if not defined RUNNING (
    echo [WARN]  容器可能未正常启动，请执行以下命令检查：
    echo         docker ps -a
    echo         docker logs phpems
)

:: ============================================================
:: 获取宿主机真实 IP
:: ============================================================
set "HOST_IP="
for /f "tokens=*" %%a in ('powershell -Command "$ip = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.InterfaceAlias -notmatch 'Loopback|vEthernet|Bluetooth|VMware|VirtualBox|Teredo|isatap' } | Where-Object { (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue).Status -eq 'Up' } | Sort-Object { if($_.InterfaceAlias -match '以太网|Ethernet'){0} elseif($_.InterfaceAlias -match 'WLAN|Wi-Fi|无线'){1} else{2} } | Select-Object -First 1; if($ip){$ip.IPAddress} else{'<your-ip>'}"') do set "HOST_IP=%%a"

if not defined HOST_IP set "HOST_IP=<your-server-ip>"

:: ============================================================
:: 输出访问信息
:: ============================================================
echo.
echo ============================================================
echo   phpems 部署完成！以下信息仅显示一次，请妥善保存！
echo ============================================================
echo.
echo   访问地址：    http://!HOST_IP!
echo   管理后台：    http://!HOST_IP!/admin
echo.
echo   管理员账号：  peadmin
echo   管理员密码：  peadmin
echo.
echo   数据库账号：  root
echo   数据库密码：  Zdr5NSqnyjAPwNvL
echo   数据库名称：  phpems11
echo.
echo   该信息只显示一次，请立即截图或记录！
echo ============================================================
echo.

pause
endlocal
