@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"

REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM 高级模式
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -------------------------------------------------
echo 高级选项
echo -------------------------------------------------
if exist "advlist.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (advlist.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (advlist.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del advlist.txt )
endlocal
if not exist "advlist.txt" goto manual_INIT
ECHO .......................................................
ECHO 发现以前的列表。你想做什么?
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
del advlist.txt
cls
call :program_logo
echo -------------------------------------------------
echo 高级选项
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
%pycommand% "%squirrel%" -t nsp xci nsx nsz xcz -tfile "%prog_dir%advlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%advlist.txt" mode=folder ext="nsp xci nsx nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%advlist.txt" mode=file ext="nsp xci nsx nsz xcz" False False True )  2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%advlist.txt" "extlist=nsp xci nsx nsz xcz" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%advlist.txt" "extlist=nsp xci nsx nsz xcz" )
goto checkagain
echo.
:checkagain
echo 你想要做什么？
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
echo Or 输入"0"返回模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsx nsz xcz -tfile "%prog_dir%advlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" goto start
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%advlist.txt" mode=folder ext="nsp xci nsx nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%advlist.txt" mode=file ext="nsp xci nsx nsz xcz" False False True ) 2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%advlist.txt" "extlist=nsp xci nsx nsz xcz" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%advlist.txt" "extlist=nsp xci nsx nsz xcz" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del advlist.txt

goto checkagain

:r_files
set /p bs="输入要删除的文件数 (从底部): "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (advlist.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<advlist.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>advlist.txt.new
endlocal
move /y "advlist.txt.new" "advlist.txt" >nul
endlocal

:showlist
cls
call :program_logo
echo -------------------------------------------------
echo 高级选项
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                 要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (advlist.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (advlist.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 你添加了 !conta! 要处理的文件
echo .................................................
endlocal

goto exit /B

:s_cl_wrongchoice
echo 错误的选择
echo ............
:start
echo *******************************************************
echo 选择如何处理文件
echo *******************************************************
echo 输入"1"，从NSP或XCI中提取所有文件
echo 输入"2"，进行原始提取（用于NCA产生错误的情况）
echo 输入"3"，将所有NCA文件提取为纯文本
echo 输入"4"，从NSP或XCI中提取NCA
echo 输入"5"，修补链接帐户要求
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" goto extract
if /i "%bs%"=="2" goto raw_extract
if /i "%bs%"=="3" goto ext_plaintext
if /i "%bs%"=="4" goto ext_fromnca
if /i "%bs%"=="5" goto patch_lnkacc
if %vrepack%=="none" goto s_cl_wrongchoice


:extract
cls
call :program_logo
echo ********************************************************
echo 从NSP或XCI提取所有文件
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%prog_dir%NSCB_extracted" -tfile "%prog_dir%advlist.txt" -x ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:raw_extract
cls
call :program_logo
echo ********************************************************
echo 以原始模式从NSP或XCI中提取所有文件
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%prog_dir%NSCB_extracted" -tfile "%prog_dir%advlist.txt" -raw_x ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:ext_plaintext
cls
call :program_logo
echo ********************************************************
echo 将NSP或XCI中的所有文件提取为纯文本
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%prog_dir%NSCB_extracted" -tfile "%prog_dir%advlist.txt" -plx ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:ext_fromnca
cls
call :program_logo
echo ********************************************************
echo 从NSP或XCI中提取内部NCA文件
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%prog_dir%NSCB_extracted" -tfile "%prog_dir%advlist.txt" -nfx ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:patch_lnkacc_wrongchoice
echo 错误的选择
echo ............
:patch_lnkacc
echo *******************************************************
echo 选择如何处理文件
echo *******************************************************
echo 输入"1"直接修补原始文件
echo 输入"2"生成新文件
echo.
ECHO ***********************************************
echo Or 输入"b"，返回上一选项s
ECHO ***********************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto start
if /i "%bs%"=="1" goto patch_lnkacc_mode1
if /i "%bs%"=="2" goto patch_lnkacc_mode2
if %vrepack%=="none" goto patch_lnkacc_wrongchoice

:patch_lnkacc_mode1
cls
call :program_logo
echo ********************************************************
echo 修补链接帐户需求
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -tfile "%prog_dir%advlist.txt" --remlinkacc ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:patch_lnkacc_mode2
cls
call :program_logo
echo ********************************************************
echo 修补链接帐户需求
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (
%pycommand% "%squirrel%" %buffer% %skdelta% --xml_gen "true" -o "%w_folder%" -tfile "%prog_dir%advlist.txt" --rebuild_nsp ""
%pycommand% "%squirrel%" %buffer% -o "%w_folder%" -tfile "%prog_dir%advlist.txt" --xci_trim ""
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%templist.txt" -ff "%w_folder%"
%pycommand% "%squirrel%" %buffer% -tfile "%prog_dir%templist.txt" --remlinkacc ""

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.xcz" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsz" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
call :delay
if exist templist.txt del templist.txt

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist advlist.txt del advlist.txt
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
for /f "tokens=*" %%f in (advlist.txt) do (
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
ECHO                                    VERSION 1.01
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
echo 希望您玩的愉快
exit /B


:salida
exit /B
