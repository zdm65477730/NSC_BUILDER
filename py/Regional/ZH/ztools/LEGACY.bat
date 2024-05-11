@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.01-b -- Profile: %ofile_name% -- by JulesOnTheRoad

::Check if user is dragging a folder or a file
if "%~1"=="" goto manual
dir "%~1\" >nul 2>nul
if not errorlevel 1 goto folder
if exist "%~1\" goto folder
goto file

:folder
if "%fi_rep%" EQU "multi" goto folder_mult_mode
goto folder_ind_mode

::AUTO MODE. INDIVIDUAL REPACK PROCESSING OPTION.
:folder_ind_mode
call :program_logo
echo --------------------------------------
echo 自动模式。单文件打包已设置
echo --------------------------------------
echo.
::*************
::NSP文件
::*************
for /r "%~1" %%f in (*.nsp) do (
set "target=%%f"
if exist "%w_folder%" RD /s /q "%w_folder%" >NUL 2>&1

MD "%w_folder%"
MD "%w_folder%\secure"

set "filename=%%~nf"
set "orinput=%%f"
set "showname=%orinput%"
call :processing_message
REM echo %safe_var%>safe.txt
call :squirrell
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%%f"
if "%zip_restore%" EQU "true" ( set "ziptarget=%%f" )
if "%zip_restore%" EQU "true" ( call :makezip )
call :getname
REM setlocal enabledelayedexpansion
REM set vpack=!vrepack!
REM endlocal & ( set "vpack=!vrepack!" )

REM if "%trn_skip%" EQU "true" ( call :check_titlerights )
if "%vrename%" EQU "true" ( call :addtags_from_nsp )

if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )
setlocal enabledelayedexpansion
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
set "gefolder=%fold_output%\!end_folder!"
if "%oforg%" EQU "inline" ( set "gefolder=%fold_output%" )
MD "%gefolder%" >NUL 2>&1
move "%w_folder%\*.xci" "%gefolder%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.nsp" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.ns*" "%gefolder%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%gefolder%\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
echo DONE
call :thumbup
)

::XCI文件
for /r "%~1" %%f in (*.xci) do (
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
set "filename=%%~nf"
set "orinput=%%f"
set "showname=%orinput%"
call :processing_message
MD "%w_folder%"
MD "%w_folder%\secure"
call :getname
echo -------------------------------------
echo 从XCI提取安全分区
echo -------------------------------------
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%%f"
echo DONE
if "%vrename%" EQU "true" ( call :addtags_from_xci )
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )
setlocal enabledelayedexpansion
MD "%fold_output%\!end_folder!" >NUL 2>&1
move "%w_folder%\*.xci" "%fold_output%\!end_folder!" >NUL 2>&1
move  "%w_folder%\*.xc*"  "%fold_output%\!end_folder!" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%\!end_folder!" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%\!end_folder!" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\!end_folder!\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
echo DONE
call :thumbup
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto aut_exit_choice

::AUTO MODE. MULTIREPACK PROCESSING OPTION.
:folder_mult_mode
call :program_logo
echo --------------------------------------
echo 自动模式。多文件处理已设置
echo --------------------------------------
echo.
set "filename=%~n1"
set "orinput=%~f1"
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
MD "%w_folder%\secure"
set "end_folder=%filename%"
set "filename=%filename%[multi]"
::NSP文件
for /r "%~1" %%f in (*.nsp) do (
set "showname=%orinput%"
call :processing_message
::echo %safe_var%>safe.txt
call :squirrell
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%%f"
if "%zip_restore%" EQU "true" ( set "ziptarget=%%f" )
if "%zip_restore%" EQU "true" ( call :makezip )
)

::XCI文件
for /r "%~1" %%f in (*.xci) do (
echo ------------------------------------
echo 从XCI提取安全分区
echo ------------------------------------
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%%f"
echo DONE
)
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )
setlocal enabledelayedexpansion
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
set "gefolder=%fold_output%\!end_folder!"
if "%oforg%" EQU "inline" ( set "gefolder=%fold_output%" )
MD "%gefolder%" >NUL 2>&1
move "%w_folder%\*.xci" "%gefolder%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.nsp" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.ns*" "%gefolder%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%gefolder%\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
echo DONE
call :thumbup
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto aut_exit_choice

:file
call :program_logo
if "%~x1"==".nsp" ( goto nsp )
if "%~x1"==".xci" ( goto xci )
if "%~x1"==".*" ( goto other )
:other
echo 未拖动有效文件。程序只接受XCI或NSP文件。
echo 您将被重定向到手动模式。
pause
goto manual

:nsp
set "orinput=%~f1"
set "filename=%~n1"
set "target=%~1"
set "showname=%orinput%"
call :processing_message
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
call :squirrell
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%~1"
if "%zip_restore%" EQU "true" ( set "ziptarget=%~1" )
if "%zip_restore%" EQU "true" ( call :makezip )
call :getname
if "%vrename%" EQU "true" call :addtags_from_nsp
::echo "%vrepack%"
::echo "%nsp_lib%"
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )
setlocal enabledelayedexpansion
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
set "gefolder=%fold_output%\!end_folder!"
if "%oforg%" EQU "inline" ( set "gefolder=%fold_output%" )
MD "%gefolder%" >NUL 2>&1
move "%w_folder%\*.xci" "%gefolder%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.nsp" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.ns*" "%gefolder%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%gefolder%\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
echo DONE
call :thumbup
goto aut_exit_choice

:xci
set "filename=%~n1"
set "orinput=%~f1"
set "showname=%orinput%"
call :processing_message
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
MD "%w_folder%\secure"
call :getname
echo ------------------------------------
echo 从XCI提取安全分区
echo ------------------------------------
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%~1"
echo DONE
if "%vrename%" EQU "true" call :addtags_from_xci
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )
setlocal enabledelayedexpansion
if exist "%fold_output%\!end_folder!" RD /S /Q "%fold_output%\!end_folder!" >NUL 2>&1
MD "%fold_output%\!end_folder!" >NUL 2>&1
move  "%w_folder%\*.xci"  "%fold_output%\!end_folder!" >NUL 2>&1
move  "%w_folder%\*.xc*"  "%fold_output%\!end_folder!" >NUL 2>&1
move  "%w_folder%\*.nsp"  "%fold_output%\!end_folder!" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%\!end_folder!" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\!end_folder!\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
echo DONE
call :thumbup
goto aut_exit_choice
:aut_exit_choice
if /i "%va_exit%"=="true" echo  程序将立即关闭
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，进入模式选择
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto aut_exit_choice
exit
:manual
endlocal
cls
call :program_logo
echo ********************************
echo 您已进入手动模式
echo ********************************
if "%manual_intro%" EQU "indiv" ( goto normalmode )
if "%manual_intro%" EQU "multi" ( goto multimode )
if "%manual_intro%" EQU "split" ( goto SPLMODE )
if "%manual_intro%" EQU "update" ( goto UPDMODE )

goto manual_Reentry

:manual_Reentry
cls
call :program_logo
ECHO .......................................................
echo 输入"1"，单文件处理 (legacy)
echo 输入"2"，多文件处理 (legacy)
echo 输入"3"，拆分模式 (legacy)
echo 输入"4"，更新模式 (legacy)
echo 输入"5"，文件信息
echo 输入"6"，数据构建
echo 输入"0"，配置选项
echo.
echo 输入"N"，进入新模式
echo 输入"M"，进入MTP模式
echo 输入"D"，进入谷歌网盘模式
echo 输入"L"，进入传统模式
echo .......................................................
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="1" goto normalmode
if /i "%bs%"=="2" goto multimode
if /i "%bs%"=="3" goto SPLMODE
if /i "%bs%"=="4" goto UPDMODE
if /i "%bs%"=="5" goto INFMODE
if /i "%bs%"=="6" goto DBMODE
if /i "%bs%"=="0" goto OPT_CONFIG
if /i "%bs%"=="N" goto call_new
if /i "%bs%"=="D" goto GDMode
if /i "%bs%"=="M" goto MTPMode
goto manual_Reentry

:MTPMode
call "%prog_dir%ztools\MtpMode.bat"
exit /B

:GDMode
call "%prog_dir%ztools\DriveMode.bat"
exit /B

REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM 启动手动模式。独立处理
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -----------------------------------------------
echo 单文件处理已激活
echo -----------------------------------------------
if exist "list.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (list.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (list.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del list.txt )
endlocal
if not exist "list.txt" goto manual_INIT
ECHO .......................................................
ECHO 发现了以前的列表, 你想做什么？
:prevlist0
ECHO .......................................................
echo 输入"1"，从上一列表自动开始处理
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo .......................................................
echo 注意：输入3，在开始处理文件之前，您将看到上一个列表，并且您可
echo 以从列表中添加和删除项目。
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
if /i "%bs%"=="0" goto manual_Reentry
echo.
echo 错误的选项
goto prevlist0
:delist
del list.txt
cls
call :program_logo
echo -----------------------------------------------
echo 单文件处理已激活
echo -----------------------------------------------
echo ..................................
echo 你已经开始一个新的列表
echo ..................................
:manual_INIT
endlocal
ECHO ***********************************************
echo 输入"0"返回模式选择菜单
ECHO ***********************************************
echo.
set /p bs="请将文件或文件夹拖到窗口上，然后按回车键： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
dir "%bs%\" >nul 2>nul
if not errorlevel 1 goto checkfolder
if exist "%bs%\" goto checkfolder
goto checkfile
:checkfolder
DIR /B /S "%bs%\*.ns*">hlist.txt
FINDSTR /L ".nsp" hlist.txt>>list.txt
FINDSTR /L ".nsx" hlist.txt>>list.txt
del hlist.txt
DIR /B /S "%bs%\*.xci">hlist2.txt
FINDSTR /L ".xci" hlist2.txt>>list.txt
del hlist2.txt
goto checkagain
:checkfile
echo %bs%>>hlist.txt
FINDSTR /L ".nsp" hlist.txt>>list.txt
FINDSTR /L ".nsx" hlist.txt>>list.txt
del hlist.txt
echo %bs%>>hlist2.txt
FINDSTR /L ".xci" hlist2.txt>>list.txt
del hlist2.txt
goto checkagain
echo.
:checkagain
echo 你想做什么？
echo ......................................................................
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="拖放文件/文件夹或设置选项： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto start_cleaning
if /i "%bs%"=="e" goto salida
if /i "%bs%"=="i" goto showlist
if /i "%bs%"=="r" goto r_files
if /i "%bs%"=="z" del list.txt
dir "%bs%\" >nul 2>nul
if not errorlevel 1 goto checkfolder
if exist "%bs%\" goto checkfolder
goto checkfile
goto salida

:r_files
set /p bs="输入要删除的文件数（从底部开始）： "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (list.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<list.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>list.txt.new
endlocal
move /y "list.txt.new" "list.txt" >nul
endlocal

:showlist
cls
call :program_logo
echo -------------------------------------------------
echo 单文件处理已激活
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                 要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (list.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (list.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 你加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto checkagain

:s_cl_wrongchoice
echo 错误的选项
echo ............
:start_cleaning
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为XCI
echo 输入"3"，全部都要
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="0" set "vrepack=zip"
if /i "%bs%"=="1" set "vrepack=nsp"
if /i "%bs%"=="2" set "vrepack=xci"
if /i "%bs%"=="3" set "vrepack=both"
if /i "%bs%"=="0" goto s_KeyChange_skip
if %vrepack%=="none" goto s_cl_wrongchoice
:s_RSV_wrongchoice
if /i "%skipRSVprompt%"=="true" set "patchRSV=-pv false"
if /i "%skipRSVprompt%"=="true" goto s_KeyChange_skip
if /i "%vrepack%"=="zip" goto s_KeyChange_skip
echo *******************************************************
echo 是否要魔改所需的系统版本
echo *******************************************************
echo 如果你选择魔改，它将被设置为与nca加密匹配，因此它只会在必要的
echo 情况下要求更新你的系统。
echo.
echo 输入"0"，不魔改
echo 输入"1"，魔改
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "patchRSV=none"
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="0" set "patchRSV=-pv false"
if /i "%bs%"=="1" set "patchRSV=-pv true"
if /i "%patchRSV%"=="none" echo 错误的选项
if /i "%patchRSV%"=="none" goto s_RSV_wrongchoice
if /i "%bs%"=="0" goto s_KeyChange_skip

:s_KeyChange_wrongchoice
echo *******************************************************
echo 设置魔改系统最大版本号
echo *******************************************************
echo 根据您的选择，如果读取密钥生成值大于程序中指定的值，则密钥生
echo 成和RSV将降低到相应的密钥生成范围。
echo 这并不总能降低系统要求。
echo.
echo 输入"f"，不魔改
echo 输入"0"，魔改版本FW 1.0
echo 输入"1"，魔改版本FW 2.0-2.3
echo 输入"2"，魔改版本FW 3.0
echo 输入"3"，魔改版本FW 3.0.1-3.0.2
echo 输入"4"，魔改版本FW 4.0.0-4.1.0
echo 输入"5"，魔改版本FW 5.0.0-5.1.0
echo 输入"6"，魔改版本FW 6.0.0-6.1.0
echo 输入"7"，魔改版本FW 6.2.0
echo 输入"8"，魔改版本FW 7.0.0-8.0.1
echo 输入"9"，魔改版本FW 8.1.0
echo 输入"10"，魔改版本FW 9.0.0-9.0.1
echo 输入"11"，魔改版本FW 9.1.0-11.0.3
echo 输入"12"，魔改版本FW 12.1.0
echo 输入"13"，魔改版本FW 13.0.0-13.2.1
echo 输入"14"，魔改版本FW 14.0.0-14.1.2
echo 输入"15"，魔改版本FW 15.0.0-15.0.1
echo 输入"16"，魔改版本FW 16.0.0-16.1.0
echo 输入"17"，魔改版本FW 17.0.0-17.0.1
echo 输入"18"，魔改版本FW 18.0.0-
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "vkey=none"
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="f" set "vkey=-kp false"
if /i "%bs%"=="0" set "vkey=-kp 0"
if /i "%bs%"=="0" set "capRSV=--RSVcap 0"
if /i "%bs%"=="1" set "vkey=-kp 1"
if /i "%bs%"=="1" set "capRSV=--RSVcap 65796"
if /i "%bs%"=="2" set "vkey=-kp 2"
if /i "%bs%"=="2" set "capRSV=--RSVcap 201327002"
if /i "%bs%"=="3" set "vkey=-kp 3"
if /i "%bs%"=="3" set "capRSV=--RSVcap 201392178"
if /i "%bs%"=="4" set "vkey=-kp 4"
if /i "%bs%"=="4" set "capRSV=--RSVcap 268435656"
if /i "%bs%"=="5" set "vkey=-kp 5"
if /i "%bs%"=="5" set "capRSV=--RSVcap 335544750"
if /i "%bs%"=="6" set "vkey=-kp 6"
if /i "%bs%"=="6" set "capRSV=--RSVcap 402653494"
if /i "%bs%"=="7" set "vkey=-kp 7"
if /i "%bs%"=="7" set "capRSV=--RSVcap 404750336"
if /i "%bs%"=="8" set "vkey=-kp 8"
if /i "%bs%"=="8" set "capRSV=--RSVcap 469762048"
if /i "%bs%"=="9" set "vkey=-kp 9"
if /i "%bs%"=="9" set "capRSV=--RSVcap 537919488"
if /i "%bs%"=="10" set "vkey=-kp 10"
if /i "%bs%"=="10" set "capRSV=--RSVcap 603979776"
if /i "%bs%"=="11" set "vkey=-kp 11"
if /i "%bs%"=="11" set "capRSV=--RSVcap 605028352"
if /i "%bs%"=="12" set "vkey=-kp 12"
if /i "%bs%"=="12" set "capRSV=--RSVcap 806354944"
if /i "%bs%"=="13" set "vkey=-kp 13"
if /i "%bs%"=="13" set "capRSV=--RSVcap 872415232"
if /i "%bs%"=="14" set "vkey=-kp 14"
if /i "%bs%"=="14" set "capRSV=--RSVcap 939524096"
if /i "%bs%"=="15" set "vkey=-kp 15"
if /i "%bs%"=="15" set "capRSV=--RSVcap 1006632960"
if /i "%bs%"=="16" set "vkey=-kp 16"
if /i "%bs%"=="16" set "capRSV=--RSVcap 1073741824"
if /i "%bs%"=="17" set "vkey=-kp 17"
if /i "%bs%"=="17" set "capRSV=--RSVcap 1140851708"
if /i "%bs%"=="18" set "vkey=-kp 18"
if /i "%bs%"=="18" set "capRSV=--RSVcap 1207960692"
if /i "%vkey%"=="none" echo 错误的选项
if /i "%vkey%"=="none" goto s_KeyChange_wrongchoice

:s_KeyChange_skip
cls
call :program_logo
for /f "tokens=*" %%f in (list.txt) do (
set "name=%%~nf"
set "filename=%%~nxf"
set "orinput=%%f"
set "ziptarget=%%f"

if "%vrepack%" EQU "zip" ( set "zip_restore=true" )
if "%%~nxf"=="%%~nf.nsp" call :nsp_manual
if "%%~nxf"=="%%~nf.xci" call :xci_manual
%pycommand% "%squirrel%" --strip_lines "%prog_dir%list.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
:s_exit_choice
if exist list.txt del list.txt
if /i "%va_exit%"=="true" echo  程序将立即关闭
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto s_exit_choice

:nsp_manual
set "filename=%name%"
set "showname=%orinput%"
call :processing_message

if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
call :squirrell

if "%vrepack%" EQU "zip" ( goto nsp_just_zip )

%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%orinput%"

:nsp_just_zip
if "%zip_restore%" EQU "true" ( call :makezip )
call :getname
if "%vrename%" EQU "true" call :addtags_from_nsp
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "repack" "%w_folder%" "%%f")
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" "%%f")
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "repack" "%w_folder%" "%%f")
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" "%%f")
setlocal enabledelayedexpansion
if "%zip_restore%" EQU "true" ( goto :nsp_just_zip2 )
if exist "%fold_output%\!end_folder!" RD /S /Q "%fold_output%\!end_folder!" >NUL 2>&1
:nsp_just_zip2
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
set "gefolder=%fold_output%\!end_folder!"
if "%oforg%" EQU "inline" ( set "gefolder=%fold_output%" )
MD "%gefolder%" >NUL 2>&1
move "%w_folder%\*.xci" "%gefolder%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.nsp" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.ns*" "%gefolder%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%gefolder%\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
echo DONE
call :thumbup
call :delay

:end_nsp_manual
exit /B

:xci_manual
::XCI文件
cls
if "%vrepack%" EQU "zip" ( goto end_xci_manual )
set "filename=%name%"
call :program_logo
set "showname=%orinput%"
call :processing_message
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
MD "%w_folder%\secure"
call :getname
echo ------------------------------------
echo 从XCI提取安全分区
echo ------------------------------------
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%orinput%"
echo DONE
if "%vrename%" EQU "true" call :addtags_from_xci
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )
setlocal enabledelayedexpansion
if exist "%fold_output%\!end_folder!" RD /S /Q "%fold_output%\!end_folder!" >NUL 2>&1
MD "%fold_output%\!end_folder!" >NUL 2>&1
move  "%w_folder%\*.xci"  "%fold_output%\!end_folder!" >NUL 2>&1
move  "%w_folder%\*.xc*"  "%fold_output%\!end_folder!" >NUL 2>&1
move  "%w_folder%\*.nsp"  "%fold_output%\!end_folder!" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%\!end_folder!" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\!end_folder!\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
echo DONE
call :thumbup
call :delay
:end_xci_manual
exit /B

:contador_NF
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (list.txt) do (
set /a conta=!conta! + 1
)
echo ...................................................
echo 仍然有 !conta! 个要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B

::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
:: 多文件模式
::///////////////////////////////////////////////////
::///////////////////////////////////////////////////

:multimode
if exist %w_folder% RD /S /Q "%w_folder%" >NUL 2>&1
cls
call :program_logo
echo -----------------------------------------------
echo 多文件处理已激活
echo -----------------------------------------------
if exist "mlist.txt" goto multi_prevlist
goto multi_manual_INIT
:multi_prevlist
set conta=0
for /f "tokens=*" %%f in (mlist.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (mlist.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del mlist.txt )
endlocal
if not exist "mlist.txt" goto multi_manual_INIT
ECHO .......................................................
ECHO 发现了以前的列表, 你想做什么？
:multi_prevlist0
ECHO .......................................................
echo 输入"1"，从上一列表自动开始处理
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo .......................................................
echo 注意：输入3，您将在开始处理文件之前看到上一个列表，并且您可以
echo 添加和删除列表中的项目。
echo.
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="3" goto multi_showlist
if /i "%bs%"=="2" goto multi_delist
if /i "%bs%"=="1" goto multi_start_cleaning
if /i "%bs%"=="0" goto manual_Reentry
echo.
echo 错误的选项
goto multi_prevlist0
:multi_delist
del mlist.txt
cls
call :program_logo
echo -----------------------------------------------
echo 多文件处理已激活
echo -----------------------------------------------
echo ..................................
echo 你已经开始一个新的列表
echo ..................................
:multi_manual_INIT
endlocal
ECHO ***********************************************
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
set /p bs="请将文件或文件夹拖到窗口上，然后按回车键： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
dir "%bs%\" >nul 2>nul
if not errorlevel 1 goto multi_checkfolder
if exist "%bs%\" goto multi_checkfolder
goto multi_checkfile
:multi_checkfolder
DIR /B /S "%bs%\*.nsp">hmlist.txt
FINDSTR /L ".nsp" hmlist.txt>>mlist.txt
del hmlist.txt
DIR /B /S "%bs%\*.xci">hmlist2.txt
FINDSTR /L ".xci" hmlist2.txt>>mlist.txt
del hmlist2.txt
goto multi_checkagain
:multi_checkfile
echo %bs%>>hmlist.txt
FINDSTR /L ".nsp" hmlist.txt>>mlist.txt
del hmlist.txt
echo %bs%>>hmlist2.txt
FINDSTR /L ".xci" hmlist2.txt>>mlist.txt
del hmlist2.txt
goto multi_checkagain
echo.
:multi_checkagain
echo 你想做什么？
echo ......................................................................
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"2"，从NSP或NCA中提取并设置自定义图标
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="拖放文件/文件夹或设置选项： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto multi_start_cleaning
if /i "%bs%"=="2" goto multi_set_clogo
if /i "%bs%"=="e" goto salida
if /i "%bs%"=="i" goto multi_showlist
if /i "%bs%"=="r" goto multi_r_files
if /i "%bs%"=="z" del mlist.txt
dir "%bs%\" >nul 2>nul
if not errorlevel 1 goto multi_checkfolder
if exist "%bs%\" goto multi_checkfolder
goto multi_checkfile
goto salida

:multi_r_files
set /p bs="输入要删除的文件数（从底部开始）： "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (mlist.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<mlist.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>mlist.txt.new
endlocal
move /y "mlist.txt.new" "mlist.txt" >nul
endlocal

:multi_showlist
cls
call :program_logo
echo -------------------------------------------------
echo 多文件处理已激活
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (mlist.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (mlist.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 你加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto multi_checkagain

:m_cl_wrongchoice
echo 错误的选项
echo ............
:multi_start_cleaning
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为xci
echo 输入"3"，打包为NSP和XCI
echo.
ECHO *****************************************
echo 或输入"b"，返回选项列表
ECHO *****************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="1" set "vrepack=nsp"
if /i "%bs%"=="2" set "vrepack=xci"
if /i "%bs%"=="3" set "vrepack=both"
if %vrepack%=="none" goto m_cl_wrongchoice
:m_RSV_wrongchoice
if /i "%skipRSVprompt%"=="true" set "patchRSV=-pv false"
if /i "%skipRSVprompt%"=="true" goto m_KeyChange_skip
echo *******************************************************
echo 是否要魔改所需的系统版本
echo *******************************************************
echo 如果你选择魔改，它将被设置为与nca加密匹配，因此它只会在必要的情况下要求更新你的系统。
echo 的情况下要求更新你的系统。
echo.
echo 输入"0"，不魔改
echo 输入"1"，魔改
echo.
ECHO *****************************************
echo 或输入"b"，返回选项列表
ECHO *****************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set patchRSV=none
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="0" set "patchRSV=-pv false"
if /i "%bs%"=="1" set "patchRSV=-pv true"
if /i "%patchRSV%"=="none" echo 错误的选项
if /i "%patchRSV%"=="none" goto m_RSV_wrongchoice
if /i "%bs%"=="0" goto m_KeyChange_skip

:m_KeyChange_wrongchoice
echo *******************************************************
echo 设置魔改允许的最大版本号
echo *******************************************************
echo 根据您的选择，如果读取密钥生成值大于程序中指定的值，则密钥生成和RSV将降低到相应的密钥生成范围。
echo 成和RSV将降低到相应的密钥生成范围。
echo 这并不总能降低系统要求。
echo.
echo 输入"f"，不魔改
echo 输入"0"，魔改版本FW 1.0
echo 输入"1"，魔改版本FW 2.0-2.3
echo 输入"2"，魔改版本FW 3.0
echo 输入"3"，魔改版本FW 3.0.1-3.0.2
echo 输入"4"，魔改版本FW 4.0.0-4.1.0
echo 输入"5"，魔改版本FW 5.0.0-5.1.0
echo 输入"6"，魔改版本FW 6.0.0-6.1.0
echo 输入"7"，魔改版本FW 6.2.0
echo 输入"8"，魔改版本FW 7.0.0-8.0.1
echo 输入"9"，魔改版本FW 8.1.0
echo 输入"10"，魔改版本FW 9.0.0-9.0.1
echo 输入"11"，魔改版本FW 9.1.0-11.0.3
echo 输入"12"，魔改版本FW 12.1.0
echo 输入"13"，魔改版本FW 13.0.0-13.2.1
echo 输入"14"，魔改版本FW 14.0.0-14.1.2
echo 输入"15"，魔改版本FW 15.0.0-15.0.1
echo 输入"16"，魔改版本FW 16.0.0-16.1.0
echo 输入"17"，魔改版本FW 17.0.0-17.0.1
echo 输入"18"，魔改版本FW 18.0.0-
echo.
ECHO *****************************************
echo 或输入"b"，返回选项列表
ECHO *****************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "vkey=none"
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="f" set "vkey=-kp false"
if /i "%bs%"=="0" set "vkey=-kp 0"
if /i "%bs%"=="0" set "capRSV=--RSVcap 0"
if /i "%bs%"=="1" set "vkey=-kp 1"
if /i "%bs%"=="1" set "capRSV=--RSVcap 65796"
if /i "%bs%"=="2" set "vkey=-kp 2"
if /i "%bs%"=="2" set "capRSV=--RSVcap 201327002"
if /i "%bs%"=="3" set "vkey=-kp 3"
if /i "%bs%"=="3" set "capRSV=--RSVcap 201392178"
if /i "%bs%"=="4" set "vkey=-kp 4"
if /i "%bs%"=="4" set "capRSV=--RSVcap 268435656"
if /i "%bs%"=="5" set "vkey=-kp 5"
if /i "%bs%"=="5" set "capRSV=--RSVcap 335544750"
if /i "%bs%"=="6" set "vkey=-kp 6"
if /i "%bs%"=="6" set "capRSV=--RSVcap 402653494"
if /i "%bs%"=="7" set "vkey=-kp 7"
if /i "%bs%"=="7" set "capRSV=--RSVcap 404750336"
if /i "%bs%"=="8" set "vkey=-kp 8"
if /i "%bs%"=="8" set "capRSV=--RSVcap 469762048"
if /i "%bs%"=="9" set "vkey=-kp 9"
if /i "%bs%"=="9" set "capRSV=--RSVcap 537919488"
if /i "%bs%"=="10" set "vkey=-kp 10"
if /i "%bs%"=="10" set "capRSV=--RSVcap 603979776"
if /i "%bs%"=="11" set "vkey=-kp 11"
if /i "%bs%"=="11" set "capRSV=--RSVcap 605028352"
if /i "%bs%"=="12" set "vkey=-kp 12"
if /i "%bs%"=="12" set "capRSV=--RSVcap 806354944"
if /i "%bs%"=="13" set "vkey=-kp 13"
if /i "%bs%"=="13" set "capRSV=--RSVcap 872415232"
if /i "%bs%"=="14" set "vkey=-kp 14"
if /i "%bs%"=="14" set "capRSV=--RSVcap 939524096"
if /i "%bs%"=="15" set "vkey=-kp 15"
if /i "%bs%"=="15" set "capRSV=--RSVcap 1006632960"
if /i "%bs%"=="16" set "vkey=-kp 16"
if /i "%bs%"=="16" set "capRSV=--RSVcap 1073741824"
if /i "%bs%"=="17" set "vkey=-kp 17"
if /i "%bs%"=="17" set "capRSV=--RSVcap 1140851708"
if /i "%bs%"=="18" set "vkey=-kp 18"
if /i "%bs%"=="18" set "capRSV=--RSVcap 1207960692"
if /i "%vkey%"=="none" echo 错误的选项
if /i "%vkey%"=="none" goto m_KeyChange_wrongchoice

:m_KeyChange_skip
echo *******************************************************
echo 最终文件名
echo *******************************************************
echo.
echo 或输入"b"，返回选项列表
echo.
set /p bs="请键入不带扩展名的名称： "
set finalname=%bs:"=%
if /i "%finalname%"=="b" goto multi_checkagain

cls
call :program_logo
for /f "tokens=*" %%f in (mlist.txt) do (
set "name=%%~nf"
set "filename=%%~nxf"
set "orinput=%%f"
if "%%~nxf"=="%%~nf.nsp" call :multi_nsp_manual
if "%%~nxf"=="%%~nf.xci" call :multi_xci_manual
%pycommand% "%squirrel%" --strip_lines "%prog_dir%mlist.txt"
call :multi_contador_NF
)
set "filename=%finalname%"
set "end_folder=%finalname%"
set "filename=%finalname%[multi]"
::pause
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )

setlocal enabledelayedexpansion
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
set "gefolder=%fold_output%\!end_folder!"
if "%oforg%" EQU "inline" ( set "gefolder=%fold_output%" )
MD "%gefolder%" >NUL 2>&1
move "%w_folder%\*.xci" "%gefolder%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.nsp" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.ns*" "%gefolder%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%gefolder%\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
:m_exit_choice
if exist mlist.txt del mlist.txt
if /i "%va_exit%"=="true" echo  程序将立即关闭
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto m_exit_choice


:multi_nsp_manual
set "showname=%orinput%"
call :processing_message
call :squirrell
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%orinput%"
if "%zip_restore%" EQU "true" ( set "ziptarget=%orinput%" )
if "%zip_restore%" EQU "true" ( call :makezip )
echo DONE
call :thumbup
call :delay
exit /B

:multi_xci_manual
::XCI文件
set "showname=%orinput%"
call :processing_message
MD "%w_folder%" >NUL 2>&1
MD "%w_folder%\secure" >NUL 2>&1
MD "%w_folder%\normal" >NUL 2>&1
MD "%w_folder%\update" >NUL 2>&1
call :getname
echo ------------------------------------
echo 从XCI提取安全分区
echo ------------------------------------
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" %nf_cleaner% "%orinput%"
echo DONE
call :thumbup
call :delay
exit /B

:multi_contador_NF
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (mlist.txt) do (
set /a conta=!conta! + 1
)
echo ...................................................
echo 仍然有 !conta! 个要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B


:multi_set_clogo
cls
call :program_logo
echo ------------------------------------------
echo 自定义图标
echo ------------------------------------------
echo 用于多游戏xci。
echo 当前自定义图标和名称是通过拖动nsp或控件nca设置的
echo 这样，程序将复制正常分区中的控件nca
echo 如果您不添加自定义图标，则徽标将从您的某个游戏中设置
echo ..........................................
echo 输入"b"，返回列表生成器
echo ..........................................
set /p bs="将NSP或NCA文件拖到窗口上，然后按回车键： "
set bs=%bs:"=%
if /i "%bs%"=="b" ( goto multi_checkagain )
if exist "%bs%" ( goto multi_checklogo )
goto multi_set_clogo

:multi_checklogo
if exist "%prog_dir%logo.txt" del "%prog_dir%logo.txt" >NUL 2>&1
echo %bs%>"%prog_dir%hlogo.txt"
FINDSTR /L ".nsp" "%prog_dir%hlogo.txt" >"%prog_dir%logo.txt"
FINDSTR /L ".nca" "%prog_dir%hlogo.txt" >>"%prog_dir%logo.txt"
del "%prog_dir%hlogo.txt"
set /p custlogo=<"%prog_dir%logo.txt"
::echo %custlogo%
for /f "usebackq tokens=*" %%f in ( "%prog_dir%logo.txt" ) do (
set "logoname=%%~nxf"
if "%%~nxf"=="%%~nf.nsp" goto ext_log
if "%%~nxf"=="%%~nf.nca" goto check_log
)

:ext_log
del "%prog_dir%logo.txt"
if not exist "%w_folder%" MD "%w_folder%" >NUL 2>&1
if exist "%w_folder%\normal" RD /S /Q "%w_folder%\normal" >NUL 2>&1

%pycommand% "%squirrel%" --nsptype "%custlogo%">"%w_folder%\nsptype.txt"
set /p nsptype=<"%w_folder%\nsptype.txt"
del "%w_folder%\nsptype.txt"
if "%nsptype%" EQU "DLC" echo.
if "%nsptype%" EQU "DLC" echo ---NSP DOESN'T HAVE A CONTROL NCA---
if "%nsptype%" EQU "DLC" echo.
if "%nsptype%" EQU "DLC" ( goto multi_set_clogo )
MD "%w_folder%\normal" >NUL 2>&1
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\normal" --NSP_copy_nca_control "%custlogo%"
echo ................
echo "提取LOGO"
echo ................
echo.
goto multi_checkagain

:check_log
del "%prog_dir%logo.txt"
if not exist "%w_folder%" MD "%w_folder%" >NUL 2>&1
if exist "%w_folder%\normal" RD /S /Q "%w_folder%\normal" >NUL 2>&1
%pycommand% "%squirrel%" --ncatype "%custlogo%">"%w_folder%\ncatype.txt"
set /p ncatype=<"%w_folder%\ncatype.txt"
del "%w_folder%\ncatype.txt"
if "%ncatype%" NEQ "Content.CONTROL" echo.
if "%ncatype%" NEQ "Content.CONTROL" echo ---NCA IS NOT A CONTROL TYPE---
if "%ncatype%" NEQ "Content.CONTROL" echo.
if "%ncatype%" NEQ "Content.CONTROL" ( goto multi_set_clogo )
MD "%w_folder%\normal" >NUL 2>&1
copy "%custlogo%" "%w_folder%\normal\%logoname%"
echo.
goto multi_checkagain
exit


::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
::拆分模式
::///////////////////////////////////////////////////
::///////////////////////////////////////////////////

:SPLMODE
cls
call :program_logo
if exist %w_folder% RD /S /Q "%w_folder%" >NUL 2>&1
echo -----------------------------------------------
echo 拆分模式已激活
echo -----------------------------------------------
if exist "splist.txt" goto sp_prevlist
goto sp_manual_INIT
:sp_prevlist
set conta=0
for /f "tokens=*" %%f in (splist.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (splist.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del splist.txt )
endlocal
if not exist "splist.txt" goto sp_manual_INIT
ECHO .......................................................
ECHO 发现了以前的列表, 你想做什么？
:sp_prevlist0
ECHO .......................................................
echo 输入"1"，从上一列表自动开始处理
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo .......................................................
echo 注意：选择3，您将在开始处理文件之前看到上一个列表，并且您可以
echo 添加和删除列表中的项目。
echo.
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="3" goto sp_showlist
if /i "%bs%"=="2" goto sp_delist
if /i "%bs%"=="1" goto sp_start_cleaning
if /i "%bs%"=="0" goto manual_Reentry
echo.
echo 错误的选项
goto sp_prevlist0
:sp_delist
del splist.txt
cls
call :program_logo
echo -----------------------------------------------
echo 拆分模式已激活
echo -----------------------------------------------
echo ..................................
echo 你已经开始一个新的列表
echo ..................................
:sp_manual_INIT
endlocal
ECHO ***********************************************
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
set /p bs="请将文件或文件夹拖到窗口上，然后按回车键： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
dir "%bs%\" >nul 2>nul
if not errorlevel 1 goto sp_checkfolder
if exist "%bs%\" goto sp_checkfolder
goto sp_checkfile
:sp_checkfolder
DIR /B /S "%bs%\*.nsp">hsplist.txt
FINDSTR /L ".nsp" hsplist.txt>>splist.txt
del hsplist.txt
DIR /B /S "%bs%\*.xci">hsplist2.txt
FINDSTR /L ".xci" hsplist2.txt>>splist.txt
del hsplist2.txt
goto sp_checkagain
:sp_checkfile
echo %bs%>>hsplist.txt
FINDSTR /L ".nsp" hsplist.txt>>splist.txt
del hsplist.txt
echo %bs%>>hsplist2.txt
FINDSTR /L ".xci" hsplist2.txt>>splist.txt
del hsplist2.txt
goto sp_checkagain
echo.
:sp_checkagain
echo 你想做什么？
echo ......................................................................
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="拖放文件/文件夹或设置选项： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto sp_start_cleaning
if /i "%bs%"=="e" goto salida
if /i "%bs%"=="i" goto sp_showlist
if /i "%bs%"=="r" goto sp_r_files
if /i "%bs%"=="z" del splist.txt
dir "%bs%\" >nul 2>nul
if not errorlevel 1 goto sp_checkfolder
if exist "%bs%\" goto sp_checkfolder
goto sp_checkfile
goto salida

:sp_r_files
set /p bs="输入要删除的文件数（从底部开始）： "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (splist.txt) do (
set /a conta=!conta! + 1
)

set /a pos1=!conta!-!bs!
set /a pos2=!conta!
set string=

:sp_update_list1
if !pos1! GTR !pos2! ( goto :sp_update_list2 ) else ( set /a pos1+=1 )
set string=%string%,%pos1%
goto :sp_update_list1
:sp_update_list2
set string=%string%,
set skiplist=%string%
Set "skip=%skiplist%"
setlocal DisableDelayedExpansion
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<splist.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>splist.txt.new
endlocal
move /y "splist.txt.new" "splist.txt" >nul
endlocal

:sp_showlist
cls
call :program_logo
echo -------------------------------------------------
echo 拆分模式已激活
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (splist.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (splist.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 你加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto sp_checkagain

:sp_cl_wrongchoice
echo 错误的选项
echo ............
:sp_start_cleaning
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为xci
echo 输入"3"，全部都要
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto sp_checkagain
if /i "%bs%"=="1" set "vrepack=nsp"
if /i "%bs%"=="2" set "vrepack=xci"
if /i "%bs%"=="3" set "vrepack=both"
if %vrepack%=="none" goto sp_cl_wrongchoice
cls
call :program_logo
for /f "tokens=*" %%f in (splist.txt) do (
set "name=%%~nf"
set "filename=%%~nxf"
set "end_folder=%%~nf"
set "orinput=%%f"
if "%%~nxf"=="%%~nf.nsp" call :split_content
if "%%~nxf"=="%%~nf.xci" call :split_content
%pycommand% "%squirrel%" --strip_lines "%prog_dir%splist.txt"
setlocal enabledelayedexpansion
if exist "%fold_output%\!end_folder!" RD /S /Q "%fold_output%\!end_folder!" >NUL 2>&1
MD "%fold_output%\!end_folder!" >NUL 2>&1
move "%w_folder%\*.xci" "%fold_output%\!end_folder!\" >NUL 2>&1
move "%w_folder%\*.xc*" "%fold_output%\!end_folder!\" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%\!end_folder!\" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%\!end_folder!\" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\!end_folder!\%filename%.nsp" )
if exist "%w_folder%" RD /S /Q  "%w_folder%" >NUL 2>&1
endlocal
call :sp_contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
:SPLIT_exit_choice
if exist splist.txt del splist.txt
if /i "%va_exit%"=="true" echo  程序将立即关闭
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto SPLIT_exit_choice

:split_content
set "showname=%orinput%"
set "sp_repack=%vrepack%"
if exist "%w_folder%" RD /S /Q  "%w_folder%" >NUL 2>&1
MD "%w_folder%" >NUL 2>&1
call :processing_message
call :squirrell
%pycommand% "%squirrel%" %buffer% -o "%w_folder%" --splitter "%orinput%" -pe "secure"
for /f "usebackq tokens=*" %%f in ("%w_folder%\dirlist.txt") do (
setlocal enabledelayedexpansion
rem echo "!sp_repack!"
set "tfolder=%%f"
set "fname=%%~nf"
set "test=%%~nf"
set test=!test:[DLC]=!
rem echo !test!
rem echo "!test!"
rem echo "!fname!"
if "!test!" NEQ "!fname!" ( set "sp_repack=nsp" )
rem echo "!sp_repack!"
set "test=%%~nf"
set test=!test:[UPD]=!
rem echo !test!
rem echo "!test!"
rem echo "!fname!"
if "!test!" NEQ "!fname!" ( set "sp_repack=nsp" )
rem echo "!sp_repack!"
if "!sp_repack!" EQU "nsp" ( call "%nsp_lib%" "sp_convert" "%w_folder%" "!tfolder!" "!fname!" )
if "!sp_repack!" EQU "xci" ( call "%xci_lib%" "sp_repack" "%w_folder%" "!tfolder!" "!fname!" )
if "!sp_repack!" EQU "both" ( call "%nsp_lib%" "sp_convert" "%w_folder%" "!tfolder!" "!fname!" )
if "!sp_repack!" EQU "both" ( call "%xci_lib%" "sp_repack" "%w_folder%" "!tfolder!" "!fname!" )
endlocal
%pycommand% "%squirrel%" --strip_lines "%prog_dir%dirlist.txt"
)
del "%w_folder%\dirlist.txt" >NUL 2>&1

call :thumbup
call :delay
exit /B

:sp_contador_NF
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (splist.txt) do (
set /a conta=!conta! + 1
)
echo ...................................................
echo 仍然有 !conta! 个要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B

::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
::更新模式 -> 第一步
::///////////////////////////////////////////////////
::///////////////////////////////////////////////////

:UPDMODE
cls
call :program_logo
if exist %w_folder% RD /S /Q "%w_folder%" >NUL 2>&1
echo -------------------------------------------------------------------
echo                      更新模式已激活
echo -------------------------------------------------------------------
if exist "UPDlist.txt" goto upd_prevlist
goto upd_ADD_BASE
:upd_prevlist
set conta=0
for /f "tokens=*" %%f in (UPDlist.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (UPDlist.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del UPDlist.txt )
endlocal
:upd_ADD_BASE
ECHO.
echo 输入"0"，返回模式选择菜单
ECHO.
ECHO *******************************************************************
ECHO                         添加基本内容
ECHO *******************************************************************
ECHO.
set /p bs="请拖动要更新的文件，然后按回车键： "

set basefile=%bs:"=%
if /i "%basefile%"=="0" goto manual_Reentry

set "test=%basefile%"
set "basecheck=false"
set test=%test:.xci=%
if "%test%" NEQ "%basefile%" ( set "basecheck=true" )
set "test=%basefile%"
set test=%test:.nsp=%
if "%test%" NEQ "%basefile%" ( set "basecheck=true" )
::echo %basecheck%
if "%basecheck%" EQU "false" (
echo.
echo ---文件类型错误。请重试---
echo.
)
if "%basecheck%" EQU "false" ( goto upd_ADD_BASE)
if not exist "UPDlist.txt" goto upd_ADD_UPD_FILES
ECHO ..................................................................
ECHO 发现了以前的列表，你想做什么？
:upd_prevlist0
ECHO ..................................................................
echo 输入"1"，开始更新 基本内容
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo ..................................................................
echo 注意：选择3，您将在开始处理文件之前看到上一个列表，并且您可以添加和删除列
echo 表中的项目。
echo.
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="3" goto upd_showlist
if /i "%bs%"=="2" goto upd_delist
if /i "%bs%"=="1" goto upd_starts
if /i "%bs%"=="0" goto manual_Reentry
echo.
echo 错误的选项
goto upd_prevlist0
:upd_delist
del UPDlist.txt
cls
call :program_logo
echo -------------------------------------------------------------------
echo                      更新模式已激活
echo -------------------------------------------------------------------
echo ..................................
echo 你已经开始一个新的列表
echo ..................................
:upd_ADD_UPD_FILES
ECHO.
ECHO *******************************************************************
echo 输入"1"，将文件夹添加到列表中
echo 输入"2"，将文件添加到列表中
echo 输入"3"，通过本地文件库，将文件添加到列表
echo 输入"4"，通过folder-walker递归的方式，将文件添加到列表
ECHO 请添加要用于更新基本内容的文件
ECHO *******************************************************************
ECHO.
echo 输入"0"，返回模式选择菜单
ECHO.
%pycommand% "%squirrel%" -t nsp xci -tfile "%prog_dir%UPDlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
if /i "%eval%"=="0" goto manual_Reentry
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%UPDlist.txt" mode=folder ext="nsp xci" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%UPDlist.txt" mode=file ext="nsp xci" False False True )  2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%UPDlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%UPDlist.txt" "extlist=nsp xci" )

goto upd_checkagain

echo.
:upd_checkagain
echo.
echo 你想做什么？
echo ......................................................................
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"2"，将另一个文件夹添加到列表中
echo 输入"3"，将另一个文件添加到列表中
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"6"，更改基本内容
echo 输入"i"，查看要处理的文件列表
echo 输入"b"，查看当前基本内容
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo 输入"e"，退出
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" -t nsp xci -tfile "%prog_dir%UPDlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" goto manual_Reentry
if /i "%eval%"=="1" goto upd_starts
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%UPDlist.txt" mode=folder ext="nsp xci" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%UPDlist.txt" mode=file ext="nsp xci" False False True )  2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%UPDlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%UPDlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="6" goto upd_ADD_BASE
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto upd_showlist
if /i "%eval%"=="b" goto upd_showbase
if /i "%eval%"=="r" goto upd_r_files
if /i "%eval%"=="z" del UPDlist.txt
goto upd_checkagain


:upd_showbase
cls
call :program_logo
ECHO -------------------------------------------------
ECHO                基本内容
ECHO -------------------------------------------------
echo %basefile%
goto upd_checkagain

:upd_r_files
set /p bs="输入要删除的文件数（从底部开始）： "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (UPDlist.txt) do (
set /a conta=!conta! + 1
)

set /a pos1=!conta!-!bs!
set /a pos2=!conta!
set string=

:upd_update_list1
if !pos1! GTR !pos2! ( goto :upd_update_list2 ) else ( set /a pos1+=1 )
set string=%string%,%pos1%
goto :upd_update_list1
:upd_update_list2
set string=%string%,
set skiplist=%string%
Set "skip=%skiplist%"
setlocal DisableDelayedExpansion
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<UPDlist.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>UPDlist.txt.new
endlocal
move /y "UPDlist.txt.new" "UPDlist.txt" >nul
endlocal

:upd_showlist
cls
call :program_logo
echo -------------------------------------------------
echo              更新模式 已激活
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (UPDlist.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (UPDlist.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 你加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto upd_checkagain

:upd_wrongchoice1
echo 错误的选项
echo ............
:upd_starts
echo *******************************************************
echo 您希望如何处理基本文件
echo *******************************************************
echo 输入"1"，以删除以前的更新
echo 输入"2"，以删除以前的DLC
echo 输入"3"，以删除以前的更新和DLC
echo.
ECHO ******************************************
echo 输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set cskip=none
if /i "%bs%"=="b" goto upd_checkagain
if /i "%bs%"=="1" set "cskip=upd"
if /i "%bs%"=="2" set "cskip=dlc"
if /i "%bs%"=="3" set "cskip=both"
if %cskip%=="none" goto upd_wrongchoice1
goto upd_pack_choice
:upd_wrongchoice2
echo 错误的选项
echo ............
:upd_pack_choice
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为xci
echo 输入"3"，全部都要
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set vrepack=none
if /i "%bs%"=="b" goto upd_checkagain
if /i "%bs%"=="1" set "vrepack=nsp"
if /i "%bs%"=="2" set "vrepack=xci"
if /i "%bs%"=="3" set "vrepack=both"
if %vrepack%=="none" goto upd_pack_choice
if /i "%skipRSVprompt%"=="true" set "patchRSV=-pv false"
if /i "%skipRSVprompt%"=="true" goto upd_KeyChange_skip
echo *******************************************************
echo 是否要魔改所需的系统版本
echo *******************************************************
echo 如果你选择魔改，它将被设置为与nca加密匹配，因此它只会在必要的
echo 情况下要求更新你的系统。
echo.
echo 输入"0"，不魔改
echo 输入"1"，魔改
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set patchRSV=none
if /i "%bs%"=="b" goto upd_checkagain
if /i "%bs%"=="0" set "patchRSV=-pv false"
if /i "%bs%"=="1" set "patchRSV=-pv true"
if /i "%patchRSV%"=="none" echo 错误的选项
if /i "%patchRSV%"=="none" goto m_RSV_wrongchoice
if /i "%bs%"=="0" goto upd_KeyChange_skip

:upd_KeyChange_wrongchoice
echo *******************************************************
echo 设置魔改最大系统版本号
echo *******************************************************
echo 根据您的选择，如果读取密钥生成值大于程序中指定的值，则密钥生
echo 成和RSV将降低到相应的密钥生成范围。
echo 这并不总是能降低固件需求。
echo.
echo 输入"f"，不魔改
echo 输入"0"，魔改版本FW 1.0
echo 输入"1"，魔改版本FW 2.0-2.3
echo 输入"2"，魔改版本FW 3.0
echo 输入"3"，魔改版本FW 3.0.1-3.0.2
echo 输入"4"，魔改版本FW 4.0.0-4.1.0
echo 输入"5"，魔改版本FW 5.0.0-5.1.0
echo 输入"6"，魔改版本FW 6.0.0-6.1.0
echo 输入"7"，魔改版本FW 6.2.0
echo 输入"8"，魔改版本FW 7.0.0-8.0.1
echo 输入"9"，魔改版本FW 8.1.0
echo 输入"10"，魔改版本FW 9.0.0-9.0.1
echo 输入"11"，魔改版本FW 9.1.0-11.0.3
echo 输入"12"，魔改版本FW 12.1.0
echo 输入"13"，魔改版本FW 13.0.0-13.2.1
echo 输入"14"，魔改版本FW 14.0.0-14.1.2
echo 输入"15"，魔改版本FW 15.0.0-15.0.1
echo 输入"16"，魔改版本FW 16.0.0-16.1.0
echo 输入"17"，魔改版本FW 17.0.0-17.0.1
echo 输入"18"，魔改版本FW 18.0.0-
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "vkey=none"
if /i "%bs%"=="b" goto upd_checkagain
if /i "%bs%"=="f" set "vkey=-kp false"
if /i "%bs%"=="0" set "vkey=-kp 0"
if /i "%bs%"=="0" set "capRSV=--RSVcap 0"
if /i "%bs%"=="1" set "vkey=-kp 1"
if /i "%bs%"=="1" set "capRSV=--RSVcap 65796"
if /i "%bs%"=="2" set "vkey=-kp 2"
if /i "%bs%"=="2" set "capRSV=--RSVcap 201327002"
if /i "%bs%"=="3" set "vkey=-kp 3"
if /i "%bs%"=="3" set "capRSV=--RSVcap 201392178"
if /i "%bs%"=="4" set "vkey=-kp 4"
if /i "%bs%"=="4" set "capRSV=--RSVcap 268435656"
if /i "%bs%"=="5" set "vkey=-kp 5"
if /i "%bs%"=="5" set "capRSV=--RSVcap 335544750"
if /i "%bs%"=="6" set "vkey=-kp 6"
if /i "%bs%"=="6" set "capRSV=--RSVcap 402653494"
if /i "%bs%"=="7" set "vkey=-kp 7"
if /i "%bs%"=="7" set "capRSV=--RSVcap 404750336"
if /i "%bs%"=="8" set "vkey=-kp 8"
if /i "%bs%"=="8" set "capRSV=--RSVcap 469762048"
if /i "%bs%"=="9" set "vkey=-kp 9"
if /i "%bs%"=="9" set "capRSV=--RSVcap 537919488"
if /i "%bs%"=="10" set "vkey=-kp 10"
if /i "%bs%"=="10" set "capRSV=--RSVcap 603979776"
if /i "%bs%"=="11" set "vkey=-kp 11"
if /i "%bs%"=="11" set "capRSV=--RSVcap 605028352"
if /i "%bs%"=="12" set "vkey=-kp 12"
if /i "%bs%"=="12" set "capRSV=--RSVcap 806354944"
if /i "%bs%"=="13" set "vkey=-kp 13"
if /i "%bs%"=="13" set "capRSV=--RSVcap 872415232"
if /i "%bs%"=="14" set "vkey=-kp 14"
if /i "%bs%"=="14" set "capRSV=--RSVcap 939524096"
if /i "%bs%"=="15" set "vkey=-kp 15"
if /i "%bs%"=="15" set "capRSV=--RSVcap 1006632960"
if /i "%bs%"=="16" set "vkey=-kp 16"
if /i "%bs%"=="16" set "capRSV=--RSVcap 1073741824"
if /i "%bs%"=="17" set "vkey=-kp 17"
if /i "%bs%"=="17" set "capRSV=--RSVcap 1140851708"
if /i "%bs%"=="18" set "vkey=-kp 18"
if /i "%bs%"=="18" set "capRSV=--RSVcap 1207960692"
if /i "%vkey%"=="none" echo 错误的选项
if /i "%vkey%"=="none" goto m_KeyChange_wrongchoice

:upd_KeyChange_skip
cls
call :program_logo

if exist "%w_folder%" RD /S /Q "%w_folder%" >NUL 2>&1
MD "%w_folder%" >NUL 2>&1
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" -cskip "%cskip%" --updbase "%basefile%"

for %%i in ("%basefile%") do (
set "filename=%%~ni"
)
call :getname

for /f "tokens=*" %%f in (UPDlist.txt) do (
set "name=%%~nf"
set "filename=%%~nxf"
set "orinput=%%f"
if "%%~nxf"=="%%~nf.nsp" call :UPD_nsp_manual
if "%%~nxf"=="%%~nf.xci" call :UPD_xci_manual
%pycommand% "%squirrel%" --strip_lines "%prog_dir%UPDlist.txt"
call :UPD_contador_NF
)
set "filename=%end_folder%[multi]"
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )

setlocal enabledelayedexpansion
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
set "gefolder=%fold_output%\!end_folder!"
if "%oforg%" EQU "inline" ( set "gefolder=%fold_output%" )
MD "%gefolder%" >NUL 2>&1
move "%w_folder%\*.xci" "%gefolder%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.nsp" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.ns*" "%gefolder%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%gefolder%\%filename%.nsp" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
:UPD_exit_choice
if exist UPDlist.txt del UPDlist.txt
if /i "%va_exit%"=="true" echo  程序将立即关闭
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto UPD_exit_choice

:UPD_nsp_manual
set "showname=%orinput%"
call :processing_message
call :squirrell
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" -tfile "%prog_dir%UPDlist.txt" %nf_cleaner% "%orinput%"
if "%zip_restore%" EQU "true" ( set "ziptarget=%orinput%" )
if "%zip_restore%" EQU "true" ( call :makezip )
call :thumbup
call :delay
exit /B

:UPD_xci_manual
set "showname=%orinput%"
call :processing_message
MD "%w_folder%" >NUL 2>&1
MD "%w_folder%\secure" >NUL 2>&1
MD "%w_folder%\normal" >NUL 2>&1
MD "%w_folder%\update" >NUL 2>&1
call :getname
echo ------------------------------------
echo 从XCI提取安全分区
echo ------------------------------------
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\secure" -tfile "%prog_dir%UPDlist.txt" %nf_cleaner% "%orinput%"
echo DONE
call :thumbup
call :delay
exit /B

:UPD_contador_NF
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (UPDlist.txt) do (
set /a conta=!conta! + 1
)
echo ...................................................
echo 仍然有 !conta! 个要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B

::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
:: 数据库生成模式
::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
:DBMODE
cls
call :program_logo
echo -----------------------------------------------
echo 数据库生成模式 已激活
echo -----------------------------------------------
if exist "DBL.txt" goto DBprevlist
goto DBmanual_INIT
:DBprevlist
set conta=0
for /f "tokens=*" %%f in (DBL.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (DBL.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del DBL.txt )
endlocal
if not exist "DBL.txt" goto DBmanual_INIT
ECHO .......................................................
ECHO 发现了以前的列表, 你想做什么？
:DBprevlist0
ECHO .......................................................
echo 输入"1"，从上一列表自动开始处理
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo .......................................................
echo 注意：输入3，您将在开始处理文件之前看到上一个列表，并且您可以
echo 添加和删除列表中的项目。
echo.
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="3" goto DBshowlist
if /i "%bs%"=="2" goto DBdelist
if /i "%bs%"=="1" goto DBstart_cleaning
if /i "%bs%"=="0" goto manual_Reentry
echo.
echo 错误的选项
goto DBprevlist0
:DBdelist
del DBL.txt
cls
call :program_logo
echo -----------------------------------------------
echo 单文件处理已激活
echo -----------------------------------------------
echo ..................................
echo 你已经开始一个新的列表
echo ..................................
:DBmanual_INIT
endlocal
ECHO ***********************************************
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
set /p bs="请将文件或文件夹拖到窗口上，然后按回车键： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
set "targt=%bs%"
dir "%bs%\" >nul 2>nul
if not errorlevel 1 goto DBcheckfolder
if exist "%bs%\" goto DBcheckfolder
goto DBcheckfile
:DBcheckfolder
%pycommand% "%squirrel%" -t nsp -tfile "%prog_dir%DBL.txt" -ff "%targt%"
%pycommand% "%squirrel%" -t nsx -tfile "%prog_dir%DBL.txt" -ff "%targt%"
goto DBcheckagain
:DBcheckfile
%pycommand% "%squirrel%" -t nsp -tfile "%prog_dir%DBL.txt" -ff "%targt%"
%pycommand% "%squirrel%" -t nsx -tfile "%prog_dir%DBL.txt" -ff "%targt%"
goto DBcheckagain
echo.
:DBcheckagain
echo 你想做什么？
echo ......................................................................
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="拖放文件/文件夹或设置选项： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto DBstart_cleaning
if /i "%bs%"=="e" goto DBsalida
if /i "%bs%"=="i" goto DBshowlist
if /i "%bs%"=="r" goto DBr_files
if /i "%bs%"=="z" del DBL.txt
set "targt=%bs%"
dir "%bs%\" >nul 2>nul
if not errorlevel 1 goto DBcheckfolder
if exist "%bs%\" goto DBcheckfolder
goto DBcheckfile
goto DBsalida

:DBr_files
set /p bs="输入要删除的文件数（从底部开始）： "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (DBL.txt) do (
set /a conta=!conta! + 1
)

set /a pos1=!conta!-!bs!
set /a pos2=!conta!
set string=

:DBupdate_list1
if !pos1! GTR !pos2! ( goto :DBupdate_list2 ) else ( set /a pos1+=1 )
set string=%string%,%pos1%
goto :DBupdate_list1
:DBupdate_list2
set string=%string%,
set skiplist=%string%
Set "skip=%skiplist%"
setlocal DisableDelayedExpansion
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<DBL.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>DBL.txt.new
endlocal
move /y "DBL.txt.new" "DBL.txt" >nul
endlocal

:DBshowlist
cls
call :program_logo
echo -------------------------------------------------
echo 单文件处理已激活
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                 要处理的文件
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (DBL.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (DBL.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 你加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto DBcheckagain

:DBs_cl_wrongchoice
echo 错误的选项
echo ............
:DBstart_cleaning
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 输入"1"，nutdb数据库生成
echo 输入"2"，扩展数据库生成
echo 输入"3"，生成无钥数据库（扩展）
echo 输入"4"，生成上述3个数据库
echo 输入"Z"，生成zip文件S
echo.
ECHO ******************************************
echo 或输入"0"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="0" goto DBcheckagain
if /i "%bs%"=="Z" set "vrepack=zip"
if /i "%bs%"=="Z" goto DBs_start
if /i "%bs%"=="1" set "dbformat=nutdb"
if /i "%bs%"=="1" goto DBs_GENDB
if /i "%bs%"=="2" set "dbformat=extended"
if /i "%bs%"=="2" goto DBs_GENDB
if /i "%bs%"=="3" set "dbformat=keyless"
if /i "%bs%"=="3" goto DBs_GENDB
if /i "%bs%"=="4" set "dbformat=all"
if /i "%bs%"=="4" goto DBs_GENDB
if %vrepack%=="none" goto DBs_cl_wrongchoice

:DBs_start
cls
call :program_logo
for /f "tokens=*" %%f in (DBL.txt) do (
set "name=%%~nf"
set "filename=%%~nxf"
set "orinput=%%f"
set "ziptarget=%%f"
if "%vrepack%" EQU "zip" ( set "zip_restore=true" )
if "%%~nxf"=="%%~nf.nsp" call :DBnsp_manual
if "%%~nxf"=="%%~nf.nsx" call :DBnsp_manual
if "%%~nxf"=="%%~nf.NSP" call :DBnsp_manual
if "%%~nxf"=="%%~nf.NSX" call :DBnsp_manual
%pycommand% "%squirrel%" --strip_lines "%prog_dir%DBL.txt"
call :DBcontador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
:DBs_exit_choice
if exist DBL.txt del DBL.txt
if /i "%va_exit%"=="true" echo  程序将立即关闭
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto s_exit_choice

:DBnsp_manual
set "filename=%name%"
set "showname=%orinput%"
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
call :squirrell

if "%vrepack%" EQU "zip" ( goto nsp_just_zip )

:DBnsp_just_zip
if "%zip_restore%" EQU "true" ( call :makezip )
rem call :getname
if "%vrename%" EQU "true" call :addtags_from_nsp
if "%zip_restore%" EQU "true" ( goto :nsp_just_zip2 )

:DBnsp_just_zip2

if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
RD /S /Q "%w_folder%" >NUL 2>&1

echo DONE
call :thumbup
call :delay

:DBend_nsp_manual
exit /B

:DBs_GENDB
for /f "tokens=*" %%f in (DBL.txt) do (
set "orinput=%%f"
set "db_file=%prog_dir%INFO\%dbformat%_DB.txt"
set "dbdir=%prog_dir%INFO\"
call :DBGeneration
%pycommand% "%squirrel%" --strip_lines "%prog_dir%DBL.txt"
call :DBcontador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto DBs_exit_choice

:DBGeneration
if not exist "%dbdir%" MD "%dbdir%">NUL 2>&1
%pycommand% "%squirrel%" --dbformat "%dbformat%" -dbfile "%db_file%" -tfile "%prog_dir%DBL.txt" -nscdb "%orinput%"
exit /B

:DBcontador_NF
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (DBL.txt) do (
set /a conta=!conta! + 1
)
echo ...................................................
echo 仍然有 !conta! 个要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B

::///////////////////////////////////////////////////
::NSCB文件信息模式
::///////////////////////////////////////////////////
:INFMODE
call "%infobat%" "%prog_dir%"
cls
goto TOP_INIT

::///////////////////////////////////////////////////
::NSCB_options.cmd 配置脚本
::///////////////////////////////////////////////////
:OPT_CONFIG
call "%batconfig%" "%op_file%" "%listmanager%" "%batdepend%"
cls
goto TOP_INIT


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
ECHO                                  VERSION 1.01 (LEGACY)
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
echo 希望你玩的开心
exit /B

:getname

if not exist %w_folder% MD %w_folder% >NUL 2>&1

set filename=%filename:[nap]=%
set filename=%filename:[xc]=%
set filename=%filename:[nc]=%
set filename=%filename:[rr]=%
set filename=%filename:[xcib]=%
set filename=%filename:[nxt]=%
set filename=%filename:[Trimmed]=%
echo %filename% >"%w_folder%\fname.txt"

::deletebrackets
for /f "usebackq tokens=1* delims=[" %%a in ("%w_folder%\fname.txt") do (
    set end_folder=%%a)
echo %end_folder%>"%w_folder%\fname.txt"
::deleteparenthesis
for /f "usebackq tokens=1* delims=(" %%a in ("%w_folder%\fname.txt") do (
    set end_folder=%%a)
echo %end_folder%>"%w_folder%\fname.txt"
::I also wanted to remove_(
set end_folder=%end_folder:_= %
set end_folder=%end_folder:~0,-1%
del "%w_folder%\fname.txt" >NUL 2>&1
if "%vrename%" EQU "true" ( set "filename=%end_folder%" )
exit /B

:makezip
echo.
echo Making zip for %ziptarget%
echo.
%pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% -o "%w_folder%\zip" --zip_combo "%ziptarget%"
%pycommand% "%squirrel%" -o "%w_folder%\zip" --NSP_c_KeyBlock "%ziptarget%"
%pycommand% "%squirrel%" --nsptitleid "%ziptarget%" >"%w_folder%\nsptitleid.txt"
if exist "%w_folder%\secure\*.dat" ( move "%w_folder%\secure\*.dat" "%w_folder%\zip" ) >NUL 2>&1

set /p titleid=<"%w_folder%\nsptitleid.txt"
del "%w_folder%\nsptitleid.txt" >NUL 2>&1
%pycommand% "%squirrel%" --nsptype "%ziptarget%" >"%w_folder%\nsptype.txt"
set /p type=<"%w_folder%\nsptype.txt"
del "%w_folder%\nsptype.txt" >NUL 2>&1
%pycommand% "%squirrel%" --ReadversionID "%ziptarget%">"%w_folder%\nspversion.txt"
set /p verID=<"%w_folder%\nspversion.txt"
set "verID=V%verID%"
del "%w_folder%\nspversion.txt" >NUL 2>&1
if "%type%" EQU "BASE" ( set "ctag=" )
if "%type%" EQU "UPDATE" ( set ctag=[UPD] )
if "%type%" EQU "DLC" ( set ctag=[DLC] )
%pycommand% "%squirrel%" -i "%ziptarget%">"%w_folder%\zip\fileinfo[%titleid%][%verID%]%ctag%.txt"
%pycommand% "%squirrel%" --filelist "%ziptarget%">"%w_folder%\zip\ORIGINAL_filelist[%titleid%][%verID%]%ctag%.txt"
"%zip%" -ifo "%w_folder%\zip" -zippy "%w_folder%\%titleid%[%verID%]%ctag%.zip"
RD /S /Q "%w_folder%\zip" >NUL 2>&1
exit /B

:processing_message
echo Processing %showname%
echo.
exit /B

:check_titlerights
%pycommand% "%squirrel%" --nsp_htrights "%target%">"%w_folder%\trights.txt"
set /p trights=<"%w_folder%\trights.txt"
del "%w_folder%\trights.txt" >NUL 2>&1
if "%trights%" EQU "TRUE" ( goto ct_true )
if "%vrepack%" EQU "nsp" ( set "vpack=none" )
if "%vrepack%" EQU "both" ( set "vpack=xci" )
:ct_true
exit /B


:addtags_from_nsp
%pycommand% "%squirrel%" --nsptitleid "%orinput%" >"%w_folder%\nsptitleid.txt"
set /p titleid=<"%w_folder%\nsptitleid.txt"
del "%w_folder%\nsptitleid.txt" >NUL 2>&1
%pycommand% "%squirrel%" --nsptype "%orinput%" >"%w_folder%\nsptype.txt"
set /p type=<"%w_folder%\nsptype.txt"
del "%w_folder%\nsptype.txt" >NUL 2>&1
if "%type%" EQU "BASE" ( set filename=%filename%[%titleid%][v0] )
if "%type%" EQU "UPDATE" ( set filename=%filename%[%titleid%][UPD] )
if "%type%" EQU "DLC" ( set filename=%filename%[%titleid%][DLC] )

exit /B
:addtags_from_xci
dir "%w_folder%\secure\*.cnmt.nca" /b  >"%w_folder%\ncameta.txt"
set /p ncameta=<"%w_folder%\ncameta.txt"
del "%w_folder%\ncameta.txt" >NUL 2>&1
set "ncameta=%w_folder%\secure\%ncameta%"
%pycommand% "%squirrel%" --ncatitleid "%ncameta%" >"%w_folder%\ncaid.txt"
set /p titleid=<"%w_folder%\ncaid.txt"
del "%w_folder%\ncaid.txt"
echo [%titleid%]>"%w_folder%\titleid.txt"

FINDSTR /L 000] "%w_folder%\titleid.txt">"%w_folder%\isbase.txt"
set /p c_base=<"%w_folder%\isbase.txt"
del "%w_folder%\isbase.txt"
FINDSTR /L 800] "%w_folder%\titleid.txt">"%w_folder%\isupdate.txt"
set /p c_update=<"%w_folder%\isupdate.txt"
del "%w_folder%\isupdate.txt"

set ttag=[DLC]

if [%titleid%] EQU %c_base% set ttag=[v0]
if [%titleid%] EQU %c_update% set ttag=[UPD]

set filename=%filename%[%titleid%][%ttag%]
del "%w_folder%\titleid.txt"
exit /B

:call_new
call "%prog_dir%\NSCB.bat"
exit /B

:salida
::pause
exit
