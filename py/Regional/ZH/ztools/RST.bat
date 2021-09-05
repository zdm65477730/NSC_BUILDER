@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"

REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM �ļ���ԭ
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -------------------------------------------------
echo �ļ���ԭ�Ѽ���
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
ECHO ������ǰ���б�������ʲô��
:prevlist0
ECHO .......................................................
echo ����"1"������һ���б��Զ���ʼ����
echo ����"2"��ɾ���б�����һ�����б�
echo ����"3"������������һ���б�
echo .......................................................
echo NOTE: By pressing 3 you'll see the previous list
echo before starting the processing the files and you will
echo be able to add and delete items from the list
echo.
ECHO *************************************************
echo ������"0"������ģʽѡ��˵�
ECHO *************************************************
echo.
set /p bs="��������ѡ�� "
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
echo �ļ���ԭ�Ѽ���
echo -------------------------------------------------
echo ..................................
echo �Ѿ���ʼһ���µ��б�
echo ..................................

:manual_INIT
endlocal
ECHO ***********************************************
echo ����"1"�����ļ�����ӵ��б���
echo ����"2"�����ļ���ӵ��б���
echo ����"3"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"4"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"0"������ģʽѡ��˵�
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp xci -tfile "%prog_dir%rstlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%rstlist.txt" mode=folder ext="nsp xci" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%rstlist.txt" mode=file ext="nsp xci" False False True ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%rstlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%rstlist.txt" "extlist=nsp xci" )
goto checkagain
echo.
:checkagain
echo ����Ҫ��ʲô��?
echo ......................................................................
echo "�϶���һ���ļ����ļ��в���Enter������Ŀ��ӵ��б���"
echo.
echo ����"1"����ʼ����
echo ����"2"������һ���ļ�����ӵ��б���
echo ����"3"������һ���ļ���ӵ��б���
echo ����"4"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"5"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"e"���˳�
echo ����"i"���Բ鿴Ҫ������ļ��б�
echo ����"r"��ɾ��һЩ�ļ� (�ӵײ�����)
echo ����"z"��ɾ�������б�
echo ......................................................................
ECHO *************************************************
echo ������"0"������ģʽѡ��˵�
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
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%rstlist.txt" mode=folder ext="nsp xci" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%rstlist.txt" mode=file ext="nsp xci" False False True ) 2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%rstlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%rstlist.txt" "extlist=nsp xci" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del rstlist.txt

goto checkagain

:r_files
set /p bs="����Ҫɾ�����ļ��� (�ӵײ�): "
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
echo �ļ���ԭ�Ѽ���
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                 Ҫ������ļ�
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
echo ������� !conta! Ҫ������ļ�
echo .................................................
endlocal

goto checkagain

:s_cl_wrongchoice
echo �����ѡ��
echo ............
:start_cleaning
echo *******************************************************
echo ѡ����δ����ļ�
echo *******************************************************
echo ���ʹ�úϷ���Դ��NSCB�޸Ĺ����ļ���nca�ļ��ǿɻָ��ģ�
echo ������ǣ������Ͳ�������
echo.
echo ��ģʽ���ָ���
echo   - XCI��NSP֮���ת������NSCB��ɣ�
echo   - ����Ȩɾ������
echo   - ��Կ���ɺ�RSV����
echo.
echo + �в�֧�ֻ�ԭ�����ʻ��޲�����
echo + �ڴ˵�һ��ʵ���У��������ļ�������Ҫ�ɶ����ݷָ�������
echo.
echo ------------------------------------------
echo ����"1"�������ļ�
echo.
ECHO ******************************************
echo ������"b"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ�� "
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
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist rstlist.txt del rstlist.txt
if /i "%va_exit%"=="true" echo PROGRAM WILL CLOSE NOW
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo ����"0"������ģʽѡ��
echo ����"1"���˳�����
echo.
set /p bs="��������ѡ�� "
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
echo ���� !conta! Ҫ������ļ�
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
echo ϣ������Ŀ���
exit /B


:salida
exit /B
