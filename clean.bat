@echo off
:: NSC_BUILDER Web UI - clean build & temp artifacts (pairs with the build / start.bat).
:: Removes bin\, obj\, dist\, itest_out\, _verify_out\, stray logs/tmp. Leaves source only.
setlocal
cd /d "%~dp0"

echo dotnet clean (Release)...
dotnet clean -c Release >nul 2>&1

echo removing build caches, publish output, and test/temp artifacts...
for /d /r %%d in (bin obj) do @if exist "%%d" ( echo %%d|findstr /i "node_modules .git" >nul || rmdir /s /q "%%d" )
if exist dist        rmdir /s /q dist
if exist itest_out   rmdir /s /q itest_out
if exist _verify_out rmdir /s /q _verify_out
if exist nohup.out   del /q nohup.out
del /s /q *.log *.tmp 2>nul

echo clean. Remaining = source only.
endlocal
