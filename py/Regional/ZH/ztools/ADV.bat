@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"

REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM �߼�ģʽ
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -------------------------------------------------
echo �߼�ѡ��
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
ECHO ������ǰ���б�������ʲô?
:prevlist0
ECHO .......................................................
echo ����"1"������һ���б��Զ���ʼ����
echo ����"2"��ɾ���б�����һ�����б�
echo ����"3"������������һ���б�
echo .......................................................
echo ע�⣺����3�������ڿ�ʼ�����ļ�֮ǰ������һ���б�
echo ���ҿ��Դ��б�����Ӻ�ɾ����Ŀ
echo.
ECHO *************************************************
echo ������"0"������ģʽѡ��˵�
ECHO *************************************************
echo.
set /p bs="��������ѡ�� "
set bs=%bs:"=%
if /i "%bs%"=="3" goto showlist
if /i "%bs%"=="2" goto delist
if /i "%bs%"=="1" goto start
if /i "%bs%"=="0" exit /B
echo.
echo �����ѡ��
goto prevlist0
:delist
del advlist.txt
cls
call :program_logo
echo -------------------------------------------------
echo �߼�ѡ��
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
echo ����Ҫ��ʲô��
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
echo Or ����"0"����ģʽѡ��˵�
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
set /p bs="����Ҫɾ�����ļ��� (�ӵײ�): "
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
echo �߼�ѡ��
echo -------------------------------------------------
ECHO -------------------------------------------------
ECHO                 Ҫ������ļ�
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
echo ������� !conta! Ҫ������ļ�
echo .................................................
endlocal

goto exit /B

:s_cl_wrongchoice
echo �����ѡ��
echo ............
:start
echo *******************************************************
echo ѡ����δ����ļ�
echo *******************************************************
echo ����"1"����NSP��XCI����ȡ�����ļ�
echo ����"2"������ԭʼ��ȡ������NCA��������������
echo ����"3"��������NCA�ļ���ȡΪ���ı�
echo ����"4"����NSP��XCI����ȡNCA
echo ����"5"���޲������ʻ�Ҫ��
echo.
ECHO ******************************************
echo ������"b"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ�� "
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
echo ��NSP��XCI��ȡ�����ļ�
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%prog_dir%NSCB_extracted" -tfile "%prog_dir%advlist.txt" -x ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:raw_extract
cls
call :program_logo
echo ********************************************************
echo ��ԭʼģʽ��NSP��XCI����ȡ�����ļ�
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%prog_dir%NSCB_extracted" -tfile "%prog_dir%advlist.txt" -raw_x ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:ext_plaintext
cls
call :program_logo
echo ********************************************************
echo ��NSP��XCI�е������ļ���ȡΪ���ı�
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%prog_dir%NSCB_extracted" -tfile "%prog_dir%advlist.txt" -plx ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:ext_fromnca
cls
call :program_logo
echo ********************************************************
echo ��NSP��XCI����ȡ�ڲ�NCA�ļ�
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%prog_dir%NSCB_extracted" -tfile "%prog_dir%advlist.txt" -nfx ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:patch_lnkacc_wrongchoice
echo �����ѡ��
echo ............
:patch_lnkacc
echo *******************************************************
echo ѡ����δ����ļ�
echo *******************************************************
echo ����"1"ֱ���޲�ԭʼ�ļ�
echo ����"2"�������ļ�
echo.
ECHO ***********************************************
echo Or ����"b"��������һѡ��s
ECHO ***********************************************
echo.
set /p bs="��������ѡ�� "
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
echo �޲������ʻ�����
echo ********************************************************
CD /d "%prog_dir%"
for /f "tokens=*" %%f in (advlist.txt) do (

%pycommand% "%squirrel%" %buffer% -tfile "%prog_dir%advlist.txt" --remlinkacc ""

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:patch_lnkacc_mode2
cls
call :program_logo
echo ********************************************************
echo �޲������ʻ�����
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
echo ���
call :thumbup
call :delay
if exist templist.txt del templist.txt

%pycommand% "%squirrel%" --strip_lines "%prog_dir%advlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist advlist.txt del advlist.txt
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
for /f "tokens=*" %%f in (advlist.txt) do (
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
echo ϣ����������
exit /B


:salida
exit /B
