@echo off
:: NSC_BUILDER Web UI – one-click start (Windows)
:: Builds (first time) and launches the server; browser opens automatically.
setlocal
cd /d "%~dp0"

set PORT=54321
set URL=http://127.0.0.1:%PORT%
set EXE=dist\win-x64\NscbServer.exe

if exist "%EXE%" goto :run

echo Building NSC_BUILDER Web UI (first time, ~30s)...
dotnet publish src\NscbServer\NscbServer.csproj -c Release -f net10.0-windows -o dist\win-x64 -v quiet
if errorlevel 1 ( echo Build failed. & pause & exit /b 1 )
echo Build done.

:run
echo Starting server on %URL%  (close this window to stop)
start "" "%URL%"
"%EXE%" --urls http://127.0.0.1:%PORT%
