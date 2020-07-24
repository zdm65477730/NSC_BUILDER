@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.00c -- Profile: %ofile_name% -- by JulesOnTheRoad

:MAIN
if exist "MTP2GD.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (MTP2GD.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (MTP2GD.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del MTP2GD.txt )
endlocal
if not exist "MTP2GD.txt" goto manual_INIT
ECHO .......................................................
ECHO 找到一个上一个列表。你想做什么？
:prevlist0
ECHO .......................................................
echo 输入"1"，自动从上一个列表开始处理
echo 输入"2"，以删除列表并创建一个新列表
echo 输入"3"，继续建立上一个列表
echo .......................................................
echo 注意：按3，您将在开始处理文件之前看到上一个列表，并且可以从列表中添加和删除项目
echo.
ECHO *************************************************
echo 或者输入"0"，返回到模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="3" goto showlist
if /i "%bs%"=="2" goto delist
if /i "%bs%"=="1" goto START_TRANSFER
if /i "%bs%"=="0" call "%prog_dir%ztools\MtpMode.bat"
echo.
echo 错误的选择
goto prevlist0
:delist
del MTP2GD.txt
cls
call :program_logo
echo -------------------------------------------------
echo MTP - 从谷歌网盘传输
echo -------------------------------------------------
echo ..................................
echo 您决定开始新的列表
echo ..................................

:manual_INIT
endlocal
cls
call :program_logo
echo *******************************************************
echo 选择功能
echo *******************************************************
echo.
echo 输入"1"，从缓存文件中选择文件
echo 输入"2"，通过本地文件库，将文件添加到列表
echo 输入"3"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"c"，为远程库重新生成缓存
ECHO.
echo --- 或输入GDRIVE公共链接或1FICHIER链接 ---	
echo.
ECHO *************************************************
echo 或者输入"0"，返回到模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" --mtp_eval_link "%prog_dir%MTP2GD.txt" "%uinput%"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" ( %pycommand% "%squirrel%" -lib_call picker_walker remote_select_from_cache -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call picker_walker remote_select_from_libraries -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="3" ( %pycommand% "%squirrel%" -lib_call picker_walker remote_select_from_walker -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="c" ( %pycommand% "%squirrel%" -lib_call workers concurrent_cache )
echo.
goto checkagain

:checkagain
echo 你想做什么？
echo ......................................................................
echo “拖动其他文件或文件夹，然后按回车将项目添加到列表中”
echo.
echo 输入"1"，开始安装
echo 输入"2"，以从缓存文件中选择文件
echo 输入"3"，通过本地文件库，将文件添加到列表
echo 输入"4"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"c"，为远程库重新生成缓存
echo 输入"e"，退出
echo 输入"i"，以查看要处理的文件列表
echo 输入"r"，删除一些文件（从下往上数）
echo 输入"z"，删除整个列表
ECHO.
echo --- 或输入GDRIVE公共链接或1FICHIER链接 ---		
echo.
ECHO *************************************************
echo 或者输入"0"，返回到模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" --mtp_eval_link "%prog_dir%MTP2GD.txt" "%uinput%"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" goto START_TRANSFER
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call picker_walker remote_select_from_cache -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="3" ( %pycommand% "%squirrel%" -lib_call picker_walker remote_select_from_libraries -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel%" -lib_call picker_walker remote_select_from_walker -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="c" ( %pycommand% "%squirrel%" -lib_call workers concurrent_cache )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del "%prog_dir%MTP2GD.txt"
if /i "%eval%"=="1" goto MAIN
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call mtp.mtp_gdrive select_from_libraries -xarg "%prog_dir%MTP2GD.txt" )
echo.
goto checkagain

:r_files
set /p bs="输入您要删除的文件数（从底部开始）："
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (MTP2GD.txt) do (
set /a conta=!conta! + 1
)

set /a pos1=!conta!-!bs!
set /a pos2=!conta!
set string=

:update_list1
if !pos1! GTR !pos2! ( goto :update_list2 ) else ( set /a pos1+=1 )
set string=%string%,%pos1%
goto :update_list1
:update_list2
set string=%string%,
set skiplist=%string%
Set "skip=%skiplist%"
setlocal DisableDelayedExpansion
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<MTP2GD.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>MTP2GD.txt.new
endlocal
move /y "MTP2GD.txt.new" "MTP2GD.txt" >nul
endlocal
:showlist
cls
call :program_logo
echo -------------------------------------------------
echo MTP - 从谷歌网盘传输
echo -------------------------------------------------
ECHO 要处理的文件：
for /f "tokens=*" %%f in (MTP2GD.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (MTP2GD.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 您已添加 !conta! 个要处理的文件
echo .................................................
endlocal
goto checkagain

:START_TRANSFER
cls
call :program_logo
CD /d "%prog_dir%"
%pycommand% "%squirrel%" -lib_call mtp.mtp_gdrive loop_transfer -xarg "%prog_dir%MTP2GD.txt"
echo.
ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist MTP2GD.txt del MTP2GD.txt
if /i "%va_exit%"=="true" echo 程序即将关闭
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto s_exit_choice


::///////////////////////////////////////////////////
::子程序
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
ECHO "                         A MTP MANAGER FOR DBI INSTALLER                           "
ECHO                                  VERSION 1.00c (MTP)
ECHO -------------------------------------------------------------------------------------
ECHO DBI by DUCKBILL: https://github.com/rashevskyv/switch/releases
ECHO Latest DBI: https://github.com/rashevskyv/switch/releases/tag/462
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
echo 希望您玩得开心
exit /B

:MAIN
call "%prog_dir%\MtpMode.bat"
exit /B

:salida
::pause
exit
