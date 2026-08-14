@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem One-click stable/pre Windows amd64 ZIP build for FlClash.
for %%I in ("%~dp0.") do set "ROOT=%%~fI"
pushd "%ROOT%" >nul || goto :error

set "APP_ENV=%~1"
set "INTERACTIVE=0"
if not defined APP_ENV (
  set "INTERACTIVE=1"
  echo Select application environment:
  echo   1. stable ^(official/release build^)
  echo   2. pre    ^(prerelease/test build^)
  set /p "ENV_CHOICE=Enter 1 or 2 [1]: "
  if "!ENV_CHOICE!"=="2" (
    set "APP_ENV=pre"
  ) else (
    set "APP_ENV=stable"
  )
)

if /I "%APP_ENV%"=="stable" (
  set "APP_ENV=stable"
) else if /I "%APP_ENV%"=="pre" (
  set "APP_ENV=pre"
) else (
  echo [ERROR] Invalid environment "%APP_ENV%". Use stable or pre.
  goto :error
)

set "FLUTTER_BIN="
if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER_BIN=%FLUTTER_ROOT%\bin"
if not defined FLUTTER_BIN if exist "D:\Codex\tools\flutter\bin\flutter.bat" set "FLUTTER_BIN=D:\Codex\tools\flutter\bin"
if not defined FLUTTER_BIN if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\fvm\default\bin\flutter.bat" set "FLUTTER_BIN=%LOCALAPPDATA%\fvm\default\bin"

if not defined FLUTTER_BIN (
  echo [ERROR] Flutter SDK was not found.
  echo Set FLUTTER_ROOT to the Flutter SDK directory, then run this file again.
  goto :error
)

set "PATH=%FLUTTER_BIN%;%LOCALAPPDATA%\Pub\Cache\bin;%PATH%"

where dart >nul 2>nul || (
  echo [ERROR] dart was not found after configuring the Flutter SDK.
  goto :error
)

echo.
echo ================================================
echo  FlClash %APP_ENV% Windows amd64 ZIP build
echo  Root: %CD%
echo ================================================
echo.

call flutter pub get || goto :error

pushd "plugins\setup\buildkit\build_tool" >nul || goto :error
call dart run build_tool windows --root-dir "%ROOT%" || (
  popd >nul
  goto :error
)
popd >nul

for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "(Get-Content -Raw 'core_sha256.json' | ConvertFrom-Json).CORE_SHA256"`) do set "CORE_SHA256=%%S"
if not defined CORE_SHA256 (
  echo [ERROR] The Windows core SHA-256 was not generated.
  goto :error
)

> env.json echo {"APP_ENV":"%APP_ENV%","CORE_SHA256":"%CORE_SHA256%"}
set "RELEASE_DIR=%CD%\build\windows\x64\runner\Release"
for /d %%D in ("%RELEASE_DIR%\FlClash-*-windows-amd64") do (
  if exist "%%~fD" rmdir /s /q "%%~fD"
)
call flutter build windows --release --dart-define-from-file=env.json || goto :error

if not exist "dist" mkdir "dist" || goto :error
for /f "tokens=1 delims=+" %%V in ('powershell -NoProfile -Command "(Select-String -Path pubspec.yaml -Pattern '^version:\s*').Line.Split(':')[1].Trim()"') do set "VERSION=%%V"
if not defined VERSION set "VERSION=unknown"
if "%APP_ENV%"=="pre" (
  set "ZIP_FILE=%CD%\dist\FlClash-%VERSION%-pre-windows-amd64.zip"
) else (
  set "ZIP_FILE=%CD%\dist\FlClash-%VERSION%-windows-amd64.zip"
)
set "RELEASE_DIR=%CD%\build\windows\x64\runner\Release"
if not exist "%RELEASE_DIR%\FlClash.exe" (
  echo [ERROR] Windows release files were not produced.
  goto :error
)

powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; if (Test-Path -LiteralPath '%ZIP_FILE%') { Remove-Item -LiteralPath '%ZIP_FILE%' -Force }; [System.IO.Compression.ZipFile]::CreateFromDirectory('%RELEASE_DIR%', '%ZIP_FILE%', [System.IO.Compression.CompressionLevel]::Optimal, $false)" || goto :error
powershell -NoProfile -Command "[BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes('%ZIP_FILE%'))).Replace('-', '') | Set-Content -NoNewline '%ZIP_FILE%.sha256.txt'" || goto :error

echo.
echo [OK] Windows amd64 ZIP:
echo %ZIP_FILE%
echo SHA-256 file:
echo %ZIP_FILE%.sha256.txt
echo.
popd >nul
if "%INTERACTIVE%"=="1" pause
exit /b 0

:error
set "EXIT_CODE=%ERRORLEVEL%"
if "%EXIT_CODE%"=="0" set "EXIT_CODE=1"
echo.
echo [FAILED] Build stopped with exit code %EXIT_CODE%.
popd >nul 2>nul
if "%INTERACTIVE%"=="1" pause
exit /b %EXIT_CODE%
