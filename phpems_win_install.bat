@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "COMPOSE_URL=https://github.com/StephenJose-Dai/phpems_windows/releases/download/20260227_11/docker-compose.yml"
set "COMPOSE_FILE=D:\data\docker-compose.yml"
set "IMAGE_NAME=stephenjose/phpems_windows:11"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run as Administrator!
    echo         Right-click the script and select "Run as administrator"
    pause
    exit /b 1
)

echo.
echo ========== Step 1/5  Check System and Architecture ==========
echo.

for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-WmiObject Win32_Processor).Architecture"') do set "CPU_ARCH=%%a"
if "%CPU_ARCH%" neq "9" (
    echo [ERROR] CPU is not x86_64. Not supported. Exiting.
    pause
    exit /b 1
)
echo [OK]    CPU architecture OK: x86_64 ^(64-bit^)

for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-WmiObject Win32_OperatingSystem).BuildNumber"') do set "BUILD=%%a"
set /a BUILD_NUM=%BUILD%

if %BUILD_NUM% lss 10240 (
    echo [ERROR] Unsupported Windows version ^(Build %BUILD%^). Only Windows 10 and 11 are supported.
    pause
    exit /b 1
)

if %BUILD_NUM% geq 22000 (
    set "WIN_VER=Windows 11"
) else (
    set "WIN_VER=Windows 10"
)
echo [OK]    OS OK: !WIN_VER! ^(Build %BUILD%^)

echo.
echo ========== Step 2/5  Check Dependencies ==========
echo.

docker version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker not found or not running.
    echo         Please install Docker Desktop: https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
echo [OK]    Docker is installed and running.

set "COMPOSE_CMD="
docker compose version >nul 2>&1
if %errorlevel% equ 0 (
    set "COMPOSE_CMD=docker compose"
    echo [OK]    Docker Compose OK ^(docker compose^)
) else (
    docker-compose version >nul 2>&1
    if %errorlevel% equ 0 (
        set "COMPOSE_CMD=docker-compose"
        echo [OK]    Docker Compose OK ^(docker-compose^)
    ) else (
        echo [ERROR] Docker Compose not found.
        echo         Please install Docker Desktop: https://www.docker.com/products/docker-desktop/
        pause
        exit /b 1
    )
)

echo.
echo ========== Step 3/5  Check Directories ==========
echo.

if not exist "D:\data\mysql" (
    echo [WARN]  Creating: D:\data\mysql
    mkdir "D:\data\mysql"
    echo [OK]    Created: D:\data\mysql
) else (
    echo [OK]    Directory exists: D:\data\mysql
)

if not exist "D:\data\nginx\logs" (
    echo [WARN]  Creating: D:\data\nginx\logs
    mkdir "D:\data\nginx\logs"
    echo [OK]    Created: D:\data\nginx\logs
) else (
    echo [OK]    Directory exists: D:\data\nginx\logs
)

echo.
echo ========== Step 4/5  Select Image Source ==========
echo.

:CHOOSE_SOURCE
echo Please select image source:
echo   1) Pull from Docker Hub ^(requires proxy/VPN^)
echo   2) Load from local file
echo.
set /p SOURCE_CHOICE=Enter [1/2]: 

if "%SOURCE_CHOICE%"=="1" goto ONLINE_PULL
if "%SOURCE_CHOICE%"=="2" goto LOCAL_IMPORT
echo [WARN]  Invalid option. Please enter 1 or 2.
goto CHOOSE_SOURCE

:ONLINE_PULL
echo.
echo [WARN]  Note: You may need a proxy or VPN to pull from Docker Hub.
echo.
set /p CONFIRM=Confirm pull? [y/N]: 
if /i "%CONFIRM%"=="y" (
    echo [INFO]  Pulling image: %IMAGE_NAME% ...
    docker pull %IMAGE_NAME%
    if %errorlevel% neq 0 (
        echo [ERROR] Pull failed. Check your network or proxy settings.
        pause
        exit /b 1
    )
    echo [OK]    Image pulled successfully.
    goto START_CONTAINER
) else (
    echo [WARN]  Cancelled. Please choose again.
    goto CHOOSE_SOURCE
)

:LOCAL_IMPORT
echo.
:INPUT_IMAGE_DIR
set /p IMAGE_DIR=Enter directory path containing image files ^(e.g. D:\images^): 
if not exist "%IMAGE_DIR%" (
    echo [ERROR] Directory not found: %IMAGE_DIR%
    goto INPUT_IMAGE_DIR
)

set "FOUND_FILES=0"
for %%f in ("%IMAGE_DIR%\*.tar" "%IMAGE_DIR%\*.tgz") do (
    if exist "%%f" set /a FOUND_FILES+=1
)

if "%FOUND_FILES%"=="0" (
    echo [ERROR] No image files ^(.tar / .tgz^) found in: %IMAGE_DIR%
    goto INPUT_IMAGE_DIR
)

echo [INFO]  Found image files:
for %%f in ("%IMAGE_DIR%\*.tar" "%IMAGE_DIR%\*.tgz") do (
    if exist "%%f" echo   - %%~nxf
)
echo.

for %%f in ("%IMAGE_DIR%\*.tar" "%IMAGE_DIR%\*.tgz") do (
    if exist "%%f" (
        echo [INFO]  Loading: %%~nxf ...
        docker load -i "%%f"
        if %errorlevel% equ 0 (
            echo [OK]    Loaded: %%~nxf
        ) else (
            echo [ERROR] Failed to load: %%~nxf
        )
    )
)
echo [OK]    All images processed.

:START_CONTAINER
echo.
echo ========== Step 5/5  Start Container ==========
echo.

if not exist "D:\data" mkdir "D:\data"

echo [INFO]  Downloading docker-compose.yml ...
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%COMPOSE_URL%' -OutFile '%COMPOSE_FILE%' -TimeoutSec 30 -UseBasicParsing; exit 0 } catch { exit 1 }"

if %errorlevel% equ 0 (
    if exist "%COMPOSE_FILE%" (
        echo [OK]    Downloaded: %COMPOSE_FILE%
        goto DO_COMPOSE_UP
    )
)

echo [WARN]  Download failed.
echo.
echo   Please download the file manually:
echo   URL: %COMPOSE_URL%
echo.

:MANUAL_CONFIRM
set /p MANUAL=Have you downloaded the file? [y/N]: 
if /i "%MANUAL%"=="y" goto INPUT_MANUAL_PATH
echo [ERROR] Please download the file first, then re-run this script.
pause
exit /b 1

:INPUT_MANUAL_PATH
set /p MANUAL_PATH=Enter full path of docker-compose.yml: 
if not exist "%MANUAL_PATH%" (
    echo [ERROR] File not found: %MANUAL_PATH%
    goto INPUT_MANUAL_PATH
)
if /i "%MANUAL_PATH%" neq "%COMPOSE_FILE%" (
    copy /y "%MANUAL_PATH%" "%COMPOSE_FILE%" >nul
    echo [OK]    Copied to: %COMPOSE_FILE%
) else (
    echo [OK]    File path OK: %COMPOSE_FILE%
)

:DO_COMPOSE_UP
echo [INFO]  Starting container ...
cd /d "D:\data"
%COMPOSE_CMD% -f "%COMPOSE_FILE%" up -d

if %errorlevel% neq 0 (
    echo [ERROR] Container failed to start. Check docker-compose.yml or Docker Desktop.
    pause
    exit /b 1
)

timeout /t 3 /nobreak >nul

for /f %%a in ('docker ps --filter "name=phpems" --format "{{.Names}}" 2^>nul') do set "RUNNING=%%a"
if not defined RUNNING (
    echo [WARN]  Container may not be running. Check with:
    echo         docker ps -a
    echo         docker logs phpems
)

set "HOST_IP="
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "$ip = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.InterfaceAlias -notmatch 'Loopback|vEthernet|Bluetooth|VMware|VirtualBox|Teredo|isatap' } | Where-Object { (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -EA SilentlyContinue).Status -eq 'Up' } | Sort-Object { if($_.InterfaceAlias -match 'Ethernet'){0} elseif($_.InterfaceAlias -match 'WLAN|Wi-Fi'){1} else{2} } | Select-Object -First 1; if($ip){$ip.IPAddress} else{'your-ip'}"`) do set "HOST_IP=%%a"

if not defined HOST_IP set "HOST_IP=your-server-ip"

echo.
echo ============================================================
echo   phpems deployed! Save this information now!
echo ============================================================
echo.
echo   URL:          http://!HOST_IP!
echo   Admin Panel:  http://!HOST_IP!/admin
echo.
echo   Admin User:   peadmin
echo   Admin Pass:   peadmin
echo.
echo   DB User:      root
echo   DB Pass:      Zdr5NSqnyjAPwNvL
echo   DB Name:      phpems11
echo.
echo   This info is only shown once. Please take a screenshot!
echo ============================================================
echo.

pause
endlocal
