@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"

REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM 文件合并
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -------------------------------------------------
echo 文件合并程序已激活
echo -------------------------------------------------
if exist "joinlist.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (joinlist.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (joinlist.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del joinlist.txt )
endlocal
if not exist "joinlist.txt" goto manual_INIT
ECHO .......................................................
ECHO 发现以前的列表。你想做什么？
:prevlist0
ECHO .......................................................
echo 输入"1"，从上一个列表自动开始处理
echo 输入"2"，删除列表并创建一个新列表。
echo 输入"3"，继续构建上一个列表
echo .......................................................
echo 注意：输入3，您将在开始处理文件之前看到上一个列表，
echo 并且可以从列表中添加和删除项目
echo.
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="3" goto showlist
if /i "%bs%"=="2" goto delist
if /i "%bs%"=="1" goto start
if /i "%bs%"=="0" exit /B
echo.
echo 错误的选择
goto prevlist0
:delist
del joinlist.txt
cls
call :program_logo
echo -------------------------------------------------
echo 文件合并程序已激活
echo -------------------------------------------------
echo ..................................
echo 已经开始一个新的列表
echo ..................................

:manual_INIT
endlocal
ECHO ***********************************************
echo 输入"1"，将文件夹添加到列表中
echo 输入"2"，将文件添加到列表中
echo 输入"3"，通过本地文件库，将文件添加到列表
echo 输入"4"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t ns0 xc0 00 -tfile "%prog_dir%joinlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%joinlist.txt" mode=folder ext="ns0 xc0 00" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%joinlist.txt" mode=file ext="ns0 xc0 00" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%joinlist.txt" "extlist=ns0 xc0 00" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%joinlist.txt" "extlist=ns0 xc0 00" )
goto checkagain
echo.
:checkagain
echo 你想要做什么？?
echo ......................................................................
echo "拖动另一个文件或文件夹并按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"2"，将另一个文件夹添加到列表中
echo 输入"3"，将另一个文件添加到列表中
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"e"，退出
echo 输入"i"，以查看要处理的文件列表
echo 输入"r"，删除一些文件 (从底部计数)
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" -t ns0 xc0 00 -tfile "%prog_dir%joinlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" goto start
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%joinlist.txt" mode=folder ext="ns0 xc0 00" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%joinlist.txt" mode=file ext="ns0 xc0 00" ) 2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%joinlist.txt" "extlist=ns0 xc0 00" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%joinlist.txt" "extlist=ns0 xc0 00" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del joinlist.txt

goto checkagain

:r_files
set /p bs="输入要删除的文件数 (从底部): "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (joinlist.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<joinlist.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>joinlist.txt.new
endlocal
move /y "joinlist.txt.new" "joinlist.txt" >nul
endlocal

:showlist
cls
call :program_logo
echo -------------------------------------------------
echo 文件合并程序已激活
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                 要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (joinlist.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (joinlist.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 你添加了 !conta! 要处理的文件
echo .................................................
endlocal

goto checkagain

:s_cl_wrongchoice
echo 错误的选择
echo ............
:start
echo *******************************************************
echo 选择如何处理文件
echo *******************************************************
echo 输入"1"，来加入.xc*，.ns*，.0*文件
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" goto joinfiles
if %vrepack%=="none" goto s_cl_wrongchoice

:joinfiles
cls
call :program_logo
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (joinlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%fold_output%" -tfile "%prog_dir%joinlist.txt" --joinfile ""
if exist "%fold_output%\output.nsp" ( %pycommand% "%squirrel%" -t nsp -renf "%fold_output%\output.nsp" >NUL 2>&1)
if exist "%fold_output%\output.xci" ( %pycommand% "%squirrel%" -t xci -renf "%fold_output%\output.xci" >NUL 2>&1)

%pycommand% "%squirrel%" --strip_lines "%prog_dir%joinlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist joinlist.txt del joinlist.txt
if /i "%va_exit%"=="true" echo PROGRAM WILL CLOSE NOW
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto s_exit_choice

:contador_NF
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (joinlist.txt) do (
set /a conta=!conta! + 1
)
echo ...................................................
echo 仍有 !conta! 要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B


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
ECHO "                    BASED ON THE WORK OF BLAWAR AND LUCA FRAGA                     "
ECHO                                    VERSION 1.00c
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


:salida
exit /B
