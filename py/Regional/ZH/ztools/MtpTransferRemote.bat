@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"
set "bat_name=%~n0"
Title NSC_Builder v1.01-b -- Profile: %ofile_name% -- by JulesOnTheRoad

:MAIN
if exist "MTP2GD.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (MTP2GD.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (MTP2GD.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del MTP2GD.txt )
endlocal
if not exist "MTP2GD.txt" goto manual_INIT
ECHO .......................................................
ECHO �ҵ�һ����һ���б�������ʲô��
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
if /i "%bs%"=="1" goto START_TRANSFER
if /i "%bs%"=="0" call "%prog_dir%ztools\MtpMode.bat"
echo.
echo �����ѡ��
goto prevlist0
:delist
del MTP2GD.txt
cls
call :program_logo
echo -------------------------------------------------
echo MTP - �ӹȸ����̴���
echo -------------------------------------------------
echo ..................................
echo ��������ʼ�µ��б�
echo ..................................

:manual_INIT
endlocal
cls
call :program_logo
echo *******************************************************
echo ѡ����
echo *******************************************************
echo.
echo ����"1"���ӻ����ļ���ѡ���ļ�
echo ����"2"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"3"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"c"��ΪԶ�̿��������ɻ���
ECHO.
echo --- ������GDRIVE�������ӻ�1FICHIER���� ---	
echo.
ECHO *************************************************
echo ��������"0"�����ص�ģʽѡ��˵�
ECHO *************************************************
echo.
%pycommand% "%squirrel%" --mtp_eval_link "%prog_dir%MTP2GD.txt" "%uinput%"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker remote_select_from_cache -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker remote_select_from_libraries -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker remote_select_from_walker -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="c" ( %pycommand% "%squirrel_lb%" -lib_call workers concurrent_cache )
echo.
goto checkagain

:checkagain
echo ������ʲô��
echo ......................................................................
echo ���϶������ļ����ļ��У�Ȼ�󰴻س�����Ŀ��ӵ��б��С�
echo.
echo ����"1"����ʼ��װ
echo ����"2"���Դӻ����ļ���ѡ���ļ�
echo ����"3"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"4"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"c"��ΪԶ�̿��������ɻ���
echo ����"e"���˳�
echo ����"i"���Բ鿴Ҫ������ļ��б�
echo ����"r"��ɾ��һЩ�ļ���������������
echo ����"z"��ɾ�������б�
ECHO.
echo --- ������GDRIVE�������ӻ�1FICHIER���� ---		
echo.
ECHO *************************************************
echo ��������"0"�����ص�ģʽѡ��˵�
ECHO *************************************************
echo.
%pycommand% "%squirrel%" --mtp_eval_link "%prog_dir%MTP2GD.txt" "%uinput%"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" goto MAIN
if /i "%eval%"=="1" goto START_TRANSFER
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker remote_select_from_cache -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker remote_select_from_libraries -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker remote_select_from_walker -xarg "%prog_dir%MTP2GD.txt" )
if /i "%eval%"=="c" ( %pycommand% "%squirrel_lb%" -lib_call workers concurrent_cache )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del "%prog_dir%MTP2GD.txt"
if /i "%eval%"=="1" goto MAIN
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call mtp.mtp_gdrive select_from_libraries -xarg "%prog_dir%MTP2GD.txt" )
echo.
goto checkagain

:r_files
set /p bs="������Ҫɾ�����ļ������ӵײ���ʼ����"
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (MTP2GD.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<MTP2GD.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>MTP2GD.txt.new
endlocal
move /y "MTP2GD.txt.new" "MTP2GD.txt" >nul
endlocal
:showlist
cls
call :program_logo
echo -------------------------------------------------
echo MTP - �ӹȸ����̴���
echo -------------------------------------------------
ECHO Ҫ������ļ���
for /f "tokens=*" %%f in (MTP2GD.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (MTP2GD.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo ������� !conta! ��Ҫ������ļ�
echo .................................................
endlocal
goto checkagain

:START_TRANSFER
cls
call :program_logo
CD /d "%prog_dir%"
%pycommand% "%squirrel_lb%" -lib_call mtp.mtp_gdrive loop_transfer -xarg "%prog_dir%MTP2GD.txt"
echo.
ECHO ---------------------------------------------------
ECHO *********** �����ļ��Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist MTP2GD.txt del MTP2GD.txt
if /i "%va_exit%"=="true" echo ���򼴽��ر�
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo ����"0"������ģʽѡ��
echo ����"1"���˳�����
echo.
set /p bs="��������ѡ��"
set bs=%bs:"=%
if /i "%bs%"=="0" goto manual_Reentry
if /i "%bs%"=="1" goto salida
goto s_exit_choice


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
