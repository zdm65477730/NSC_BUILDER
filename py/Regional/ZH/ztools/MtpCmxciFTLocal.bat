@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.01 -- Profile: %ofile_name% -- by JulesOnTheRoad

::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
:: MTP 多文件模式
::///////////////////////////////////////////////////
::///////////////////////////////////////////////////

:multimode
if exist %w_folder% RD /S /Q "%w_folder%" >NUL 2>&1
if exist "%list_folder%\a_multi" RD /S /Q "%list_folder%\a_multi" >NUL 2>&1
cls
call :program_logo
echo -----------------------------------------------
echo 创建多XCI并传输到MTP
echo -----------------------------------------------
if exist "mlistMTP.txt" del "mlistMTP.txt"
:multi_manual_INIT
endlocal
set skip_list_split="false"
set "mlistfol=%list_folder%\m_multiMTP"
echo 拖动文件或文件夹以创建列表
echo 注意：记住在拖动每个文件\文件夹后按回车
echo.
ECHO ***********************************************
echo 输入"1"，以处理先前保存的作业
echo 输入"2"，通过选择器将另一个文件夹添加到列表
echo 输入"3"，通过选择器将另一个文件添加到列表
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%mlistMTP.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" set skip_list_split="true"
if /i "%eval%"=="1" goto m_patch_keygen
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mlistMTP.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mlistMTP.txt" mode=file ext="nsp xci nsz xcz" False False True ) 2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller select_from_local_libraries -xarg "%prog_dir%mlistMTP.txt" "mode=installer" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%mlistMTP.txt" "extlist=nsp xci nsz xcz" )

goto multi_checkagain

:multi_checkagain
echo.
set "mlistfol=%list_folder%\a_multiMTP"
echo 你想让我做什么？
echo ......................................................................
echo “拖动其他文件或文件夹，然后按回车将项目添加到列表中”
echo.
echo 输入"1"，开始处理当前列表
echo 输入"2"，添加到已保存列表并进行处理
echo 输入"3"，保存列表供以后使用
echo 输入"4"，通过选择器将另一个文件夹添加到列表
echo 输入"5"，通过选择器将另一个文件添加到列表
echo 输入"6"，通过本地文件库，将文件添加到列表
echo 输入"7"，通过folder-walker递归的方式，将文件添加到列表
echo.
echo 输入"e"，退出
echo 输入"i"，请参阅要处理的文件列表
echo 输入"r"，删除一些文件（从下往上数）
echo 输入"z"，删除一些文件（从下往上数）
echo ......................................................................
ECHO *************************************************
echo 或者输入"0"，返回到模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%mlistMTP.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" set "mlistfol=%list_folder%\a_multiMTP"
if /i "%eval%"=="1" goto m_patch_keygen
if /i "%eval%"=="2" set "mlistfol=%list_folder%\m_multiMTP"
if /i "%eval%"=="2" goto m_patch_keygen
if /i "%eval%"=="3" set "mlistfol=%list_folder%\m_multiMTP"
if /i "%eval%"=="3" goto multi_saved_for_later
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mlistMTP.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mlistMTP.txt" mode=file ext="nsp xci nsz xcz" False False True ) 2>&1>NUL
if /i "%eval%"=="6" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller select_from_local_libraries -xarg "%prog_dir%mlistMTP.txt" "mode=installer" )
if /i "%eval%"=="7" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%mlistMTP.txt" "extlist=nsp xci nsz xcz" )
REM if /i "%eval%"=="2" goto multi_set_clogo
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto multi_showlist
if /i "%eval%"=="r" goto multi_r_files
if /i "%eval%"=="z" del mlistMTP.txt

goto multi_checkagain

:multi_saved_for_later
if not exist "%list_folder%" MD "%list_folder%" >NUL 2>&1
if not exist "%mlistfol%" MD "%mlistfol%" >NUL 2>&1
echo 再次保存列表作业
echo ......................................................................
echo 输入"1"，将列表保存为合并任务（单个多文件列表）
echo 输入"2"，通过文件的baseid将列表另存为多任务
echo.
ECHO *******************************************
echo 输入"b"，以继续建立列表
echo 输入"0"，返回选择菜单
ECHO *******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto multi_saved_for_later1
if /i "%bs%"=="2" ( %pycommand% "%squirrel%" -splid "%mlistfol%" -tfile "%prog_dir%mlistMTP.txt" )
if /i "%bs%"=="2" del "%prog_dir%mlistMTP.txt"
if /i "%bs%"=="2" goto multi_saved_for_later2
echo 错误的选项!!
goto multi_saved_for_later
:multi_saved_for_later1
echo.
echo 选择任务名称
echo ......................................................................
echo 该列表将以您选择的名称保存在列表的文件夹中（路径是"程序目录\list\m_multi"）
echo.
set /p lname="Input name for the list job: "
set lname=%lname:"=%
move /y "%prog_dir%mlistMTP.txt" "%mlistfol%\%lname%.txt" >nul
echo.
echo 任务已保存!!!
:multi_saved_for_later2
echo.
echo 输入"0"，返回模式选择
echo 输入"1"，以创建其他任务
echo 输入"2"，退出程序
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" echo.
if /i "%bs%"=="1" echo CREATE ANOTHER JOB
if /i "%bs%"=="1" goto multi_manual_INIT
if /i "%bs%"=="1" goto salida
goto multi_saved_for_later2

:multi_r_files
set /p bs="输入您要删除的文件数（从底部开始）："
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (mlistMTP.txt) do (
set /a conta=!conta! + 1
)

set /a pos1=!conta!-!bs!
set /a pos2=!conta!
set string=

:multi_update_list1
if !pos1! GTR !pos2! ( goto :multi_update_list2 ) else ( set /a pos1+=1 )
set string=%string%,%pos1%
goto :multi_update_list1
:multi_update_list2
set string=%string%,
set skiplist=%string%
Set "skip=%skiplist%"
setlocal DisableDelayedExpansion
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<mlistMTP.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>mlistMTP.txt.new
endlocal
move /y "mlistMTP.txt.new" "mlistMTP.txt" >nul
endlocal

:multi_showlist
cls
call :program_logo
echo -------------------------------------------------
echo 多重打包模式已激活
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (mlistMTP.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (mlistMTP.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 您已添加 !conta! 个要处理的文件
echo .................................................
endlocal

goto multi_checkagain

:m_KeyChange_wrongchoice
echo 错误的选项
echo ............
:m_patch_keygen
echo *******************************************************
echo 检查控制台固件和补丁要求？
echo *******************************************************
echo.
echo 1. YES
echo 2. NO
echo.
ECHO ******************************************
echo 或者输入"0"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
set dopatchkg=none
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" set "dopatchkg=True"
if /i "%bs%"=="2" set "dopatchkg=False"

if %dopatchkg%=="none" goto m_KeyChange_wrongchoice

:m_KeyChange_skip
if not exist "%list_folder%" MD "%list_folder%" >NUL 2>&1
if not exist "%mlistfol%" MD "%mlistfol%" >NUL 2>&1
if %skip_list_split% EQU "true" goto m_process_jobs
echo *******************************************************
echo 您如何处理文件？
echo *******************************************************
echo 通过基本ID分开模式可以识别与每个游戏相对应的内容并创建多个来自同一列表文件的multi-xci或multi-nsp
echo.
echo 输入"1"，将所有文件合并为一个文件
echo 输入"2"，以baseid分隔成多个文件
echo.
ECHO *****************************************
echo 或输入"b"，返回选项列表
ECHO *****************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="1" move /y "%prog_dir%mlistMTP.txt" "%mlistfol%\mlistMTP.txt" >nul
if /i "%bs%"=="1" goto m_process_jobs
if /i "%bs%"=="2" goto m_split_merge
goto m_KeyChange_skip

:m_split_merge
cls
call :program_logo
%pycommand% "%squirrel%" -splid "%mlistfol%" -tfile "%prog_dir%mlistMTP.txt"

:m_process_jobs
dir "%mlistfol%\*.txt" /b  > "%prog_dir%mlistMTP.txt"
for /f "tokens=*" %%f in (mlistMTP.txt) do (
set "listname=%%f"
call :program_logo
call :m_split_merge_list_name

%pycommand% "%squirrel_lb%" -lib_call mtp.mtpxci generate_multixci_and_transfer -xarg "%mlistfol%\%%f" "%w_folder%" "destiny=False" "kgpatch=%dopatchkg%" "verification=%MTP_verification%"
echo.
%pycommand% "%squirrel%" --strip_lines "%prog_dir%mlistMTP.txt" "1" "true"
if exist "%mlistfol%\%%f" del "%mlistfol%\%%f"
)

if exist mlistMTP.txt del mlistMTP.txt
goto m_exit_choice

:m_split_merge_list_name
echo *******************************************************
echo 正在处理列表 %listname%
echo *******************************************************
exit /B


:m_exit_choice
ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理! *************
ECHO ---------------------------------------------------
if exist mlistMTP.txt del mlistMTP.txt
if /i "%va_exit%"=="true" echo PROGRAM WILL CLOSE NOW
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto salida
goto m_exit_choice

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
ECHO                                  VERSION 1.01 (MTP)
ECHO -------------------------------------------------------------------------------------
ECHO DBI by DUCKBILL: https://github.com/rashevskyv/switch/releases
ECHO Latest DBI: https://github.com/rashevskyv/switch/releases
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
