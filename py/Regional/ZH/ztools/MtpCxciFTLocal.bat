@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.01-b -- Profile: %ofile_name% -- by JulesOnTheRoad
REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM �ֶ�ģʽ��ʼ�����ļ�����
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -----------------------------------------------
echo MTP - ����XCI�ʹ����Ѽ���
echo -----------------------------------------------
if exist "mtpxci.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (mtpxci.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (mtpxci.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del mtpxci.txt )
endlocal
if not exist "mtpxci.txt" goto manual_INIT
ECHO .......................................................
ECHO �ҵ�һ����һ���б�����������ʲô��
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
if /i "%bs%"=="1" goto start_xci_process
if /i "%bs%"=="0" goto MAIN
echo.
echo �����ѡ��
goto prevlist0
:delist
del mtpxci.txt
cls
call :program_logo
echo -----------------------------------------------
echo MTP - ����XCI�ʹ����Ѽ���
echo -----------------------------------------------
echo ..................................
echo ��������ʼ�µ��б�
echo ..................................
:manual_INIT
endlocal
ECHO ***********************************************
echo ����"1"��ͨ��ѡ�������ļ�����ӵ��б�
echo ����"2"��ͨ��ѡ�������ļ���ӵ��б�
echo ����"3"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"4"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"0"�����ص�ģʽѡ��˵�
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz nsx xcz -tfile "%prog_dir%mtpxci.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mtpxci.txt" mode=folder ext="nsp xci nsz nsx xcz" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%mtpxci.txt" mode=file ext="nsp xci nsz nsx xcz" False False True ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller select_from_local_libraries -xarg "%prog_dir%mtpxci.txt" "mode=installer" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%mtpxci.txt" "extlist=nsp xci nsz xcz" )
goto checkagain
echo.
:checkagain
echo ����������ʲô��
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
%pycommand% "%squirrel%" -t nsp xci nsz nsx xcz -tfile "%prog_dir%mtpxci.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" goto patch_keygen
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg  "%prog_dir%mtpxci.txt" mode=folder ext="nsp xci nsz nsx xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg  "%prog_dir%mtpxci.txt" mode=file ext="nsp xci nsz nsx xcz" False False True )  2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtpinstaller select_from_local_libraries -xarg "%prog_dir%mtpxci.txt" "mode=installer" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%mtpxci.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del mtpxci.txt

goto checkagain

:r_files
set /p bs="������Ҫɾ�����ļ������ӵײ���ʼ����"
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (mtpxci.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<mtpxci.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>mtpxci.txt.new
endlocal
move /y "mtpxci.txt.new" "mtpxci.txt" >nul
endlocal

:showlist
cls
call :program_logo
echo -------------------------------------------------
echo MTP - ����XCI�ʹ����Ѽ���
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                 Ҫ������ļ�
ECHO -------------------------------------------------
for /f "tokens=*" %%f in (mtpxci.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (mtpxci.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo ������� !conta! ��Ҫ������ļ�
echo .................................................
endlocal

goto checkagain

:patch_keygen_wrongchoice
echo �����ѡ��
echo ............
:patch_keygen
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

if %dopatchkg%=="none" goto patch_keygen_wrongchoice

:start_xci_process
%pycommand% "%squirrel_lb%" -lib_call mtp.mtpxci loop_xci_transfer -xarg "%prog_dir%mtpxci.txt" "destiny=False" "verification=%MTP_verification%" "%w_folder%" "patch_keygen=%dopatchkg%" "mode=single"

ECHO ---------------------------------------------------
ECHO *********** �����ļ��Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice


:s_exit_choice
if exist mtpxci.txt del mtpxci.txt
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


echo ���򼴽��˳�
PING -n 2 127.0.0.1 >NUL 2>&1
goto salida


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
