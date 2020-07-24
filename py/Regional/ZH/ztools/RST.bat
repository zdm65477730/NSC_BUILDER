@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"

REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM 文件还原
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -------------------------------------------------
echo 文件还原已激活
echo -------------------------------------------------
if exist "rstlist.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (rstlist.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (rstlist.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del rstlist.txt )
endlocal
if not exist "rstlist.txt" goto manual_INIT
ECHO .......................................................
ECHO 发现以前的列表。你想做什么？
:prevlist0
ECHO .......................................................
echo 输入"1"，从上一个列表自动开始处理
echo 输入"2"，删除列表并创建一个新列表。
echo 输入"3"，继续构建上一个列表
echo .......................................................
echo NOTE: By pressing 3 you'll see the previous list
echo before starting the processing the files and you will
echo be able to add and delete items from the list
echo.
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="3" goto showlist
if /i "%bs%"=="2" goto delist
if /i "%bs%"=="1" goto start_cleaning
if /i "%bs%"=="0" exit /B
echo.
echo BAD CHOICE
goto prevlist0
:delist
del rstlist.txt
cls
call :program_logo
echo -------------------------------------------------
echo 文件还原已激活
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
%pycommand% "%squirrel%" -t nsp xci -tfile "%prog_dir%rstlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%rstlist.txt" mode=folder ext="nsp xci" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%rstlist.txt" mode=file ext="nsp xci" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%rstlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%rstlist.txt" "extlist=nsp xci" )
goto checkagain
echo.
:checkagain
echo 你想要做什么？?
echo ......................................................................
echo "拖动另一个文件或文件夹并按Enter键将项目添加到列表中"
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
%pycommand% "%squirrel%" -t nsp xci -tfile "%prog_dir%rstlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" goto start_cleaning
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%rstlist.txt" mode=folder ext="nsp xci" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%rstlist.txt" mode=file ext="nsp xci" ) 2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%rstlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%rstlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del rstlist.txt

goto checkagain

:r_files
set /p bs="输入要删除的文件数 (从底部): "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (rstlist.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<rstlist.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>rstlist.txt.new
endlocal
move /y "rstlist.txt.new" "rstlist.txt" >nul
endlocal

:showlist
cls
call :program_logo
echo -------------------------------------------------
echo 文件还原已激活
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                 要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (rstlist.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (rstlist.txt) do (
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
:start_cleaning
echo *******************************************************
echo 选择如何处理文件
echo *******************************************************
echo 如果使用合法来源的NSCB修改过的文件的nca文件是可恢复的，
echo 如果不是，那您就不走运了
echo.
echo 此模式将恢复：
echo   - XCI或NSP之间的转换（由NSCB完成）
echo   - 所有权删除操作
echo   - 密钥生成和RSV更改
echo.
echo + 尚不支持还原链接帐户修补程序
echo + 在此第一个实现中，多内容文件首先需要由多内容分割器处理。
echo.
echo ------------------------------------------
echo 输入"1"，处理文件
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" goto restorefiles
if %vrepack%=="none" goto s_cl_wrongchoice

:restorefiles
cls
call :program_logo
CD /d "%prog_dir%"
MD "%fold_output%" >NUL 2>&1
for /f "tokens=*" %%f in (rstlist.txt) do (
MD "%w_folder%" >NUL 2>&1

%pycommand% "%squirrel%" %buffer% -o "%w_folder%" %buffer% -tfile "%prog_dir%rstlist.txt" --restore ""
%pycommand% "%squirrel%" --strip_lines "%prog_dir%rstlist.txt"

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1

RD /S /Q "%w_folder%" >NUL 2>&1
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist rstlist.txt del rstlist.txt
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
for /f "tokens=*" %%f in (rstlist.txt) do (
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
