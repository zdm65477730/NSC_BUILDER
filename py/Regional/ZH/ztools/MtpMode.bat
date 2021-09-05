@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.01-b -- Profile: %ofile_name% -- by JulesOnTheRoad

:MAIN
cls
call :program_logo
ECHO .............................................................
echo ����"1"��������Ϸ��װģʽ
echo ����"2"�������ļ�����ģʽ
echo ����"3"���ӿ��Զ������豸ģʽ
echo ����"4"��DUMP��ж����Ϸ
echo ����"5"�����뱸�ݴ浵ģʽ
echo ����"6"�������豸��Ϣģʽ
echo ����"7"������ͨ��SX AUTOLOADER�ļ�ģʽ
echo ����"0"����������ģʽ
echo.
echo ����"N"�������׼ģʽ
echo ����"D"������ȸ�����ģʽ
echo ����"L"�����봫ͳģʽ
echo .............................................................
echo.
set /p bs="��������ѡ��"
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
echo MTP - �ļ�����ģʽ�Ѽ���
echo -------------------------------------------------
echo *******************************************************
echo ѡ����
echo *******************************************************
echo.
echo 1. �ӱ����ļ���װ��Ϸ
echo 2. ��Զ�̿⣨GDRIVE����װ��Ϸ
echo.
ECHO ******************************************
echo ��������"0"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
echo MTP - ��װģʽ�Ѽ���
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
ECHO �ҵ�һ����һ���б�����Ҫ��ʲô��
:prevlist0
ECHO .......................................................
echo ����"1"���Զ�����һ���б�ʼ����
echo ����"2"����ɾ���б�����һ�����б�
echo ����"3"������������һ���б�
echo .......................................................
echo ע�⣺��3�������ڿ�ʼ�����ļ�֮ǰ������һ���б����ҿ��Դ��б�����Ӻ�ɾ����Ŀ
echo.
ECHO *************************************************
echo ��������"0"�����ص�ģʽѡ��˵�
ECHO *************************************************
echo.
set /p bs="��������ѡ��"
set bs=%bs:"=%
if /i "%bs%"=="3" goto showlist
if /i "%bs%"=="2" goto delist
if /i "%bs%"=="1" goto start_1install
if /i "%bs%"=="0" goto MAIN
echo.
echo �����ѡ��
goto prevlist0
:delist
del MTP1.txt
cls
call :program_logo
echo -------------------------------------------------
echo MTP - ��װģʽ�Ѽ���
echo -------------------------------------------------
echo ..................................
echo ��������ʼ�µ��б�
echo ..................................

:manual_INIT
endlocal
echo ���϶������ļ����ļ��У�Ȼ�󰴻س�����Ŀ��ӵ��б��С�
echo.
ECHO ***********************************************
echo ����"1"��ͨ��ѡ�������ļ�����ӵ��б�
echo ����"2"��ͨ��ѡ�������ļ���ӵ��б�
echo ����"3"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"4"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"0"�����ص�ģʽѡ��˵�
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
echo ����Ҫ��ʲô��
echo ......................................................................
echo ���϶������ļ����ļ��У�Ȼ�󰴻س�����Ŀ��ӵ��б��С�
echo.
echo ����"1"����ʼ����
echo ����"2"��ͨ��ѡ���������һ���ļ��е��б�
echo ����"3"��ͨ��ѡ���������һ���ļ����б�
echo ����"4"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"5"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"e"���˳�
echo ����"i"���Բ鿴Ҫ������ļ��б�
echo ����"r"��ɾ��һЩ�ļ���������������
echo ����"z"��ɾ�������б�
echo ......................................................................
ECHO *************************************************
echo ��������"0"�����ص�ģʽѡ��˵�
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
set /p bs="������Ҫɾ�����ļ������ӵײ���ʼ����"
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
echo MTP - ��װģʽ�Ѽ���
echo -------------------------------------------------
ECHO Ҫ������ļ���
for /f "tokens=*" %%f in (MTP1.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (MTP1.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo ������� !conta! ��Ҫ������ļ�
echo .................................................
endlocal

goto checkagain

:s_mtp1_wrongchoice
echo �����ѡ��
echo ............
:start_1install
echo *******************************************************
echo ѡ����ô������Щ�ļ�
echo *******************************************************
echo ����"1"����װ��Ϸ
echo.
ECHO ******************************************
echo ��������"b"���Է��ص��б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" goto select_medium
if %choice%=="none" goto s_mtp1_wrongchoice

:select_medium_wrongchoice
echo �����ѡ��
echo ............
:select_medium
echo *******************************************************
echo ��װ����
echo *******************************************************
echo.
echo 1. SD
echo 2. EMMC
echo.
ECHO ******************************************
echo �������롰b�����Է��ص��б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
ECHO *********** �����ļ��Ѵ���! *************
ECHO ---------------------------------------------------
goto s_exit_choice

:F_TR
cls
call :program_logo
echo -------------------------------------------------
echo MTP - �ļ�����ģʽ�Ѽ���
echo -------------------------------------------------
echo *******************************************************
echo ѡ����
echo *******************************************************
echo.
echo 1. �ӱ����ļ�����
echo 2. ��Զ�̿⣨GDRIVE������
echo 3. ����XCI�ʹ���
echo 4. ��������XCI�ʹ���
echo.
ECHO ******************************************
echo ��������"0"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
echo ��װ����
echo *******************************************************
echo.
echo 1. SD
echo 2. EMMC
echo.
ECHO ******************************************
echo �������롱0���������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
set bs=%bs:"=%
set medium=none
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" set "medium=SD"
if /i "%bs%"=="2" set "medium=EMMC"

if %medium%=="none" goto select_medium_AUTOUPDATE
:set_auto_AUTOUPDATE
echo *******************************************************
echo �Զ�������װ��
echo *******************************************************
echo.
echo 1. �ڼ�⵽�����ݺ�ʼ��װ
echo 2. ѡ��Ҫ��װ������
echo 3. ѡ��Ҫ��װ������ (ʹ��ע��������浵��ע���XCI)
echo.
ECHO ******************************************
echo ����"0"�������б�ѡ��
echo ����"b"��������һ���˵�
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
echo �Զ�����Դ
echo *******************************************************
echo.
echo 1. �ӱ��ؿ��Զ�����
echo 2. ��Զ�̿��Զ����£�GOOGLE DRIVE��
echo.
ECHO ******************************************
echo ����"0"�������б�ѡ��
echo ����"b"��������һ���˵�
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
ECHO *********** �����ļ��Ѵ���*************
ECHO ---------------------------------------------------
goto s_exit_choice

:AUTOUPDATE_LOCAL
CD /d "%prog_dir%"
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller update_console -xarg "libraries=all" "destiny=%medium%" "exclude_xci=%MTP_exclude_xci_autinst%" "prioritize_nsz=%MTP_prioritize_NSZ%" "%prog_dir%MTP1.txt" "verification=%MTP_verification%" "ch_medium=%MTP_aut_ch_medium%" "ch_other=%MTP_prechk_Upd%" "autoupd_aut=%autoupd_aut%" "archived=%use_archived%"

echo.
ECHO ---------------------------------------------------
ECHO *********** �����ļ��Ѵ���*************
ECHO ---------------------------------------------------
goto s_exit_choice

:INSTALLED
cls
call :program_logo
echo.
echo 1. DUMP��װ������
echo 2. ж������
echo 3. ɾ����Ϸ
echo.
ECHO ******************************************
echo �������롱0���������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto dump_games
if /i "%bs%"=="2" goto uninstall_games
if /i "%bs%"=="3" goto delete_archived
goto INSTALLED

:dump_games
echo.
ECHO ******************************************
echo ����ת��
ECHO ******************************************
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_game_manager dump_content
echo.
ECHO ---------------------------------------------------
ECHO *********** �����ļ��Ѵ���*************
ECHO ---------------------------------------------------
goto s_exit_choice

:uninstall_games
echo.
ECHO ******************************************
echo ����ж��
ECHO ******************************************
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_game_manager uninstall_content
echo.
ECHO ---------------------------------------------------
ECHO *********** �����ļ��Ѵ���*************
ECHO ---------------------------------------------------
goto s_exit_choice

:delete_archived
echo.
ECHO ******************************************
echo ɾ����Ϸ
ECHO ******************************************
echo.
%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_game_manager delete_archived
echo.
ECHO ---------------------------------------------------
ECHO *********** �����ļ��Ѵ���*************
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
echo �浵ת��
ECHO ******************************************
echo.
echo 1. DUMP���д浵
echo 2. ѡ��ҪDUMP�Ĵ浵
echo 3. �����ݵ�ǰ��װ�Ĵ浵��Ҫ��DBI 155����µİ汾��
echo.
ECHO ******************************************
echo �������롱0���������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
ECHO *********** �����ļ��Ѵ���*************
ECHO ---------------------------------------------------
goto s_exit_choice

:SX_AUTOLOADER
cls
call :program_logo
echo.
ECHO ******************************************
echo SX AUTOLOADERѡ��
ECHO ******************************************
echo.
echo 1. ΪSD����Ϸ����SX�Զ��������ļ�
echo 2. ΪHDDӲ����Ϸ����SX�Զ��������ļ�
echo 3. ��SX�Զ��������ļ����͵�����̨
echo 4. ��鲢�����Զ��������ļ���ּ�ڱ���SD��HDD֮��ĳ�ͻ��
echo.
ECHO ******************************************
echo �������롱0���������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
echo ����"0"������ģʽѡ��
echo ����"1"���˳�����
echo.
set /p bs="��������ѡ��"
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto salida
goto s_exit_choice

:DEV_INF_wrongchoice
echo �����ѡ��
echo ............
:DEV_INF
cls
call :program_logo
ECHO ******************************************
echo ��Ϣ
ECHO ******************************************
echo ����"1"������ʾ�豸��Ϣ
echo ����"2"������ʾ�豸���Ѱ�װ����Ϸ��xci��Ϸ
echo ����"3"������ʾ��������Ϸ���¿��ø��»�DLC���б�
echo ����"4"������ʾ�浵����Ϸ
echo ����"5"������ʾ�浵��Ϸ���¿��ø��»�DLC�б�
echo.
ECHO ******************************************
echo �������롱0���������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
echo ���� !conta! ���ļ�Ҫ����
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B

::///////////////////////////////////////////////////
::�ӳ���
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
echo ϣ������ÿ���
exit /B

:call_main
call "%prog_dir%\NSCB.bat"
exit /B

:salida
::pause
exit
