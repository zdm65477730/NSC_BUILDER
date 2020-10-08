@ECHO OFF
:TOP_INIT
set "prog_dir=%~dp0"
set "bat_name=%~n0"
set "ofile_name=%bat_name%_options.cmd"
set "opt_interface=Interface_options.cmd"
set "opt_server=Server_options.cmd"
Title NSC_Builder v1.01-b -- Profile: %ofile_name% -- by JulesOnTheRoad
set "list_folder=%prog_dir%lists"
::-----------------------------------------------------
::编辑此变量以链接其他选项文件
::-----------------------------------------------------
set "op_file=%~dp0zconfig\%ofile_name%"
set "opt_interface=%~dp0zconfig\%opt_interface%"
set "opt_server=%~dp0zconfig\%opt_server%"
::-----------------------------------------------------
::从选项文件复制选项
::-----------------------------------------------------
setlocal
if exist "%op_file%" call "%op_file%"
endlocal & (
REM 变量
set "safe_var=%safe_var%"
set "vrepack=%vrepack%"
set "vrename=%vrename%"
set "fi_rep=%fi_rep%"
set "zip_restore=%zip_restore%"
set "manual_intro=%manual_intro%"
set "va_exit=%va_exit%"
set "skipRSVprompt=%skipRSVprompt%"
set "oforg=%oforg%"
set "NSBMODE=%NSBMODE%"
set "romaji=%romaji%"
set "transnutdb=%transnutdb%"
set "workers=%workers%"
set "compression_lv=%compression_lv%"
set "compression_threads=%compression_threads%"
set "xci_export=%xci_export%"
set "MTP_verification=%MTP_verification%"
set "MTP_prioritize_NSZ=%MTP_prioritize_NSZ%"
set "MTP_exclude_xci_autinst=%MTP_exclude_xci_autinst%"
set "MTP_aut_ch_medium=%MTP_aut_ch_medium%"
set "MTP_chk_fw=%MTP_chk_fw%"
set "MTP_prepatch_kg=%MTP_prepatch_kg%"
set "MTP_prechk_Base=%MTP_prechk_Base%"
set "MTP_prechk_Upd=%MTP_prechk_Upd%"
set "MTP_saves_Inline=%MTP_saves_Inline%"
set "MTP_saves_AddTIDandVer=%MTP_saves_AddTIDandVer%"
set "MTP_pdrive_truecopy=%MTP_pdrive_truecopy%"
set "MTP_stc_installs=%MTP_stc_installs%"
set "MTP_ptch_inst_spec=%MTP_ptch_inst_spec%"

REM 拷贝功能
set "pycommand=%pycommand%"
set "buffer=%buffer%"
set "nf_cleaner=%nf_cleaner%"
set "patchRSV=%patchRSV%"
set "vkey=%vkey%"
set "capRSV=%capRSV%"
set "fatype=%fatype%"
set "fexport=%fexport%"
set "skdelta=%skdelta%"
REM 程序
set "squirrel=%nut%"
set "squirrel_lb=%squirrel_lb%"
set "MTP=%MTP%"
set "xci_lib=%xci_lib%"
set "nsp_lib=%nsp_lib%"
set "zip=%zip%"
set "hacbuild=%hacbuild%"
set "listmanager=%listmanager%"
set "batconfig=%batconfig%"
set "batdepend=%batdepend%"
set "infobat=%infobat%"
REM 文件
set "uinput=%uinput%"
set "dec_keys=%dec_keys%"
REM 文件夹
set "w_folder=%~dp0%w_folder%"
set "fold_output=%fold_output%"
set "zip_fold=%~dp0%zip_fold%"
)
::-----------------------------------------------------
::设置绝对路径
::-----------------------------------------------------
::程序完整路径
if exist "%~dp0%squirrel%" set "squirrel=%~dp0%squirrel%"
if exist "%~dp0%squirrel_lb%" set "squirrel_lb=%~dp0%squirrel_lb%"
if exist "%~dp0%xci_lib%"  set "xci_lib=%~dp0%xci_lib%"
if exist "%~dp0%nsp_lib%"  set "nsp_lib=%~dp0%nsp_lib%"
if exist "%~dp0%zip%"  set "zip=%~dp0%zip%"

if exist "%~dp0%hacbuild%"  set "hacbuild=%~dp0%hacbuild%"
if exist "%~dp0%listmanager%"  set "listmanager=%~dp0%listmanager%"
if exist "%~dp0%batconfig%"  set "batconfig=%~dp0%batconfig%"
if exist "%~dp0%batdepend%"  set "batdepend=%~dp0%batdepend%"
if exist "%~dp0%infobat%"  set "infobat=%~dp0%infobat%"
::重要文件完整路径
if exist "%~dp0%uinput%"  set "uinput=%~dp0%uinput%"
if exist "%~dp0%dec_keys%"  set "dec_keys=%~dp0%dec_keys%"
::输出文件夹
CD /d "%~dp0"
if not exist "%fold_output%" MD "%fold_output%"
if not exist "%fold_output%" MD "%~dp0%fold_output%"
if exist "%~dp0%fold_output%"  set "fold_output=%~dp0%fold_output%"
::-----------------------------------------------------
::多项检查
::-----------------------------------------------------
::选项文件检查
if not exist "%op_file%" ( goto missing_things )
::程序检查
if not exist "%squirrel%" ( goto missing_things )
if not exist "%xci_lib%" ( goto missing_things )
if not exist "%nsp_lib%" ( goto missing_things )
if not exist "%zip%" ( goto missing_things )

if not exist "%hacbuild%" ( goto missing_things )
if not exist "%listmanager%" ( goto missing_things )
if not exist "%batconfig%" ( goto missing_things )
if not exist "%infobat%" ( goto missing_things )
::重要文件检查
if not exist "%dec_keys%" ( goto missing_things )
::-----------------------------------------------------
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1

::检查用户是否拖动文件夹或文件
if "%~1"=="" goto manual
if "%vrepack%" EQU "nodelta" goto aut_rebuild_nodeltas
if "%vrepack%" EQU "rebuild" goto aut_rebuild_nsp
dir "%~1\" >nul 2>nul
if not errorlevel 1 goto folder
if exist "%~1\" goto folder
goto file

:folder
if "%fi_rep%" EQU "multi" goto folder_mult_mode
if "%fi_rep%" EQU "baseid" goto folder_packbyid
goto folder_ind_mode

::自动模式。 单文件重打包处理选项
:folder_ind_mode
rem if "%fatype%" EQU "-fat fat32" goto folder_ind_mode_fat32
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

set "filename=%%~nf"
set "orinput=%%f"
set "showname=%orinput%"

MD "%w_folder%"
REM echo %safe_var%>safe.txt
call :squirrell

if "%zip_restore%" EQU "true" ( set "ziptarget=%%f" )
if "%zip_restore%" EQU "true" ( call :makezip )
call :getname
REM setlocal enabledelayedexpansion
REM set vpack=!vrepack!
REM endlocal & ( set "vpack=!vrepack!" )

REM if "%trn_skip%" EQU "true" ( call :check_titlerights )
if "%vrename%" EQU "true" ( call :addtags_from_nsp )

if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "nsp" -dc "%%f" )
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "xci" -dc "%%f" )
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "both" -dc "%%f" )

if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
)

::*************
::NSZ文件
::*************
for /r "%~1" %%f in (*.nsz) do (
set "target=%%f"
if exist "%w_folder%" RD /s /q "%w_folder%" >NUL 2>&1

set "filename=%%~nf"
set "orinput=%%f"
set "showname=%orinput%"

MD "%w_folder%"
REM echo %safe_var%>safe.txt
call :squirrell

if "%zip_restore%" EQU "true" ( set "ziptarget=%%f" )
if "%zip_restore%" EQU "true" ( call :makezip )
call :getname
REM setlocal enabledelayedexpansion
REM set vpack=!vrepack!
REM endlocal & ( set "vpack=!vrepack!" )

REM if "%trn_skip%" EQU "true" ( call :check_titlerights )
if "%vrename%" EQU "true" ( call :addtags_from_nsp )

if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "nsp" -dc "%%f" )
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "xci" -dc "%%f" )
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "both" -dc "%%f" )

if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
)

::XCI文件
for /r "%~1" %%f in (*.xci) do (
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
set "filename=%%~nf"
set "orinput=%%f"
set "showname=%orinput%"

MD "%w_folder%"
call :getname
if "%vrename%" EQU "true" ( call :addtags_from_xci )

if "%vrepack%" EQU "nsp" (  %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "nsp" -dc "%%f" )
if "%vrepack%" EQU "xci" (  %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "xci" -dc "%%f" )
if "%vrepack%" EQU "both" (  %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "both" -dc "%%f" )

if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理! *************
ECHO ---------------------------------------------------
goto aut_exit_choice

::XCZ文件
for /r "%~1" %%f in (*.xcz) do (
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
set "filename=%%~nf"
set "orinput=%%f"
set "showname=%orinput%"

MD "%w_folder%"
call :getname
if "%vrename%" EQU "true" ( call :addtags_from_xci )

if "%vrepack%" EQU "nsp" (  %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "nsp" -dc "%%f" )
if "%vrepack%" EQU "xci" (  %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "xci" -dc "%%f" )
if "%vrepack%" EQU "both" (  %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "both" -dc "%%f" )

if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理! *************
ECHO ---------------------------------------------------
goto aut_exit_choice

:folder_ind_mode_fat32
CD /d "%prog_dir%"
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
echo 完成
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
echo 完成
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
echo 完成
call :thumbup
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto aut_exit_choice

::自动模式。多文件处理选项
:folder_mult_mode
rem if "%fatype%" EQU "-fat fat32" goto folder_mult_mode_fat32
call :program_logo
echo --------------------------------------
echo 自动模式。多文件处理已设置
echo --------------------------------------
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
if exist "%prog_dir%mlist.txt" del "%prog_dir%mlist.txt" >NUL 2>&1

echo -正在生成文件列表
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%mlist.txt" -ff "%~1"
echo   完成

if "%vrepack%" EQU "nsp" echo ......................................
if "%vrepack%" EQU "nsp" echo 正在打包文件夹内容到NSP
if "%vrepack%" EQU "nsp" echo ......................................
if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t cnsp -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )
if "%vrepack%" EQU "nsp" echo.

if "%vrepack%" EQU "xci" echo ......................................
if "%vrepack%" EQU "xci" echo 正在打包文件夹内容到XCI
if "%vrepack%" EQU "xci" echo ......................................
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t xci -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )
if "%vrepack%" EQU "xci" echo.

if "%vrepack%" EQU "both" echo ......................................
if "%vrepack%" EQU "both" echo 正在打包文件夹内容到NSP
if "%vrepack%" EQU "both" echo ......................................
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t cnsp -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )
if "%vrepack%" EQU "both" echo.

if "%vrepack%" EQU "both" echo ......................................
if "%vrepack%" EQU "both" echo 正在打包文件夹内容到XCI
if "%vrepack%" EQU "both" echo ......................................
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t xci -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )
if "%vrepack%" EQU "both" echo.

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
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -tfile "%w_folder%\filename.txt" -ifo "%w_folder%\archfolder" -archive "%gefolder%" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
call :thumbup
goto aut_exit_choice

:folder_mult_mode_fat32
CD /d "%prog_dir%"
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
echo 完成
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
echo 完成
call :thumbup
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto aut_exit_choice

:folder_packbyid
rem if "%fatype%" EQU "-fat fat32" goto folder_mult_mode_fat32
call :program_logo
echo --------------------------------------
echo 自动模式。通过ID打包已设置
echo --------------------------------------
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
if exist "%prog_dir%mlist.txt" del "%prog_dir%mlist.txt" >NUL 2>&1
set "mlistfol=%list_folder%\a_multi"
if not exist "%list_folder%" MD "%list_folder%" >NUL 2>&1
if not exist "%mlistfol%" MD "%mlistfol%" >NUL 2>&1

echo - Generating filelist
%pycommand% "%squirrel%" -t nsp xci -tfile "%prog_dir%mlist.txt" -ff "%~1"
echo   完成
echo - 正在分割文件列表
%pycommand% "%squirrel%" -splid "%mlistfol%" -tfile "%prog_dir%mlist.txt"
if "%vrepack%" EQU "nsp" set "vrepack=cnsp"
if "%vrepack%" EQU "both" set "vrepack=cboth"
goto m_process_jobs2

:aut_rebuild_nodeltas
call :program_logo
echo --------------------------------------
echo 自动模式。重建不包含增量部分
echo --------------------------------------
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
if exist "%prog_dir%list.txt" del "%prog_dir%list.txt" >NUL 2>&1
%pycommand% "%squirrel%" -t nsp xci -tfile "%prog_dir%list.txt" -ff "%~1"
echo   完成
goto s_KeyChange_skip

:aut_rebuild_nsp
call :program_logo
echo --------------------------------------
echo 自动模式。按cnmt顺序重新生成nsp
echo --------------------------------------
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
if exist "%prog_dir%list.txt" del "%prog_dir%list.txt" >NUL 2>&1
%pycommand% "%squirrel%" -t nsp xci -tfile "%prog_dir%list.txt" -ff "%~1"
echo   完成
goto s_KeyChange_skip

:file
call :program_logo
if "%~x1"==".nsp" ( goto nsp )
if "%~x1"==".xci" ( goto xci )
if "%~x1"==".nsz" ( goto nsp )
if "%~x1"==".xcz" ( goto xci )
if "%~x1"==".*" ( goto other )
:other
echo 拖动不包含有效文件。程序只接受XCI或NSP文件。
echo 您将被重定向到手动模式。
pause
goto manual

:nsp
rem if "%fatype%" EQU "-fat fat32" goto file_nsp_fat32
set "orinput=%~f1"
set "filename=%~n1"
set "target=%~1"
set "showname=%orinput%"

if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
call :squirrell

if "%zip_restore%" EQU "true" ( set "ziptarget=%~1" )
if "%zip_restore%" EQU "true" ( call :makezip )
MD "%w_folder%"
call :getname
if "%vrename%" EQU "true" call :addtags_from_nsp

if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "nsp" -dc "%~1" )
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "xci" -dc "%~1" )
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "both" -dc "%~1"  )

if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
goto aut_exit_choice

:file_nsp_fat32
CD /d "%prog_dir%"
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
echo 完成
call :thumbup
goto aut_exit_choice

:xci
rem if "%fatype%" EQU "-fat fat32" goto file_xci_fat32
set "filename=%~n1"
set "orinput=%~f1"
set "showname=%orinput%"

if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"
MD "%w_folder%\secure"
call :getname

if "%vrename%" EQU "true" call :addtags_from_xci

if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "nsp" -dc "%~1" )
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "xci" -dc "%~1" )
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "both" -dc "%~1"  )

MD "%fold_output%\" >NUL 2>&1

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
goto aut_exit_choice

:file_xci_fat32
CD /d "%prog_dir%"
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
echo 完成
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
echo 完成
call :thumbup
goto aut_exit_choice

:aut_exit_choice
if /i "%va_exit%"=="true" echo 程序将立即关闭
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
::if "%manual_intro%" EQU "update" ( goto UPDMODE )
goto manual_Reentry

:manual_Reentry
cls
if "%NSBMODE%" EQU "legacy" call "%prog_dir%ztools\LEGACY.bat"
call :program_logo
ECHO .......................................................
echo 输入 "1"  单文件处理   （XCI和NSP互转：常用功能）
echo 输入 "2"  多文件处理   （XCI整合用：常用功能）
echo 输入 "3"  文件拆分     （XCI或NSP拆包：常用功能）
echo 输入 "4"  文件信息查询 （查询游戏版本信息：常用功能）
echo 输入 "5"  数据库构建   （重建游戏文件数据库：不常用）
echo 输入 "6"  高级选项     （修补链接账户等：常用功能）
echo 输入 "7"  合并模式     （文件合并：不常用）
echo 输入 "8"  压缩和解压   （XCI和XCZ以及NSP和NSZ的互转：常用功能）
echo 输入 "9"  文件还原     （从备份文件恢复原始包：不常用）
echo 输入 "10" 文件管理     （功能暂不完善）
echo 输入 "0"  配置选项     （程序配置：常用功能）
echo.
echo 输入"D"，进入谷歌网盘模式
echo 输入"M"，进入MTP模式
echo 输入"L"，进入传统模式
echo 输入"I"，进入界面配置
echo 输入"S"，进入服务器配置
echo .......................................................
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="1" goto normalmode
if /i "%bs%"=="2" goto multimode
if /i "%bs%"=="3" goto SPLMODE
if /i "%bs%"=="4" goto INFMODE
if /i "%bs%"=="5" goto DBMODE
if /i "%bs%"=="6" goto ADVmode
if /i "%bs%"=="7" goto JOINmode
if /i "%bs%"=="8" goto ZSTDmode
if /i "%bs%"=="9" goto RSTmode
if /i "%bs%"=="10" goto MNGmode
if /i "%bs%"=="M" goto MTPMode
if /i "%bs%"=="D" goto DriveMode
if /i "%bs%"=="L" goto LegacyMode
if /i "%bs%"=="I" goto InterfaceTrigger
if /i "%bs%"=="S" goto ServerTrigger
if /i "%bs%"=="0" goto OPT_CONFIG
goto manual_Reentry

:ADVmode
call "%prog_dir%ztools\ADV.bat"
goto manual_Reentry
:JOINmode
call "%prog_dir%ztools\JOINER.bat"
goto manual_Reentry
:ZSTDmode
call "%prog_dir%ztools\ZSTD.bat"
goto manual_Reentry
:RSTmode
call "%prog_dir%ztools\RST.bat"
goto manual_Reentry
:MNGmode
call "%prog_dir%ztools\MNG.bat"
goto manual_Reentry
:LegacyMode
call "%prog_dir%ztools\LEGACY.bat"
goto manual_Reentry
:MTPMode
call "%prog_dir%ztools\MtpMode.bat"
goto manual_Reentry
:DriveMode
call "%prog_dir%ztools\DriveMode.bat"
goto manual_Reentry
:InterfaceTrigger
call Interface.bat
goto manual_Reentry
:ServerTrigger
call Server.bat
goto manual_Reentry
REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM 手动模式开始。单文件处理
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
echo 注意: 输入"3"，在开始处理文件之前，您将看到上一个列表，并且
echo 您可以添加或者删除内容到列表里。
echo.
ECHO *************************************************
echo 或者输入"0"，以返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="3" goto showlist
if /i "%bs%"=="2" goto delist
if /i "%bs%"=="1" goto start_cleaning
if /i "%bs%"=="0" goto manual_Reentry
echo.
echo BAD CHOICE
goto prevlist0
:delist
del list.txt
cls
call :program_logo
echo -----------------------------------------------
echo 单文件处理已激活
echo -----------------------------------------------
echo ..................................
echo 您已决定创建一个新的列表
echo ..................................
:manual_INIT
endlocal
ECHO ***********************************************
echo 输入"1"，将文件夹添加到列表
echo 输入"2"，将文件添加到列表
echo 输入"3"，通过本地文件库，将文件添加到列表
echo 输入"4"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz nsx xcz -tfile "%prog_dir%list.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto manual_Reentry
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%list.txt" mode=folder ext="nsp xci nsz nsx xcz" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%list.txt" mode=file ext="nsp xci nsz nsx xcz" False False True ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%list.txt" "extlist=nsp xci nsz nsx xcz" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%list.txt" "extlist=nsp xci nsz nsx xcz" )
goto checkagain
echo.
:checkagain
echo 你想做什么？
echo ......................................................................
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"2"，将另一个文件夹添加到列表
echo 输入"3"，将另一个文件添加到列表
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或者输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz nsx xcz -tfile "%prog_dir%list.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" goto manual_Reentry
if /i "%eval%"=="1" goto start_cleaning
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg  "%prog_dir%list.txt" mode=folder ext="nsp xci nsz nsx xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg  "%prog_dir%list.txt" mode=file ext="nsp xci nsz nsx xcz" False False True )  2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%list.txt" "extlist=nsp xci nsz nsx xcz" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%list.txt" "extlist=nsp xci nsz nsx xcz" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del list.txt

goto checkagain

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
echo 您已添加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto checkagain

:s_cl_wrongchoice
echo 错误的选择
echo ............
:start_cleaning
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为XCI
echo 输入"3"，重新打包NSP和XCI
echo.
echo 特殊选项：
echo 输入"4"，删除NSP文件中的增量
echo 输入"5"，重命名XCI或NSP文件
echo 输入"6"，XCI超级裁剪\裁剪\不裁剪
echo 输入"7"，按cnmt顺序重建nsp
echo 输入"8"，激活验证
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" set "vrepack=nsp"
if /i "%bs%"=="2" set "vrepack=xci"
if /i "%bs%"=="3" set "vrepack=both"
if /i "%bs%"=="4" set "vrepack=nodelta"
if /i "%bs%"=="4" goto s_KeyChange_skip
if /i "%bs%"=="5" set "vrepack=renamef"
if /i "%bs%"=="5" goto rename
if /i "%bs%"=="6" goto s_trimmer_selection
if /i "%bs%"=="7" set "vrepack=rebuild"
if /i "%bs%"=="7" goto s_KeyChange_skip
if /i "%bs%"=="8" set "vrepack=verify"
if /i "%bs%"=="8" goto s_vertype
if %vrepack%=="none" goto s_cl_wrongchoice
:s_RSV_wrongchoice
if /i "%skipRSVprompt%"=="true" set "patchRSV=-pv false"
if /i "%skipRSVprompt%"=="true" goto s_KeyChange_skip
echo *******************************************************
echo 是否要魔改游戏所需的系统版本
echo *******************************************************
echo 如果您选择魔改系统版本，它将会被设置为相应的NCA加密
echo 所以系统只会在系统版本和魔改软件版本不匹配时，请求更新系统
echo.
echo 输入"0"，不魔改游戏所需系统版本
echo 输入"1"，魔改游戏所需系统版本
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
if /i "%patchRSV%"=="none" echo 错误的选择
if /i "%patchRSV%"=="none" goto s_RSV_wrongchoice
if /i "%bs%"=="0" goto s_KeyChange_skip

:s_KeyChange_wrongchoice
echo *******************************************************
echo 设置魔改的最大系统版本
echo *******************************************************
echo 取决于您的选择，如果魔改的密钥值大于程序中指定的值，
echo 魔改的密钥和RSV将会低于程序最低系统版本要求。
echo 程序将永远不能低于系统固件要求运行。
echo.
echo 输入"f"，不魔改
echo 输入"0"，魔改版本FW 1.0
echo 输入"1"，魔改版本FW 2.0-2.3
echo 输入"2"，魔改版本FW 3.0
echo 输入"3"，魔改版本FW 3.0.1-3.02
echo 输入"4"，魔改版本FW 4.0.0-4.1.0
echo 输入"5"，魔改版本FW 5.0.0-5.1.0
echo 输入"6"，魔改版本FW 6.0.0-6.1.0
echo 输入"7"，魔改版本FW 6.2.0
echo 输入"8"，魔改版本FW 7.0.0-8.0.1
echo 输入"9"，魔改版本FW 8.1.0
echo 输入"10"，魔改版本FW 9.0.0-9.0.1
echo 输入"11"，魔改版本FW 9.1.0-10.2.0
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
if /i "%vkey%"=="none" echo 错误的选择
if /i "%vkey%"=="none" goto s_KeyChange_wrongchoice
goto s_KeyChange_skip

:s_trimmer_selection
echo *******************************************************
echo 超级清理、清理、不清理
echo *******************************************************
echo 描述:
echo - 超级清理
echo   删除系统固件更新，清空更新分区，
echo   删除最终和中间填充，删除LOGO分区，
echo   删除游戏更新，保留已有的游戏证书（适用于tinfoil安装）
echo - 超级清理但保留游戏更新数据
echo   和超级清理一样，但保留游戏更新数据
echo - 清理
echo   删除最后的填充（空数据）
echo - 不清理
echo   不执行数据清理
echo.
echo 输入"1"，超级清理
echo 输入"2"，超级清理但保留游戏更新数据
echo 输入"3"，清理
echo 输入"4"，不清理
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "vrepack=none"
if /i "%bs%"=="1" set "vrepack=xci_supertrimmer"
if /i "%bs%"=="2" set "vrepack=xci_supertrimmer_keep_upd"
if /i "%bs%"=="3" set "vrepack=xci_trimmer"
if /i "%bs%"=="4" set "vrepack=xci_untrimmer"
if /i "%vrepack%"=="none" echo 错误的选择
if /i "%vrepack%"=="none" goto s_trimmer_selection
goto s_KeyChange_skip

:s_vertype
echo *******************************************************
echo 验证类型
echo *******************************************************
echo 选择验证的级别.
echo 解密 - 文件可读，票证正确，没有文件丢失
echo 签名 - 检查Nintendo签名的标头，为NSCB修改计算原始标头
echo 哈希 - 检查与文件名匹配的文件当前和原始哈希值是否一致
echo.
echo 注意：如果您通过文件流方法读取远程服务上的文件，则推荐使用解密或签名
echo.
echo 输入 "1" 使用解密验证（快速）
echo 输入 "2" 使用解密+签名验证（快速）
echo 输入 "3" 使用解密+签名+HASH验证（慢）
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "verif=none"
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" set "verif=lv1"
if /i "%bs%"=="2" set "verif=lv2"
if /i "%bs%"=="3" set "verif=lv3"
if /i "%verif%"=="none" echo 错误的选择
if /i "%verif%"=="none" echo.
if /i "%verif%"=="none" goto s_vertype

:s_KeyChange_skip
echo Filtering extensions from list according to options chosen
if "%vrepack%" EQU "xci_supertrimmer" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%list.txt","ext=xci","token=False",Print="False" )
if "%vrepack%" EQU "xci_supertrimmer_keep_upd" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%list.txt","ext=xci","token=False",Print="False" )
if "%vrepack%" EQU "xci_trimmer" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%list.txt","ext=xci","token=False",Print="False" )
if "%vrepack%" EQU "xci_untrimmer" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%list.txt","ext=xci","token=False",Print="False" )
if "%vrepack%" EQU "rebuild" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%list.txt","ext=nsp nsz","token=False",Print="False" )
if "%vrepack%" EQU "nodelta" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%list.txt","ext=nsp nsz","token=False",Print="False" )
if "%fatype%" EQU "-fat fat32" echo Fat32 selected, removing nsz and xcz from input list
if "%fatype%" EQU "-fat fat32" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%list.txt","ext=nsp nsx xci","token=False",Print="False" )
cls
call :program_logo

for /f "tokens=*" %%f in (list.txt) do (
set "name=%%~nf"
set "filename=%%~nxf"
set "orinput=%%f"
set "ziptarget=%%f"

if "%%~nxf"=="%%~nf.nsp" call :nsp_manual
if "%%~nxf"=="%%~nf.nsz" call :nsp_manual
if "%%~nxf"=="%%~nf.xci" call :xci_manual
if "%%~nxf"=="%%~nf.xcz" call :xci_manual
%pycommand% "%squirrel%" --strip_lines "%prog_dir%list.txt" "1" "true"
rem call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:rename
:s_rename_wrongchoice1
echo.
echo *******************************************************
echo 重命名类型
echo *******************************************************
echo 正常模式：
echo 输入"1"，始终重命名
echo 输入"2"，如果存在[TITLEID]则不重命名
echo 输入"3"，如果[TITLEID]等于计算值不重命名
echo 输入"4"，仅添加ID
echo 输入"5"，添加ID+标记并将名称保留到[
echo.
echo Sanitize:
echo 输入"6"，从文件名中删除错误字符
echo 输入"7"，将日语/汉语转换为罗马字
echo.
echo 清理标签：
echo 输入"8"，从文件名中删除[]标签
echo 输入"9"，从文件名中删除()标签
echo 输入"10"，从文件名中删除[]和()标签
echo 输入"11"，从第一个[标签开始删除TITLE
echo 输入"12"，从第一个(标签开始删除TITLE
echo.
ECHO ******************************************
echo 或输入"0"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "renmode=none"
if /i "%bs%"=="0" goto checkagain
if /i "%bs%"=="1" set "renmode=force"
if /i "%bs%"=="1" set "oaid=false"
if /i "%bs%"=="2" set "renmode=skip_corr_tid"
if /i "%bs%"=="2" set "oaid=false"
if /i "%bs%"=="3" set "renmode=skip_if_tid"
if /i "%bs%"=="3" set "oaid=false"
if /i "%bs%"=="4" set "renmode=skip_corr_tid"
if /i "%bs%"=="4" set "oaid=true"
if /i "%bs%"=="5" set "renmode=skip_corr_tid"
if /i "%bs%"=="5" set "oaid=idtag"
if /i "%bs%"=="6" goto sanitize
if /i "%bs%"=="7" goto romaji

if /i "%bs%"=="8" set "tagtype=[]"
if /i "%bs%"=="8" goto filecleantags
if /i "%bs%"=="9" set "tagtype=()"
if /i "%bs%"=="9" goto filecleantags
if /i "%bs%"=="10" set "tagtype=false"
if /i "%bs%"=="10" goto filecleantags
if /i "%bs%"=="11" set "tagtype=["
if /i "%bs%"=="11" goto filecleantags
if /i "%bs%"=="12" set "tagtype=("
if /i "%bs%"=="12" goto filecleantags

if /i "%renmode%"=="none" echo 错误的选择
if /i "%renmode%"=="none" goto s_rename_wrongchoice1
echo.
:s_rename_wrongchoice2
echo *******************************************************
echo 添加版本号
echo *******************************************************
echo 将内容版本号添加到文件名
echo.
echo 输入"1"，添加版本号
echo 输入"2"，不添加版本号
echo 输入"3"，如果版本=0，不在XCI中添加版本
echo.
ECHO *********************************************
echo 或输入"b"，返回重命名类型
echo 或输入"0"，返回列表选项
ECHO *********************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "nover=none"
if /i "%bs%"=="0" goto checkagain
if /i "%bs%"=="b" goto s_rename_wrongchoice1
if /i "%bs%"=="1" set "nover=false"
if /i "%bs%"=="2" set "nover=true"
if /i "%bs%"=="3" set "nover=xci_no_v0"
if /i "%nover%"=="none" echo 错误的选择
if /i "%nover%"=="none" goto s_rename_wrongchoice2
echo.
:s_rename_wrongchoice3
echo *******************************************************
echo 添加语言字符串
echo *******************************************************
echo 为游戏和更新添加语言标记
echo.
echo 输入"1"，不添加语言字符串
echo 输入"2"，添加语言字符串
echo.
echo 注意：无法从DLCs中读取语言,
echo 因此此选项不会影响它们
echo.
ECHO *********************************************
echo 或输入"b"，返回添加版本号
echo 或输入"0"，返回列表选项
ECHO *********************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "addlangue=none"
if /i "%bs%"=="0" goto checkagain
if /i "%bs%"=="b" goto s_rename_wrongchoice2
if /i "%bs%"=="1" set "addlangue=false"
if /i "%bs%"=="2" set "addlangue=true"
if /i "%addlangue%"=="none" echo 错误的选择
if /i "%addlangue%"=="none" goto s_rename_wrongchoice3
echo.
:s_rename_wrongchoice4
echo *******************************************************
echo DLC命名回滚
echo *******************************************************
echo 当前版本将dlc名称在nutdb检索，此选项说明如果无法检索到名称，
echo 则回滚为空。
echo.
echo 通常命令格式 基本名 [内容名]
echo 选项3格式 基本名 [内容名] [DLC号]
echo.
echo 输入"1"，保持DLC名称
echo 输入"2"，重命名为DLC编号
echo 输入"3"，以保持名称并添加dlc编号为标签
echo.
ECHO *********************************************
echo 或输入"b"，返回添加保留DLC名称
echo 或输入"0"，返回列表选项
ECHO *********************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set "dlcrname=none"
if /i "%bs%"=="0" goto checkagain
if /i "%bs%"=="b" goto s_rename_wrongchoice3
if /i "%bs%"=="1" set "dlcrname=false"
if /i "%bs%"=="2" set "dlcrname=true"
if /i "%bs%"=="3" set "dlcrname=tag"
if /i "%dlcrname%"=="none" echo 错误的选择
if /i "%dlcrname%"=="none" goto s_rename_wrongchoice4
echo.
cls
call :program_logo
set "workers=-threads 1"
for /f "tokens=*" %%f in (list.txt) do (
%pycommand% "%squirrel%" -renf "single" -tfile "%prog_dir%list.txt" -t nsp xci nsx nsz xcz -renm %renmode% -nover %nover% -oaid %oaid% -addl %addlangue% -roma %romaji% -dlcrn %dlcrname% %workers%
if "%workers%" EQU "-threads 1" ( %pycommand% "%squirrel%" --strip_lines "%prog_dir%list.txt" "1" "true" )
if "%workers%" NEQ "-threads 1" ( call :renamecheck )
rem call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:renamecheck
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (list.txt) do (
set /a conta=!conta! + 1
)
if !conta! LEQ 0 ( del list.txt )
endlocal
if not exist "list.txt" goto s_exit_choice
exit /B

:sanitize
cls
call :program_logo
for /f "tokens=*" %%f in (list.txt) do (
%pycommand% "%squirrel%" -snz "single" -tfile "%prog_dir%list.txt" -t nsp xci nsx nsz xcz
%pycommand% "%squirrel%" --strip_lines "%prog_dir%list.txt" "1" "true"
rem call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:romaji
cls
call :program_logo
for /f "tokens=*" %%f in (list.txt) do (
%pycommand% "%squirrel%" -roma "single" -tfile "%prog_dir%list.txt" -t nsp xci nsx nsz xcz
%pycommand% "%squirrel%" --strip_lines "%prog_dir%list.txt" "1" "true"
rem call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice


:filecleantags
cls
call :program_logo
for /f "tokens=*" %%f in (list.txt) do (
%pycommand% "%squirrel%" -cltg "single" -tfile "%prog_dir%list.txt" -t nsp xci nsx nsz xcz -tgtype "%tagtype%"
%pycommand% "%squirrel%" --strip_lines "%prog_dir%list.txt" "1" "true"
rem call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

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
rem if "%fatype%" EQU "-fat fat32" goto nsp_manual_fat32
rem set "filename=%name%"
rem set "showname=%orinput%"
if "%zip_restore%" EQU "true" ( call :makezip )
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%" >NUL 2>&1
call :squirrell

if "%vrename%" EQU "true" call :addtags_from_nsp

if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "nsp" -dc "%orinput%" -tfile "%prog_dir%list.txt")
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "xci" -dc "%orinput%" -tfile "%prog_dir%list.txt")
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "both" -dc "%orinput%" -tfile "%prog_dir%list.txt")
if "%vrepack%" EQU "nodelta" ( %pycommand% "%squirrel%" %buffer% --xml_gen "true" -o "%w_folder%" -tfile "%prog_dir%list.txt" --erase_deltas "")
if "%vrepack%" EQU "rebuild" ( %pycommand% "%squirrel%" %buffer% %skdelta% --xml_gen "true" -o "%w_folder%" -tfile "%prog_dir%list.txt" --rebuild_nsp "")
if "%vrepack%" EQU "verify" ( %pycommand% "%squirrel%" %buffer% -vt "%verif%" -tfile "%prog_dir%list.txt" -v "")
if "%vrepack%" EQU "verify" ( goto end_nsp_manual )

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
call :delay
goto end_nsp_manual

:nsp_manual_fat32
CD /d "%prog_dir%"
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
echo 完成
call :thumbup
call :delay
goto end_nsp_manual

:end_nsp_manual
exit /B

:xci_manual
rem if "%fatype%" EQU "-fat fat32" goto xci_manual_fat32
::XCI文件
if exist "%w_folder%" rmdir /s /q "%w_folder%" >NUL 2>&1
MD "%w_folder%"

set "filename=%name%"
set "showname=%orinput%"

if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "nsp" -dc "%orinput%" -tfile "%prog_dir%list.txt")
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "xci" -dc "%orinput%" -tfile "%prog_dir%list.txt")
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -o "%w_folder%" -t "both" -dc "%orinput%" -tfile "%prog_dir%list.txt")
if "%vrepack%" EQU "xci_supertrimmer" ( %pycommand% "%squirrel%" %buffer% -o "%w_folder%" -tfile "%prog_dir%list.txt" -xci_st "%orinput%")
if "%vrepack%" EQU "xci_supertrimmer_keep_upd" ( %pycommand% "%squirrel%" %buffer% -o "%w_folder%" -t "xci" -dc "%orinput%" -tfile "%prog_dir%list.txt" )
if "%vrepack%" EQU "xci_trimmer" ( %pycommand% "%squirrel%" %buffer% -o "%w_folder%" -tfile "%prog_dir%list.txt" -xci_tr "%orinput%")
if "%vrepack%" EQU "xci_untrimmer" ( %pycommand% "%squirrel%" %buffer% -o "%w_folder%" -tfile "%prog_dir%list.txt" -xci_untr "%orinput%" )
if "%vrepack%" EQU "verify" ( %pycommand% "%squirrel%" %buffer% -vt "%verif%" -tfile "%prog_dir%list.txt" -v "")
if "%vrepack%" EQU "verify" ( goto end_xci_manual )

if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1

move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
if exist "%w_folder%\*.zip" ( MD "%zip_fold%" ) >NUL 2>&1
move "%w_folder%\*.zip" "%zip_fold%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\%filename%.nsp" )

RD /S /Q "%w_folder%" >NUL 2>&1
echo 完成
call :thumbup
call :delay
goto end_xci_manual

:xci_manual_fat32
CD /d "%prog_dir%"
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
echo 完成
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
echo 完成
call :thumbup
call :delay
goto end_xci_manual

:end_xci_manual
exit /B

:contador_NF
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (list.txt) do (
set /a conta=!conta! + 1
)
echo ...................................................
echo 仍有 !conta! 个文件要处理
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B

::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
:: MULTI-MODE
::///////////////////////////////////////////////////
::///////////////////////////////////////////////////

:multimode
if exist %w_folder% RD /S /Q "%w_folder%" >NUL 2>&1
if exist "%list_folder%\a_multi" RD /S /Q "%list_folder%\a_multi" >NUL 2>&1
cls
call :program_logo
echo -----------------------------------------------
echo 多文件处理已激活
echo -----------------------------------------------
if exist "mlist.txt" del "mlist.txt"
:multi_manual_INIT
endlocal
set skip_list_split="false"
set "mlistfol=%list_folder%\m_multi"
echo 拖放文件或文件夹以创建列表
echo 注意：记得在拖放文件或文件夹后按回车键
echo.
ECHO ***********************************************
echo 输入"1"，处理以前保存的作业
echo 输入"2"，将另一个文件夹添加到列表中
echo 输入"3"，将另一个文件添加到列表中
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%mlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto manual_Reentry
if /i "%eval%"=="1" set skip_list_split="true"
if /i "%eval%"=="1" goto multi_start_cleaning
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mlist.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mlist.txt" mode=file ext="nsp xci nsz xcz" False False True ) 2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%mlist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%mlist.txt" "extlist=nsp xci nsz xcz" )

goto multi_checkagain
echo.
:multi_checkagain
set "mlistfol=%list_folder%\a_multi"
echo 你想做什么？
echo ......................................................................
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理当前列表
echo 输入"2"，添加到保存的列表并处理它们
echo 输入"3"，保存列表以后处理
echo 输入"4"，添加另一个文件夹到列表
echo 输入"5"，添加另一个文件到列表
echo 输入"6"，通过本地文件库，将文件添加到列表
echo 输入"7"，通过folder-walker递归的方式，将文件添加到列表
echo.
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%mlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" goto manual_Reentry
if /i "%eval%"=="1" set "mlistfol=%list_folder%\a_multi"
if /i "%eval%"=="1" goto multi_start_cleaning
if /i "%eval%"=="2" set "mlistfol=%list_folder%\m_multi"
if /i "%eval%"=="2" goto multi_start_cleaning
if /i "%eval%"=="3" set "mlistfol=%list_folder%\m_multi"
if /i "%eval%"=="3" goto multi_saved_for_later
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mlist.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mlist.txt" mode=file ext="nsp xci nsz xcz" False False True ) 2>&1>NUL
if /i "%eval%"=="6" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%mlist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="7" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%mlist.txt" "extlist=nsp xci nsz xcz" )
REM if /i "%eval%"=="2" goto multi_set_clogo
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto multi_showlist
if /i "%eval%"=="r" goto multi_r_files
if /i "%eval%"=="z" del mlist.txt

goto multi_checkagain

:multi_saved_for_later
if not exist "%list_folder%" MD "%list_folder%" >NUL 2>&1
if not exist "%mlistfol%" MD "%mlistfol%" >NUL 2>&1
echo 保存列表
echo ......................................................................
echo 输入"1"，以将列表合并保存（单个多文件列表）
echo 输入"2"，按文件的baseid保存为多个列表
echo.
ECHO *******************************************
echo 输入"b"，继续构建列表
echo 输入"0"，返回选择菜单
ECHO *******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto multi_saved_for_later1
if /i "%bs%"=="2" ( %pycommand% "%squirrel%" -splid "%mlistfol%" -tfile "%prog_dir%mlist.txt" )
if /i "%bs%"=="2" del "%prog_dir%mlist.txt"
if /i "%bs%"=="2" goto multi_saved_for_later2
echo 错误的选择!!
goto multi_saved_for_later
:multi_saved_for_later1
echo.
echo 选择名称
echo ......................................................................
echo 列表将保存在您选择的列表目录名称( 路径是 "程序目录\list\m_multi")
echo.
set /p lname="请为列表命名: "
set lname=%lname:"=%
move /y "%prog_dir%mlist.txt" "%mlistfol%\%lname%.txt" >nul
echo.
echo JOB SAVED!!!
:multi_saved_for_later2
echo.
echo 输入"0"，返回模式选择菜单
echo 输入"1"，以创建其他列表
echo 输入"2"，退出程序
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" echo.
if /i "%bs%"=="1" echo CREATE ANOTHER JOB
if /i "%bs%"=="1" goto multi_manual_INIT
if /i "%bs%"=="1" goto salida
goto multi_saved_for_later2

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
echo 您已添加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto multi_checkagain

:m_cl_wrongchoice
echo 错误的选择
echo ............
:multi_start_cleaning
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 标准加密选项:
echo 输入"1"，重新打包列表为无票据的NSP
echo 输入"2"，重新打包列表为XCI
echo 输入"3"，重新打包列表为无票据的NSP和XCI
echo.
echo 特殊选项：
echo 输入"4"，重新打包列表为NSP(未修改NCA)
echo 输入"5"，重新打包列表为NSP和XCI（未修改NCA）
echo.
ECHO *****************************************
echo 或输入"b"，返回选项列表
ECHO *****************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="1" set "vrepack=cnsp"
if /i "%bs%"=="2" set "vrepack=xci"
if /i "%bs%"=="3" set "vrepack=cboth"

if /i "%bs%"=="4" set "vrepack=nsp"
if /i "%bs%"=="4" set "skipRSVprompt=true"
if /i "%bs%"=="5" set "vrepack=both"

if %vrepack%=="none" goto m_cl_wrongchoice
:m_RSV_wrongchoice
if /i "%skipRSVprompt%"=="true" set "patchRSV=-pv false"
if /i "%skipRSVprompt%"=="true" set "vkey=-kp false"
if /i "%skipRSVprompt%"=="true" goto m_KeyChange_skip
echo *******************************************************
echo 是否要魔改所需的系统版本
echo *******************************************************
echo 如果您选择打补丁，它将被设置为匹配的nca加密
echo 因此仅在必要时才要求更新系统
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
if /i "%bs%"=="0" set "vkey=-kp false"
if /i "%bs%"=="1" set "patchRSV=-pv true"
if /i "%patchRSV%"=="none" echo 错误的选择
if /i "%patchRSV%"=="none" goto m_RSV_wrongchoice
if /i "%bs%"=="0" goto m_KeyChange_skip

:m_KeyChange_wrongchoice
echo *******************************************************
echo 魔改程序已激活
echo *******************************************************
echo 这并不总能降低系统要求。
echo.
echo 输入"f"，不魔改
echo 输入"0"，魔改版本FW 1.0
echo 输入"1"，魔改版本FW 2.0-2.3
echo 输入"2"，魔改版本FW 3.0
echo 输入"3"，魔改版本FW 3.0.1-3.02
echo 输入"4"，魔改版本FW 4.0.0-4.1.0
echo 输入"5"，魔改版本FW 5.0.0-5.1.0
echo 输入"6"，魔改版本FW 6.0.0-6.1.0
echo 输入"7"，魔改版本FW 6.2.0
echo 输入"8"，魔改版本FW 7.0.0-8.0.1)
echo 输入"9"，魔改版本FW 8.1.0)
echo 输入"10"，魔改版本FW 9.0.0-9.0.1)
echo 输入"11"，魔改版本FW 9.1.0-10.2.0)
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
if /i "%vkey%"=="none" echo 错误的选择
if /i "%vkey%"=="none" goto m_KeyChange_wrongchoice

:m_KeyChange_skip
if not exist "%list_folder%" MD "%list_folder%" >NUL 2>&1
if not exist "%mlistfol%" MD "%mlistfol%" >NUL 2>&1
if %skip_list_split% EQU "true" goto m_process_jobs
echo *******************************************************
echo 您想如何处理这些文件？
echo *******************************************************
echo 通过基本ID分离的模式能够识别与每个游戏相对应的内容，
echo 并从同一列表文件创建多XCI或多nsp文件
echo.
echo 输入"1"，将所有文件合并为一个文件
echo 输入"2"，通过baseid分离成多文件
echo.
ECHO *****************************************
echo 或输入"b"，返回选项列表
ECHO *****************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="1" move /y "%prog_dir%mlist.txt" "%mlistfol%\mlist.txt" >nul
if /i "%bs%"=="1" goto m_process_jobs
if /i "%bs%"=="2" goto m_split_merge
goto m_KeyChange_skip

:m_split_merge
if "%fatype%" EQU "-fat fat32" echo Fat32 selected, removing nsz and xcz from input list
if "%fatype%" EQU "-fat fat32" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%mlist.txt","ext=nsp nsx xci","token=False",Print="False" )
cls
call :program_logo
%pycommand% "%squirrel%" -splid "%mlistfol%" -tfile "%prog_dir%mlist.txt"
goto m_process_jobs2
:m_process_jobs
if "%fatype%" EQU "-fat fat32" echo Fat32 selected, removing nsz and xcz from input list
if "%fatype%" EQU "-fat fat32" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%mlist.txt","ext=nsp nsx xci","token=False",Print="False" )
cls
:m_process_jobs2
dir "%mlistfol%\*.txt" /b  > "%prog_dir%mlist.txt"
rem if "%fatype%" EQU "-fat fat32" goto m_process_jobs_fat32
for /f "tokens=*" %%f in (mlist.txt) do (
set "listname=%%f"
if "%vrepack%" EQU "cnsp" call :program_logo
if "%vrepack%" EQU "cnsp" call :m_split_merge_list_name
if "%vrepack%" EQU "cnsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t cnsp -o "%w_folder%" -tfile "%mlistfol%\%%f" -roma %romaji% -dmul "calculate" )

if "%vrepack%" EQU "xci" call :program_logo
if "%vrepack%" EQU "xci" call :m_split_merge_list_name
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t xci -o "%w_folder%" -tfile "%mlistfol%\%%f" -roma %romaji% -dmul "calculate" )

if "%vrepack%" EQU "nsp" call :program_logo
if "%vrepack%" EQU "nsp" call :m_split_merge_list_name
if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t nsp -o "%w_folder%" -tfile "%mlistfol%\%%f" -roma %romaji% -dmul "calculate" )

if "%vrepack%" EQU "cboth" call :program_logo
if "%vrepack%" EQU "cboth" call :m_split_merge_list_name
if "%vrepack%" EQU "cboth" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t xci -o "%w_folder%" -tfile "%mlistfol%\%%f" -roma %romaji% -dmul "calculate" )
if "%vrepack%" EQU "cboth" call :program_logo
if "%vrepack%" EQU "cboth" call :m_split_merge_list_name
if "%vrepack%" EQU "cboth" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t cnsp -o "%w_folder%" -tfile "%mlistfol%\%%f" -roma %romaji% -dmul "calculate" )

if "%vrepack%" EQU "both" call :program_logo
if "%vrepack%" EQU "both" call :m_split_merge_list_name
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t nsp -o "%w_folder%" -tfile "%mlistfol%\%%f" -roma %romaji% -dmul "calculate" )
if "%vrepack%" EQU "both" call :program_logo
if "%vrepack%" EQU "both" call :m_split_merge_list_name
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t xci -o "%w_folder%" -tfile "%mlistfol%\%%f" -roma %romaji% -dmul "calculate" )
%pycommand% "%squirrel%" --strip_lines "%prog_dir%mlist.txt" "1" "true"
if exist "%mlistfol%\%%f" del "%mlistfol%\%%f"
rem call :multi_contador_NF
)

setlocal enabledelayedexpansion
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
set "gefolder=%fold_output%"
move "%w_folder%\*.xci" "%gefolder%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.nsp" "%gefolder%" >NUL 2>&1
move "%w_folder%\*.ns*" "%gefolder%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -tfile "%w_folder%\filename.txt" -ifo "%w_folder%\archfolder" -archive "%gefolder%" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
if exist "%mlistfol%" RD /S /Q "%mlistfol%" >NUL 2>&1
if exist mlist.txt del mlist.txt
goto m_exit_choice

:m_process_jobs_fat32
CD /d "%prog_dir%"
set "finalname=tempname"
cls
call :program_logo
for /f "tokens=*" %%f in (mlist.txt) do (
set "listname=%%f"
set "list=%mlistfol%\%%f"
call :m_split_merge_list_name
call :m_process_jobs_fat32_2
%pycommand% "%squirrel%" --strip_lines "%prog_dir%mlist.txt" "1" "true"
if exist "%mlistfol%\%%f" del "%mlistfol%\%%f"
rem call :multi_contador_NF
)
goto m_exit_choice
:m_process_jobs_fat32_2
if not exist "%w_folder%" MD "%w_folder%" >NUL 2>&1
copy "%list%" "%w_folder%\list.txt" >NUL 2>&1
for /f "usebackq tokens=*" %%f in ("%w_folder%\list.txt") do (
echo %%f
set "name=%%~nf"
set "filename=tempname"
set "orinput=%%f"
if "%%~nxf"=="%%~nf.nsp" call :multi_nsp_manual
if "%%~nxf"=="%%~nf.xci" call :multi_xci_manual
)
if exist "%w_folder%\list.txt" del "%w_folder%\list.txt"
if "%vrepack%" EQU "cnsp" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "nsp" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "xci" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "cboth" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "cboth" ( call "%xci_lib%" "repack" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%nsp_lib%" "convert" "%w_folder%" )
if "%vrepack%" EQU "both" ( call "%xci_lib%" "repack" "%w_folder%" )
RD /S /Q "%w_folder%\secure" >NUL 2>&1
RD /S /Q "%w_folder%\normal" >NUL 2>&1
if exist "%w_folder%\archfolder" goto m_process_jobs_fat32_3
if exist "%w_folder%\*.xc*" goto m_process_jobs_fat32_4
if exist "%w_folder%\*.ns*" goto m_process_jobs_fat32_4
if exist "%w_folder%\tempname.*" goto m_process_jobs_fat32_4
:m_process_jobs_fat32_3
setlocal enabledelayedexpansion
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -ifo "%w_folder%\archfolder" -archive "%fold_output%\tempname.nsp" )
endlocal
dir "%fold_output%\tempname.*" /b  > "%w_folder%\templist.txt"
for /f "usebackq tokens=*" %%f in ("%w_folder%\templist.txt") do (
%pycommand% "%squirrel%" -roma %romaji% --renameftxt "%fold_output%\%%f" -tfile "%list%"
if exist "%w_folder%\templist.txt" del "%w_folder%\templist.txt"
)

if exist "%w_folder%\*.xc*" goto m_process_jobs_fat32_4
if exist "%w_folder%\*.ns*" goto m_process_jobs_fat32_4
RD /S /Q "%w_folder%" >NUL 2>&1
exit /B

:m_process_jobs_fat32_4
dir "%w_folder%\tempname.*" /b  > "%w_folder%\templist.txt"
for /f "usebackq tokens=*" %%f in ("%w_folder%\templist.txt") do (
%pycommand% "%squirrel%" -roma %romaji% --renameftxt "%w_folder%\%%f" -tfile "%list%"
)
setlocal enabledelayedexpansion
if not exist "%fold_output%" MD "%fold_output%" >NUL 2>&1
move "%w_folder%\*.xci" "%fold_output%" >NUL 2>&1
move  "%w_folder%\*.xc*" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.nsp" "%fold_output%" >NUL 2>&1
move "%w_folder%\*.ns*" "%fold_output%" >NUL 2>&1
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
exit /B

:m_split_merge_list_name
echo *******************************************************
echo 正在处理列表 %listname%
echo *******************************************************
exit /B

:m_normal_merge
rem if "%fatype%" EQU "-fat fat32" goto m_KeyChange_skip_fat32
REM 对于当前的beta版，文件名是计算出来的。此代码将保留评论，以便将来重新集成
rem echo *******************************************************
rem echo 输入输出文件的最终文件名
rem echo *******************************************************
rem echo.
rem echo 或输入"b"，返回选项列表
rem echo.
rem set /p bs="请键入不带扩展名的名称： "
rem set finalname=%bs:"=%
rem if /i "%finalname%"=="b" goto multi_checkagain

cls
if "%vrepack%" EQU "cnsp" call :program_logo
if "%vrepack%" EQU "cnsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t cnsp -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )

if "%vrepack%" EQU "xci" call :program_logo
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t xci -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )

if "%vrepack%" EQU "nsp" call :program_logo
if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t nsp -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )

if "%vrepack%" EQU "cboth" call :program_logo
if "%vrepack%" EQU "cboth" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t xci -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )
if "%vrepack%" EQU "cboth" call :program_logo
if "%vrepack%" EQU "cboth" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t cnsp -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )

if "%vrepack%" EQU "both" call :program_logo
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t nsp -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )
if "%vrepack%" EQU "both" call :program_logo
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% %patchRSV% %vkey% %capRSV% %fatype% %fexport% %skdelta% -t xci -o "%w_folder%" -tfile "%prog_dir%mlist.txt" -roma %romaji% -dmul "calculate" )

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
if exist "%w_folder%\archfolder" ( %pycommand% "%squirrel%" -tfile "%w_folder%\filename.txt" -ifo "%w_folder%\archfolder" -archive "%gefolder%" )
endlocal
RD /S /Q "%w_folder%" >NUL 2>&1
goto m_exit_choice

:m_KeyChange_skip_fat32
CD /d "%prog_dir%"
echo *******************************************************
echo 输入输出文件的最终文件名
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
%pycommand% "%squirrel%" --strip_lines "%prog_dir%mlist.txt" "1" "true"
rem call :multi_contador_NF
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
goto m_exit_choice

:m_exit_choice
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
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
echo 完成
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
echo 仍有 !conta! 个要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B

REM the logo function has been disabled temporarly for the current beta, the code remains here
REM unaccessed for future modification and reintegration
:multi_set_clogo
cls
call :program_logo
echo ------------------------------------------
echo 自定义图标
echo ------------------------------------------
echo 适用于多游戏XCI。
echo 当前设置了自定义图标和名称，拖动一个NSP或control nca
echo 这种方式下，程序将在正常分区中复制control nca
echo 如果您不添加自定义图标，则将从您的一款游戏中设置图标
echo ..........................................
echo 输入"b"，返回列表生成器
echo ..........................................
set /p bs="将NSP或NCA文件拖到窗口上，然后按回车键： "
set bs=%bs:"=%
if /i "%bs%"=="b" ( goto multi_checkagain )
if exist "%bs%" ( goto multi_checklogo )
goto multi_set_clogo

:multi_checklogo
if exist "%~dp0logo.txt" del "%~dp0logo.txt" >NUL 2>&1
echo %bs%>"%~dp0hlogo.txt"
FINDSTR /L ".nsp" "%~dp0hlogo.txt" >"%~dp0logo.txt"
FINDSTR /L ".nca" "%~dp0hlogo.txt" >>"%~dp0logo.txt"
set /p custlogo=<"%~dp0logo.txt"
del "%~dp0hlogo.txt"
::echo %custlogo%
for /f "usebackq tokens=*" %%f in ( "%~dp0logo.txt" ) do (
set "logoname=%%~nxf"
if "%%~nxf"=="%%~nf.nsp" goto ext_log
if "%%~nxf"=="%%~nf.nca" goto check_log
)

:ext_log
del "%~dp0logo.txt"
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
del "%~dp0logo.txt"
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
echo 注意：通过输入3，您将在开始处理文件之前看到前一个列表，
echo 并且可以从列表中添加和删除项目
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
echo 错误的选择
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
echo 输入"1"，将文件夹添加到列表中
echo 输入"2"，将文件添加到列表中
echo 输入"3"，通过本地文件库，将文件添加到列表
echo 输入"4"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%splist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" goto manual_Reentry
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%splist.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%splist.txt" mode=file ext="nsp xci nsz xcz" False False True )  2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%splist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%splist.txt" "extlist=nsp xci nsz xcz" )

echo.
:sp_checkagain
echo 你想做什么？
echo ......................................................................
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"2"，将另一个文件夹添加到列表
echo 输入"3"，将另一个文件添加到列表
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%splist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" goto manual_Reentry
if /i "%eval%"=="1" goto sp_start_cleaning
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%splist.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%splist.txt" mode=file ext="nsp xci nsz xcz" False False True )  2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%splist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%splist.txt" "extlist=nsp xci nsz xcz" )

if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto sp_showlist
if /i "%eval%"=="r" goto sp_r_files
if /i "%eval%"=="z" del splist.txt

goto sp_checkagain

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
echo 您已添加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto sp_checkagain

:sp_cl_wrongchoice
echo 错误的选择
echo ............
:sp_start_cleaning
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为XCI
echo 输入"3"，重新打包为NSP和XCI
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
if "%fatype%" EQU "-fat fat32" echo Fat32 selected, removing nsz and xcz from input list
if "%fatype%" EQU "-fat fat32" ( %pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%splist.txt","ext=nsp nsx xci","token=False",Print="False" )
cls
call :program_logo
for /f "tokens=*" %%f in (splist.txt) do (
set "name=%%~nf"
set "filename=%%~nxf"
set "end_folder=%%~nf"
set "orinput=%%f"
if "%%~nxf"=="%%~nf.nsp" call :split_content
if "%%~nxf"=="%%~nf.NSP" call :split_content
if "%%~nxf"=="%%~nf.nsz" call :split_content
if "%%~nxf"=="%%~nf.NSZ" call :split_content
if "%%~nxf"=="%%~nf.xci" call :split_content
if "%%~nxf"=="%%~nf.XCI" call :split_content
if "%%~nxf"=="%%~nf.xcz" call :split_content
if "%%~nxf"=="%%~nf.XCZ" call :split_content
%pycommand% "%squirrel%" --strip_lines "%prog_dir%splist.txt" "1" "true"
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
rem call :sp_contador_NF
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
rem if "%fatype%" EQU "-fat fat32" goto split_content_fat32
set "showname=%orinput%"
set "sp_repack=%vrepack%"
if exist "%w_folder%" RD /S /Q  "%w_folder%" >NUL 2>&1
MD "%w_folder%" >NUL 2>&1
call :processing_message
call :squirrell
if "%vrepack%" EQU "nsp" ( %pycommand% "%squirrel%" %buffer% -o "%w_folder%" %fatype% %fexport% -t "nsp" -dspl "%orinput%" -tfile "%prog_dir%splist.txt")
if "%vrepack%" EQU "xci" ( %pycommand% "%squirrel%" %buffer% -o "%w_folder%" %fatype% %fexport% -t "xci" -dspl "%orinput%" -tfile "%prog_dir%splist.txt")
if "%vrepack%" EQU "both" ( %pycommand% "%squirrel%" %buffer% -o "%w_folder%" %fatype% %fexport% -t "both" -dspl "%orinput%" -tfile "%prog_dir%splist.txt")

call :thumbup
call :delay
exit /B

:split_content_fat32
CD /d "%prog_dir%"
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
%pycommand% "%squirrel%" --strip_lines "%prog_dir%dirlist.txt" "1" "true"
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
echo 仍有 !conta! 个要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B

::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
:: 数据库模式
::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
:DBMODE
cls
call :program_logo
echo -----------------------------------------------
echo 数据库生成模式已激活
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
echo 注意：通过输入3，您将在开始处理文件之前看到前一个列表，
echo 并且可以从列表中添加和删除项目
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
echo 错误的选择
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
echo 输入"0"返回模式选择菜单
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
%pycommand% "%squirrel%" -t nsp xci nsx nsz xcz -tfile "%prog_dir%DBL.txt" -ff "%targt%"
goto DBcheckagain
:DBcheckfile
%pycommand% "%squirrel%" -t nsp xci nsx nsz xcz -tfile "%prog_dir%DBL.txt" -ff "%targt%"
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
echo 您已添加了 !conta! 个要处理的文件
echo .................................................
endlocal

goto DBcheckagain

:DBs_cl_wrongchoice
echo 错误的选择
echo ............
:DBstart_cleaning
echo *******************************************************
echo 接下来选择您要执行的操作
echo *******************************************************
echo 输入"1"，NUTDB数据库生成
echo 输入"2"，扩展数据库生成
echo 输入"3"，生成无钥数据库（扩展）
echo 输入"4"，生成简单数据库
echo 输入"5"，生成以上4个数据库
echo 输入"Z"，生成ZIP文件
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
if /i "%bs%"=="4" set "dbformat=simple"
if /i "%bs%"=="4" goto DBs_GENDB
if /i "%bs%"=="5" set "dbformat=all"
if /i "%bs%"=="5" goto DBs_GENDB
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
if "%%~nxf"=="%%~nf.nsz" call :DBnsp_manual
if "%%~nxf"=="%%~nf.NSP" call :DBnsp_manual
if "%%~nxf"=="%%~nf.NSX" call :DBnsp_manual
if "%%~nxf"=="%%~nf.NSZ" call :DBnsp_manual
if "%%~nxf"=="%%~nf.xci" call :DBnsp_manual
if "%%~nxf"=="%%~nf.XCI" call :DBnsp_manual
if "%%~nxf"=="%%~nf.xcz" call :DBnsp_manual
if "%%~nxf"=="%%~nf.XCZ" call :DBnsp_manual
%pycommand% "%squirrel%" --strip_lines "%prog_dir%DBL.txt" "1" "true"
rem call :DBcontador_NF
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
set "db_file=%prog_dir%INFO\%dbformat%_DB.txt"
set "dbdir=%prog_dir%INFO\"
if exist "%dbdir%temp" ( RD /S /Q "%dbdir%temp" ) >NUL 2>&1
rem echo %dbdir%temp

for /f "tokens=*" %%f in (DBL.txt) do (
set "orinput=%%f"
if exist "%dbdir%temp" ( RD /S /Q "%dbdir%temp" ) >NUL 2>&1
call :DBGeneration
if "%workers%" EQU "-threads 1" ( %pycommand% "%squirrel%" --strip_lines "%prog_dir%DBL.txt" "1" "true")
if "%workers%" NEQ "-threads 1" ( call :DBcheck )
rem if "%workers%" NEQ "-threads 1" ( call :DBcontador_NF )
)
:DBs_fin
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
if exist "%dbdir%temp" ( RD /S /Q "%dbdir%temp" ) >NUL 2>&1
goto DBs_exit_choice

:DBGeneration
if not exist "%dbdir%" MD "%dbdir%">NUL 2>&1
%pycommand% "%squirrel%" --dbformat "%dbformat%" -dbfile "%db_file%" -tfile "%prog_dir%DBL.txt" -nscdb "%orinput%" %workers%
exit /B

:DBcheck
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (DBL.txt) do (
set /a conta=!conta! + 1
)
if !conta! LEQ 0 ( del DBL.txt )
endlocal
if not exist "DBL.txt" goto DBs_fin
exit /B

:DBcontador_NF
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (DBL.txt) do (
set /a conta=!conta! + 1
)
echo ...................................................
echo 仍有 !conta! 个要处理的文件
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
::NSCB_options.cmd配置脚本
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
ECHO                                  VERSION 1.01 (NEW)
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
echo 正在为 %ziptarget% 创建zip压缩文件
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
echo 正在处理 %showname%
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

:missing_things
call :program_logo
echo ....................................
echo 您缺少以下内容                     :
echo ....................................
echo.
if not exist "%op_file%" echo - The config file is not correctly pointed or is missing.
if not exist "%squirrel%" echo - "squirrel.py" is not correctly pointed or is missing.
if not exist "%xci_lib%" echo - "XCI.bat" is not correctly pointed or is missing.
if not exist "%nsp_lib%" echo - "NSP.bat" is not correctly pointed or is missing.
if not exist "%zip%" echo - "7za.exe" is not correctly pointed or is missing.

if not exist "%hacbuild%" echo - "hacbuild.exe" is not correctly pointed or is missing.
if not exist "%listmanager%" echo - "listmanager.py" is not correctly pointed or is missing.
if not exist "%batconfig%" echo - "NSCB_config.bat" is not correctly pointed or is missing.
if not exist "%infobat%" echo - "info.bat" is not correctly pointed or is missing.
::文件完整路径
if not exist "%dec_keys%" echo - "keys.txt"文件指向不正确或者缺失。
echo.
pause
echo 程序即将退出
PING -n 2 127.0.0.1 >NUL 2>&1
goto salida
:salida
::暂停
exit
