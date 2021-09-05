@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.01-b -- Profile: %ofile_name% -- by JulesOnTheRoad

::///////////////////////////////////////////////////
::///////////////////////////////////////////////////
:: MTP ���ļ�ģʽ
::///////////////////////////////////////////////////
::///////////////////////////////////////////////////

:multimode
if exist %w_folder% RD /S /Q "%w_folder%" >NUL 2>&1
if exist "%list_folder%\a_multi" RD /S /Q "%list_folder%\a_multi" >NUL 2>&1
cls
call :program_logo
echo -----------------------------------------------
echo ������XCI�����䵽MTP
echo -----------------------------------------------
if exist "mlistMTP.txt" del "mlistMTP.txt"
:multi_manual_INIT
endlocal
set skip_list_split="false"
set "mlistfol=%list_folder%\m_multiMTP"
echo �϶��ļ����ļ����Դ����б�
echo ע�⣺��ס���϶�ÿ���ļ�\�ļ��к󰴻س�
echo.
ECHO ***********************************************
echo ����"1"���Դ�����ǰ�������ҵ
echo ����"2"��ͨ��ѡ��������һ���ļ�����ӵ��б�
echo ����"3"��ͨ��ѡ��������һ���ļ���ӵ��б�
echo ����"4"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"5"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"0"������ģʽѡ��˵�
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
echo ����������ʲô��
echo ......................................................................
echo ���϶������ļ����ļ��У�Ȼ�󰴻س�����Ŀ��ӵ��б��С�
echo.
echo ����"1"����ʼ����ǰ�б�
echo ����"2"����ӵ��ѱ����б����д���
echo ����"3"�������б��Ժ�ʹ��
echo ����"4"��ͨ��ѡ��������һ���ļ�����ӵ��б�
echo ����"5"��ͨ��ѡ��������һ���ļ���ӵ��б�
echo ����"6"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"7"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo.
echo ����"e"���˳�
echo ����"i"�������Ҫ������ļ��б�
echo ����"r"��ɾ��һЩ�ļ���������������
echo ����"z"��ɾ��һЩ�ļ���������������
echo ......................................................................
ECHO *************************************************
echo ��������"0"�����ص�ģʽѡ��˵�
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
echo �ٴα����б���ҵ
echo ......................................................................
echo ����"1"�����б���Ϊ�ϲ����񣨵������ļ��б�
echo ����"2"��ͨ���ļ���baseid���б����Ϊ������
echo.
ECHO *******************************************
echo ����"b"���Լ��������б�
echo ����"0"������ѡ��˵�
ECHO *******************************************
echo.
set /p bs="��������ѡ��"
set bs=%bs:"=%
set vrepack=none
if /i "%bs%"=="b" goto multi_checkagain
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" goto multi_saved_for_later1
if /i "%bs%"=="2" ( %pycommand% "%squirrel%" -splid "%mlistfol%" -tfile "%prog_dir%mlistMTP.txt" )
if /i "%bs%"=="2" del "%prog_dir%mlistMTP.txt"
if /i "%bs%"=="2" goto multi_saved_for_later2
echo �����ѡ��!!
goto multi_saved_for_later
:multi_saved_for_later1
echo.
echo ѡ����������
echo ......................................................................
echo ���б�����ѡ������Ʊ������б���ļ����У�·����"����Ŀ¼\list\m_multi"��
echo.
set /p lname="Input name for the list job: "
set lname=%lname:"=%
move /y "%prog_dir%mlistMTP.txt" "%mlistfol%\%lname%.txt" >nul
echo.
echo �����ѱ���!!!
:multi_saved_for_later2
echo.
echo ����"0"������ģʽѡ��
echo ����"1"���Դ�����������
echo ����"2"���˳�����
echo.
set /p bs="��������ѡ��"
set bs=%bs:"=%
if /i "%bs%"=="0" goto MAIN
if /i "%bs%"=="1" echo.
if /i "%bs%"=="1" echo CREATE ANOTHER JOB
if /i "%bs%"=="1" goto multi_manual_INIT
if /i "%bs%"=="1" goto salida
goto multi_saved_for_later2

:multi_r_files
set /p bs="������Ҫɾ�����ļ������ӵײ���ʼ����"
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
echo ���ش��ģʽ�Ѽ���
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                Ҫ������ļ�
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
echo ������� !conta! ��Ҫ������ļ�
echo .................................................
endlocal

goto multi_checkagain

:m_KeyChange_wrongchoice
echo �����ѡ��
echo ............
:m_patch_keygen
echo *******************************************************
echo ������̨�̼��Ͳ���Ҫ��
echo *******************************************************
echo.
echo 1. YES
echo 2. NO
echo.
ECHO ******************************************
echo ��������"0"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ��"
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
echo ����δ����ļ���
echo *******************************************************
echo ͨ������ID�ֿ�ģʽ����ʶ����ÿ����Ϸ���Ӧ�����ݲ������������ͬһ�б��ļ���multi-xci��multi-nsp
echo.
echo ����"1"���������ļ��ϲ�Ϊһ���ļ�
echo ����"2"����baseid�ָ��ɶ���ļ�
echo.
ECHO *****************************************
echo ������"b"������ѡ���б�
ECHO *****************************************
echo.
set /p bs="��������ѡ��"
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
echo ���ڴ����б� %listname%
echo *******************************************************
exit /B


:m_exit_choice
ECHO ---------------------------------------------------
ECHO *********** �����ļ��Ѵ���! *************
ECHO ---------------------------------------------------
if exist mlistMTP.txt del mlistMTP.txt
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
goto m_exit_choice

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
:MAIN
call "%prog_dir%\MtpMode.bat"
exit /B

:salida
::pause
exit
