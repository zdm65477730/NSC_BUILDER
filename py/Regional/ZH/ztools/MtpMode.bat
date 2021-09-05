@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.01-b -- Profile: %ofile_name% -- by JulesOnTheRoad

:MAIN
cls
call :program_logo
ECHO .............................................................
echo 输入"1"，进入游戏安装模式
echo 输入"2"，进入文件传输模式
echo 输入"3"，从库自动更新设备模式
echo 输入"4"，DUMP或卸载游戏
echo 输入"5"，进入备份存档模式
echo 输入"6"，进入设备信息模式
echo 输入"7"，进入通用SX AUTOLOADER文件模式
echo 输入"0"，进入配置模式
echo.
echo 输入"N"，进入标准模式
echo 输入"D"，进入谷歌网盘模式
echo 输入"L"，进入传统模式
echo .............................................................
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="1" goto G_INST
if /i "%bs%"=="2" goto F_TR
if /i "%bs%"=="3" goto AUTOUPDATE
if /i "%bs%"=="4" goto INSTALLED
if /i "%bs%"=="5" goto SAVES
if /i "%bs%"=="6" goto DEV_INF
if /i "%bs%"=="7" goto SX_AUTOLOADER
if /i "%bs%"=="N" goto call_main
if /i "%bs%"=="L" goto LegacyMode
if /i "%bs%"=="D" goto GDMode
if /i "%bs%"=="0" goto OPT_CONFIG
goto MAIN

:LegacyMode
call "%prog_dir%ztools\LEGACY.bat"
exit /B

:GDMode
call "%prog_dir%ztools\DriveMode.bat"
exit /B

:G_INST
cls
call :program_logo
echo -------------------------------------------------
echo MTP - 文件传输模式已激活
echo -------------------------------------------------
echo *******************************************************
echo 选择功能
echo *******************************************************
echo.
echo 1. 从本地文件安装游戏
echo 2. 从远程库（GDRIVE）安装游戏
echo.
ECHO ******************************************
echo 或者输入"0"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto G_INST_LOCAL
if /i "%bs%"=="2" goto G_INST_GDRIVE
goto G_INST

:G_INST_GDRIVE
call "%prog_dir%ztools\MtpInstallRemote.bat"
goto MAIN

:G_INST_LOCAL
cls
call :program_logo
echo -------------------------------------------------
echo MTP - 安装模式已激活
echo -------------------------------------------------
if exist "MTP1.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (MTP1.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (MTP1.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del MTP1.txt )
endlocal
if not exist "MTP1.txt" goto manual_INIT
ECHO .......................................................
ECHO 找到一个上一个列表。你想要做什么？
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
if /i "%bs%"=="1" goto start_1install
if /i "%bs%"=="0" goto MAIN
echo.
echo 错误的选择
goto prevlist0
:delist
del MTP1.txt
cls
call :program_logo
echo -------------------------------------------------
echo MTP - 安装模式已激活
echo -------------------------------------------------
echo ..................................
echo 您决定开始新的列表
echo ..................................

:manual_INIT
endlocal
echo “拖动其他文件或文件夹，然后按回车将项目添加到列表中”
echo.
ECHO ***********************************************
echo 输入"1"，通过选择器将文件夹添加到列表
echo 输入"2"，通过选择器将文件添加到列表
echo 输入"3"，通过本地文件库，将文件添加到列表
echo 输入"4"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"0"，返回到模式选择菜单
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp nsz xci xcz -tfile "%prog_dir%MTP1.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%MTP1.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%MTP1.txt" mode=file ext="nsp xci nsz xcz" False False True )  2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller select_from_local_libraries -xarg "%prog_dir%MTP1.txt" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%MTP1.txt" "extlist=nsp xci nsz xcz" )

goto checkagain
echo.
:checkagain
echo 你想要做什么？
echo ......................................................................
echo ”拖动其他文件或文件夹，然后按回车将项目添加到列表中“
echo.
echo 输入"1"，开始处理
echo 输入"2"，通过选择器添加另一个文件夹到列表
echo 输入"3"，通过选择器添加另一个文件到列表
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"e"，退出
echo 输入"i"，以查看要处理的文件列表
echo 输入"r"，删除一些文件（从下往上数）
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或者输入"0"，返回到模式选择菜单
ECHO *************************************************
echo.
%pycommand% "%squirrel%" -t nsp nsz xci xcz -tfile "%prog_dir%MTP1.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" goto start_1install
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%MTP1.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%MTP1.txt" mode=file ext="nsp xci nsz xcz" False False True )  2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller select_from_local_libraries -xarg "%prog_dir%MTP1.txt" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%MTP1.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del MTP1.txt

goto checkagain

:r_files
set /p bs="输入您要删除的文件数（从底部开始）："
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (MTP1.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<MTP1.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>MTP1.txt.new
endlocal
move /y "MTP1.txt.new" "MTP1.txt" >nul
endlocal

:showlist
cls
call :program_logo
echo -------------------------------------------------
echo MTP - 安装模式已激活
echo -------------------------------------------------
ECHO 要处理的文件：
for /f "tokens=*" %%f in (MTP1.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (MTP1.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 您已添加 !conta! 个要处理的文件
echo .................................................
endlocal

goto checkagain

:s_mtp1_wrongchoice
echo 错误的选择
echo ............
:start_1install
echo *******************************************************
echo 选择怎么处理这些文件
echo *******************************************************
echo 输入"1"，安装游戏
echo.
ECHO ******************************************
echo 或者输入"b"，以返回到列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" goto select_medium
if %choice%=="none" goto s_mtp1_wrongchoice

:select_medium_wrongchoice
echo 错误的选项
echo ............
:select_medium
echo *******************************************************
echo 安装介质
echo *******************************************************
echo.
echo 1. SD
echo 2. EMMC
echo.
ECHO ******************************************
echo 或者输入“b”，以返回到列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
set medium=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" set "medium=SD"
if /i "%bs%"=="2" set "medium=EMMC"

if %medium%=="none" goto select_medium_wrongchoice

:start_installing
cls
call :program_logo
CD /d "%prog_dir%"

%pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%MTP1.txt","ext=nsp xci nsz","token=False",Print="False"
%pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller loop_install -xarg "%prog_dir%MTP1.txt" "destiny=%medium%" "verification=%MTP_verification%" "%w_folder%" "ch_medium=%MTP_aut_ch_medium%" "check_fw=%MTP_chk_fw%" "patch_keygen=%MTP_prepatch_kg%" "ch_base=%MTP_prechk_Base%" "ch_other=%MTP_prechk_Upd%" "install_mode=%MTP_ptch_inst_spec%" "st_crypto=%MTP_stc_installs%"

ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理! *************
ECHO ---------------------------------------------------
goto s_exit_choice

:F_TR
cls
call :program_logo
echo -------------------------------------------------
echo MTP - 文件传输模式已激活
echo -------------------------------------------------
echo *******************************************************
echo 选择功能
echo *******************************************************
echo.
echo 1. 从本地文件传输
echo 2. 从远程库（GDRIVE）传输
echo 3. 创建XCI和传输
echo 4. 创建多重XCI和传输
echo.
ECHO ******************************************
echo 或者输入"0"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto F_TR_LOCAL
if /i "%bs%"=="2" goto F_TR_GD
if /i "%bs%"=="3" goto F_TR_C_xci_Transfer
if /i "%bs%"=="4" goto F_TR_C_mxci_Transfer
goto F_TR

:F_TR_LOCAL
call "%prog_dir%ztools\MtpFTLocal.bat"
goto MAIN
:F_TR_GD
call "%prog_dir%ztools\MtpTransferRemote.bat"
goto MAIN
:F_TR_C_xci_Transfer
call "%prog_dir%ztools\MtpCxciFTLocal.bat"
goto MAIN
:F_TR_C_mxci_Transfer
call "%prog_dir%ztools\MtpCmxciFTLocal.bat"
goto MAIN

:AUTOUPDATE
cls
call :program_logo
:select_medium_AUTOUPDATE
echo *******************************************************
echo 安装介质
echo *******************************************************
echo.
echo 1. SD
echo 2. EMMC
echo.
ECHO ******************************************
echo 或者输入”0“，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
set medium=none
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" set "medium=SD"
if /i "%bs%"=="2" set "medium=EMMC"

if %medium%=="none" goto select_medium_AUTOUPDATE
:set_auto_AUTOUPDATE
echo *******************************************************
echo 自动启动安装？
echo *******************************************************
echo.
echo 1. 在检测到新内容后开始安装
echo 2. 选择要安装的内容
echo 3. 选择要安装的内容 (使用注册表，包括存档和注册的XCI)
echo.
ECHO ******************************************
echo 输入"0"，返回列表选项
echo 输入"b"，进入上一级菜单
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
set autoupd_aut=none
set "use_archived=False"
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" set "autoupd_aut=True"
if /i "%bs%"=="2" set "autoupd_aut=False"
if /i "%bs%"=="3" set "autoupd_aut=False"
if /i "%bs%"=="3" set "use_archived=True"
if /i "%bs%"=="b" goto select_medium_AUTOUPDATE

if %autoupd_aut%=="none" goto set_auto_AUTOUPDATE

:set_source_AUTOUPDATE
echo *******************************************************
echo 自动更新源
echo *******************************************************
echo.
echo 1. 从本地库自动更新
echo 2. 从远程库自动更新（GOOGLE DRIVE）
echo.
ECHO ******************************************
echo 输入"0"，返回列表选项
echo 输入"b"，进入上一级菜单
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto AUTOUPDATE_LOCAL
if /i "%bs%"=="2" goto AUTOUPDATE_GD
if /i "%bs%"=="b" goto set_auto_AUTOUPDATE

if %autoupd_aut%=="none" goto set_auto_AUTOUPDATE

:AUTOUPDATE_GD
CD /d "%prog_dir%"
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_gdrive update_console_from_gd -xarg "libraries=update" "destiny=%medium%" "exclude_xci=%MTP_exclude_xci_autinst%" "prioritize_nsz=%MTP_prioritize_NSZ%" "%prog_dir%MTP1GD.txt" "verification=%MTP_verification%" "ch_medium=%MTP_aut_ch_medium%" "ch_other=%MTP_prechk_Upd%" "autoupd_aut=%autoupd_aut%" "archived=%use_archived%"
echo.
ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理！*************
ECHO ---------------------------------------------------
goto s_exit_choice

:AUTOUPDATE_LOCAL
CD /d "%prog_dir%"
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller update_console -xarg "libraries=all" "destiny=%medium%" "exclude_xci=%MTP_exclude_xci_autinst%" "prioritize_nsz=%MTP_prioritize_NSZ%" "%prog_dir%MTP1.txt" "verification=%MTP_verification%" "ch_medium=%MTP_aut_ch_medium%" "ch_other=%MTP_prechk_Upd%" "autoupd_aut=%autoupd_aut%" "archived=%use_archived%"

echo.
ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理！*************
ECHO ---------------------------------------------------
goto s_exit_choice

:INSTALLED
cls
call :program_logo
echo.
echo 1. DUMP安装的内容
echo 2. 卸载内容
echo 3. 删除游戏
echo.
ECHO ******************************************
echo 或者输入”0“，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto dump_games
if /i "%bs%"=="2" goto uninstall_games
if /i "%bs%"=="3" goto delete_archived
goto INSTALLED

:dump_games
echo.
ECHO ******************************************
echo 内容转储
ECHO ******************************************
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_game_manager dump_content
echo.
ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理！*************
ECHO ---------------------------------------------------
goto s_exit_choice

:uninstall_games
echo.
ECHO ******************************************
echo 内容卸载
ECHO ******************************************
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_game_manager uninstall_content
echo.
ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理！*************
ECHO ---------------------------------------------------
goto s_exit_choice

:delete_archived
echo.
ECHO ******************************************
echo 删除游戏
ECHO ******************************************
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_game_manager delete_archived
echo.
ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理！*************
ECHO ---------------------------------------------------
goto s_exit_choice

:SAVES_wrongchoice
echo wrong choice
echo ............
:SAVES
cls
call :program_logo
echo.
ECHO ******************************************
echo 存档转储
ECHO ******************************************
echo.
echo 1. DUMP所有存档
echo 2. 选择要DUMP的存档
echo 3. 仅备份当前安装的存档（要求DBI 155或更新的版本）
echo.
ECHO ******************************************
echo 或者输入”0“，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
set backup_all=none
set onlyinstalled=none
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" set "backup_all=True"
if /i "%bs%"=="1" set "onlyinstalled=False"
if /i "%bs%"=="2" set "backup_all=False"
if /i "%bs%"=="2" set "onlyinstalled=False"
if /i "%bs%"=="3" set "backup_all=True"
if /i "%bs%"=="3" set "onlyinstalled=True"
if %backup_all%=="none" goto SAVES_wrongchoice

%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_game_manager back_up_saves -xarg  %backup_all% %MTP_saves_Inline% %MTP_saves_AddTIDandVer% %romaji% "" %onlyinstalled%
echo.
ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理！*************
ECHO ---------------------------------------------------
goto s_exit_choice

:SX_AUTOLOADER
cls
call :program_logo
echo.
ECHO ******************************************
echo SX AUTOLOADER选项
ECHO ******************************************
echo.
echo 1. 为SD卡游戏生成SX自动加载器文件
echo 2. 为HDD硬盘游戏生成SX自动加载器文件
echo 3. 将SX自动加载器文件推送到控制台
echo 4. 检查并清理自动加载器文件（旨在避免SD和HDD之间的冲突）
echo.
ECHO ******************************************
echo 或者输入”0“，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
set backup_all=none
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtp_game_manager gen_sx_autoloader_sd_files )
if /i "%bs%"=="1" goto s_exit_choice
if /i "%bs%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtp_tools gen_sx_autoloader_files_menu )
if /i "%bs%"=="2" goto s_exit_choice
if /i "%bs%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtp_tools push_sx_autoloader_libraries )
if /i "%bs%"=="3" goto s_exit_choice
if /i "%bs%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtp_tools cleanup_sx_autoloader_files )
if /i "%bs%"=="4" goto s_exit_choice
goto SX_AUTOLOADER

:s_exit_choice
if exist MTP1.txt del MTP1.txt
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
goto s_exit_choice

:DEV_INF_wrongchoice
echo 错误的选项
echo ............
:DEV_INF
cls
call :program_logo
ECHO ******************************************
echo 信息
ECHO ******************************************
echo 输入"1"，以显示设备信息
echo 输入"2"，以显示设备上已安装的游戏和xci游戏
echo 输入"3"，以显示适用于游戏的新可用更新或DLC的列表
echo 输入"4"，以显示存档的游戏
echo 输入"5"，以显示存档游戏的新可用更新或DLC列表
echo.
ECHO ******************************************
echo 或者输入”0“，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择："
set bs=%bs:"=%
if /i "%bs%"=="1" goto DEV_INF2
if /i "%bs%"=="2" goto GAMES_INSTALLED_INFO
if /i "%bs%"=="3" goto NC_AVAILABLE_INFO
if /i "%bs%"=="4" goto ARCHIVED_GAMES_INFO
if /i "%bs%"=="5" goto NC_ARCHIVED_GAMES_INFO
if /i "%bs%"=="0" goto MAIN
goto DEV_INF_wrongchoice

:DEV_INF2
cls
call :program_logo
echo.
"%MTP%" ShowInfo
echo.
PAUSE
goto DEV_INF

:GAMES_INSTALLED_INFO
cls
call :program_logo
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller get_installed_info -xarg "" False "exclude_homebrew=True" "exclude_xci=False"
echo.
PAUSE
goto DEV_INF

:NC_AVAILABLE_INFO
cls
call :program_logo
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller get_installed_info -xarg "" True "exclude_homebrew=True" "exclude_xci=False"
echo.
PAUSE
goto DEV_INF

:ARCHIVED_GAMES_INFO
cls
call :program_logo
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller get_archived_info -xarg False "exclude_homebrew=True" "exclude_xci=False"
echo.
PAUSE
goto DEV_INF

:NC_ARCHIVED_GAMES_INFO
cls
call :program_logo
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller get_archived_info -xarg True "exclude_homebrew=True" "exclude_xci=False"
echo.
PAUSE
goto DEV_INF

::///////////////////////////////////////////////////
::NSCB_options.cmd configuration script
::///////////////////////////////////////////////////
:OPT_CONFIG
call "%batconfig%" "%op_file%" "%listmanager%" "%batdepend%"
cls
goto TOP_INIT

:contador_MTP1
setlocal enabledelayedexpansion
set /a conta=0
for /f "tokens=*" %%f in (MTP1.txt) do (
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

:call_main
call "%prog_dir%\NSCB.bat"
exit /B

:salida
::pause
exit
