@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.01 -- Profile: %ofile_name% -- by JulesOnTheRoad

:MAIN
cls
call :program_logo
ECHO .......................................................
echo 输入"1"，进入下载模式
echo 输入"2"，进入文件信息模式
echo 输入"0"，进入配置选项
echo.
echo 输入"N"，转到新模式
echo 输入"M"，转到MTP模式
echo 输入"D"，转到谷歌网盘模式
echo 输入"L"，转到传统模式
echo .......................................................
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="1" goto DOWNLOADMODE
if /i "%bs%"=="2" goto INFMODE
if /i "%bs%"=="N" goto call_main
if /i "%bs%"=="L" goto LegacyMode
if /i "%bs%"=="M" goto MTPMode
if /i "%bs%"=="0" goto OPT_CONFIG
goto MAIN

:LegacyMode
call "%prog_dir%ztools\LEGACY.bat"
exit /B

:MTPMode
call "%prog_dir%ztools\MtpMode.bat"
exit /B

:DOWNLOADMODE
cls
call :program_logo
%pycommand% "%squirrel_lb%" -lib_call Drive.Download Interface
goto MAIN

:INFMODE
cls
call :program_logo
%pycommand% "%squirrel_lb%" -lib_call Drive.Info Interface
goto MAIN

::///////////////////////////////////////////////////
::NSCB_options.cmd 配置脚本
::///////////////////////////////////////////////////
:OPT_CONFIG
call "%batconfig%" "%op_file%" "%listmanager%" "%batdepend%"
cls
goto TOP_INIT

::///////////////////////////////////////////////////
::子路径
::///////////////////////////////////////////////////

:squirrell
echo                    ,;:;;,
echo                   ;;;;;
echo           .=',    ;:;;:,
echo          /_', "=. ';:;:;
echo          @=:__,  \,;:;:'
echo            _(\.=  ;:;;'
echo           `"_(  _/="`
echo            `"'
exit /B

:program_logo

ECHO                                        __          _ __    __
ECHO                  ____  _____ ____     / /_  __  __(_) /___/ /__  _____
ECHO                 / __ \/ ___/ ___/    / __ \/ / / / / / __  / _ \/ ___/
ECHO                / / / (__  ) /__     / /_/ / /_/ / / / /_/ /  __/ /
ECHO               /_/ /_/____/\___/____/_.___/\__,_/_/_/\__,_/\___/_/
ECHO                              /_____/
ECHO -------------------------------------------------------------------------------------
ECHO                         NINTENDO SWITCH CLEANER AND BUILDER
ECHO                      (THE XCI MULTI CONTENT BUILDER AND MORE)
ECHO -------------------------------------------------------------------------------------
ECHO =============================     BY JULESONTHEROAD     =============================
ECHO -------------------------------------------------------------------------------------
ECHO "                                POWERED BY SQUIRREL                                "
ECHO "                    BASED ON THE WORK OF BLAWAR AND LUCA FRAGA                     "
ECHO                                  VERSION 1.01 (GDRIVE)
ECHO -------------------------------------------------------------------------------------
ECHO Program's github: https://github.com/julesontheroad/NSC_BUILDER
ECHO Blawar's github:  https://github.com/blawar
ECHO Luca Fraga's github: https://github.com/LucaFraga
ECHO -------------------------------------------------------------------------------------
exit /B

:delay
PING -n 2 127.0.0.1 >NUL 2>&1
exit /B

:thumbup
echo.
echo    /@
echo    \ \
echo  ___\ \
echo (__O)  \
echo (____@) \
echo (____@)  \
echo (__o)_    \
echo       \    \
echo.
echo 希望您玩的开心
exit /B

:call_main
call "%prog_dir%\NSCB.bat"
exit /B

:salida
::pause
exit
