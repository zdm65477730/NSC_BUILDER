@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"

REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM ѹ��
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -------------------------------------------------
echo ѹ�����ѹģʽ�Ѽ���
echo -------------------------------------------------
if exist "zzlist.txt" goto prevlist
goto manual_INIT
:prevlist
set conta=0
for /f "tokens=*" %%f in (zzlist.txt) do (
echo %%f
) >NUL 2>&1
setlocal enabledelayedexpansion
for /f "tokens=*" %%f in (zzlist.txt) do (
set /a conta=!conta! + 1
) >NUL 2>&1
if !conta! LEQ 0 ( del zzlist.txt )
endlocal
if not exist "zzlist.txt" goto manual_INIT
ECHO .......................................................
ECHO ������ǰ���б�������ʲô��?
:prevlist0
ECHO .......................................................
echo ����"1"������һ���б��Զ���ʼ����
echo ����"2"��ɾ���б�����һ�����б�
echo ����"3"������������һ���б�
echo .......................................................
echo ע�⣺���� 3�������ڿ�ʼ�����ļ�֮ǰ������һ���б�
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
del zzlist.txt
cls
call :program_logo
echo -------------------------------------------------
echo ѹ�����ѹ��ģʽ�Ѽ���
echo -------------------------------------------------
echo ..................................
echo �Ѿ���ʼһ���µ��б�
echo ..................................

:manual_INIT
endlocal
echo "�϶���һ���ļ����ļ��в����س�������Ŀ��ӵ��б���"
echo.
ECHO ***********************************************
echo ����"1"�����ļ�����ӵ��б���
echo ����"2"�����ļ���ӵ��б���
echo ����"3"��ͨ�������ļ��⣬���ļ���ӵ��б�
echo ����"4"��ͨ��folder-walker�ݹ�ķ�ʽ�����ļ���ӵ��б�
echo ����"0"������ģʽѡ��˵�
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%zzlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%zzlist.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%zzlist.txt" mode=file ext="nsp xci nsz xcz" False False True )  2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%zzlist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%zzlist.txt" "extlist=nsp xci nsz xcz" )

goto checkagain
echo.
:checkagain
echo ����Ҫ��ʲô��?
echo ......................................................................
echo "�϶���һ���ļ����ļ��в����س�������Ŀ��ӵ��б���"
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
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%zzlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal

if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" goto start
if /i "%eval%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%zzlist.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel_lb%" -lib_call listmanager selector2list -xarg "%prog_dir%zzlist.txt" mode=file ext="nsp xci nsz xcz" False False True )  2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%zzlist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel_lb%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%zzlist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del zzlist.txt

goto checkagain

:r_files
set /p bs="����Ҫɾ�����ļ��� (�ӵײ�): "
set bs=%bs:"=%

setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (zzlist.txt) do (
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
(for /f "tokens=1,*delims=:" %%a in (' findstr /n "^" ^<zzlist.txt'
) do Echo=%skip%|findstr ",%%a," 2>&1>NUL ||Echo=%%b
)>zzlist.txt.new
endlocal
move /y "zzlist.txt.new" "zzlist.txt" >nul
endlocal

:showlist
cls
call :program_logo
echo -------------------------------------------------
echo ѹ�����ѹ��ģʽ�Ѽ���
echo -------------------------------------------------
ECHO Ҫ������ļ�:
for /f "tokens=*" %%f in (zzlist.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (zzlist.txt) do (
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
:start
echo *******************************************************
echo ѡ����δ����ļ�
echo *******************************************************
echo ����"1"����nsp��xciѹ����nsz��xcz
echo ����"2"������ѹ��
echo ����"3"����ѹ��nsz����xcz
echo.
ECHO ******************************************
echo ������"b"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="��������ѡ�� "
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" goto compression_presets_menu
if /i "%bs%"=="2" goto pararell_compress
if /i "%bs%"=="3" goto decompress
if "%choice%"=="none" goto s_cl_wrongchoice


:compression_presets_wrongchoice
echo �����ѡ��
echo ............
:compression_presets_menu
echo *******************************************************
echo ѹ��Ԥ��
echo *******************************************************
echo ����ʹ�õ�ѹ��Ԥ��
echo.
echo 0. �ֶ�����
echo 1. ���� (���߳�)           - �ȼ� 1  _ 4   �߳�
echo 2. ���� (���߳�)           - �ȼ� 1  _ no  �߳�
echo 3. �е� (���߳�)           - �ȼ� 10 _ 4   �߳�
echo 4. �е� (���߳�)           - �ȼ� 10 _ no  �߳�
echo 5. ƽ�� (���߳�)           - �ȼ� 17 _ 2   �߳�
echo 6. ƽ�� (���߳�)           - �ȼ� 17 _ no  �߳�
echo 7. ���� (���߳�)           - �ȼ� 22 _ no  �߳�
echo 8. ���� (���߳�)           - �ȼ� 22 _ 1   �߳�
echo 9. �Զ��� (������������)
echo.
ECHO ******************************************
echo ����"d"��Ĭ��(�ȼ� 17_no �߳�)
echo ������"b"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="����ѹ���ȼ�����: "
set bs=%bs:"=%
set level=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="d" set "level=17"
if /i "%bs%"=="d" set "workers=0"

if /i "%bs%"=="0" goto levels
if /i "%bs%"=="1" set "level=1"
if /i "%bs%"=="1" set "workers=4"
if /i "%bs%"=="2" set "level=1"
if /i "%bs%"=="2" set "workers=0"
if /i "%bs%"=="3" set "level=10"
if /i "%bs%"=="3" set "workers=4"
if /i "%bs%"=="4" set "level=10"
if /i "%bs%"=="4" set "workers=0"
if /i "%bs%"=="5" set "level=17"
if /i "%bs%"=="5" set "workers=2"
if /i "%bs%"=="6" set "level=17"
if /i "%bs%"=="6" set "workers=0"
if /i "%bs%"=="7" set "level=22"
if /i "%bs%"=="7" set "workers=0"
if /i "%bs%"=="8" set "level=22"
if /i "%bs%"=="8" set "workers=1"
if /i "%bs%"=="9" set "level=%compression_lv%"
if /i "%bs%"=="9" set "workers=%compression_threads%"

if "%level%"=="none" goto compression_presets_wrongchoice
goto compress


:levels_wrongchoice
echo �����ѡ��
echo ............
:levels
echo *******************************************************
echo ����ѹ������
echo *******************************************************
echo ����1��22֮���ѹ������
echo ע��:
echo  + �ȼ� 1     -���ٺ͸�С��ѹ����
echo  + �ȼ� 22    -���������õ�ѹ����
echo  �ȼ� 10-17 ���Ƽ����õ�ѹ����
echo.
ECHO ******************************************
echo ����"d"��Ĭ�ϣ��ȼ� 17��
echo ������"b"��������һѡ��
echo ������"x"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="����ѹ���ȼ�����[1-22]��"
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="x" goto checkagain
if /i "%bs%"=="b" goto compression_presets_menu
if /i "%bs%"=="d" set "bs=17"
set "level=%bs%"
if "%choice%"=="none" goto levels_wrongchoice
goto threads
:threads_wrongchoice
echo �����ѡ��
echo ............
:threads
echo *******************************************************
echo ����Ҫʹ�õ��߳���
echo *******************************************************
echo ����Ҫ��0��4֮��ʹ�õ��߳���
echo ע�⣺���鱣��Ĭ��
echo   + ͨ��ʹ���̣߳������ܻ���һЩ���٣�������ʧѹ����
echo   + 22����4���߳̿��ܻ�ľ������ڴ�
echo   + ��������߳�ѹ������Ϊ17��������ʧѹ����
echo   + -1��������Ϊ�����߼��߳���
echo.
ECHO *********************************************
echo ����"d"��Ĭ�ϣ�0���̣߳�
echo ������"b"��������һѡ��
echo ������"x"�������б�ѡ��
ECHO *********************************************
echo.
set /p bs="����ѹ���߳�����"
set bs=%bs:"=%
set workers=none
if /i "%bs%"=="x" goto checkagain
if /i "%bs%"=="b" goto levels
if /i "%bs%"=="d" set "bs=0"
set "workers=%bs%"
if "%workers%"=="none" goto threads_wrongchoice

:compress
cls
call :program_logo
echo *******************************
echo ѹ��NSP��XCI
echo *******************************
CD /d "%prog_dir%"
%pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%zzlist.txt","ext=nsp xci","token=False",Print="False"
for /f "tokens=*" %%f in (zzlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%fold_output%" -tfile "%prog_dir%zzlist.txt" --compress "%level%" --threads "%workers%" --nodelta "%skdelta%" --fexport "%xci_export%"
REM %pycommand% "%squirrel%" %buffer% -o "%fold_output%" -tfile "%prog_dir%zzlist.txt" --compress "%level%" --threads "%workers%" --nodelta "%skdelta%" --pararell "true"

%pycommand% "%squirrel%" --strip_lines "%prog_dir%zzlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:pararell_compress_wrongchoice
echo �����ѡ��
echo ............
:pararell_compress
echo *******************************************************
echo ����Ҫʹ�õ�ʵ����Ŀ
echo *******************************************************
echo ������ʵ����ʹ�ô���0��ʵ��
echo �����ֵת��Ϊ2��0ת��Ϊ1
echo ע�⣺
echo   + ��������������ʵ������ȵ�ѹ���ļ�
echo   + ��������㹻�Ĵ��̿ռ䣬��ʵ�����̸߳���Ч�����Ҽ��������ϵ�
echo   + ��������㹻�Ĵ��̿ռ�ͼ����������벻Ҫ���³���ʹ��10-20��ʵ��
echo   + tqdm�ڴ�ӡ�������Ƶ�ƽ������ʱ�е㲻ϰ�ߣ������Ļ����ƽ��ģʽ��ÿ3��ˢ��һ�������������ӡ��
echo.
ECHO *********************************************
echo ����"d"��ʹ��Ĭ��ֵ��4��ʵ����
echo ������"b"������֮ǰ��ѡ��
echo ������"x"�������б�ѡ��
ECHO *********************************************
echo.
set /p bs="����ʵ����Ŀ [>1]: "
set bs=%bs:"=%
set workers=none
if /i "%bs%"=="x" goto checkagain
if /i "%bs%"=="b" goto start
if /i "%bs%"=="d" set "bs=4"
set "workers=%bs%"
if "%workers%"=="none" goto pararell_compress_wrongchoice
goto pararell_levels

:pararell_levels_wrongchoice
echo �����ѡ��
echo ............
:pararell_levels
echo *******************************************************
echo ����ѹ������
echo *******************************************************
echo ����1��22֮���ѹ������
echo ע��:
echo  + �ȼ� 1     -���ٺ͸�С��ѹ����
echo  + �ȼ� 22    -���������õ�ѹ����
echo  �ȼ�10-17���Ƽ����õ�ѹ����

echo.
ECHO ******************************************
echo ����"d"��ʹ��Ĭ��ֵ��level 17��
echo ������"b"������֮ǰ��ѡ��
echo ������"x"�������б�ѡ��
ECHO ******************************************
echo.
set /p bs="���뼶���� [1-22]: "
set bs=%bs:"=%
set level=none
if /i "%bs%"=="x" goto checkagain
if /i "%bs%"=="b" goto pararell_compress
if /i "%bs%"=="d" set "bs=17"
set "level=%bs%"
if "%level%"=="none" goto pararell_levels_wrongchoice
goto pcompress
:pcompress
cls
call :program_logo
echo *******************************
echo NSP��XCI����ѹ��
echo *******************************
CD /d "%prog_dir%"
echo �����б�����ļ���չ��
%pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%zzlist.txt","ext=nsp xci","token=False",Print="False"
echo Arrange list by filesizes
%pycommand% "%squirrel_lb%" -lib_call listmanager size_sorted_from_tfile -xarg "%prog_dir%zzlist.txt"
echo Start compression by batches of "%workers%"
%pycommand% "%squirrel%" %buffer% -o "%fold_output%" -tfile "%prog_dir%zzlist.txt" --compress "%level%" --threads "%workers%" --nodelta "%skdelta%" --fexport "%xci_export%" --pararell "true"

ECHO ---------------------------------------------------
ECHO *********** �����ļ��Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:decompress
cls
call :program_logo
echo **************************
echo ��ѹNSZ��XCZ
echo **************************
CD /d "%prog_dir%"
%pycommand% "%squirrel_lb%" -lib_call listmanager filter_list "%prog_dir%zzlist.txt","ext=nsz xcz","token=False",Print="False"
for /f "tokens=*" %%f in (zzlist.txt) do (

%pycommand% "%squirrel%" -o "%fold_output%" -tfile "%prog_dir%zzlist.txt" --decompress "auto"

%pycommand% "%squirrel%" --strip_lines "%prog_dir%zzlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** �����ļ����Ѵ��� *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist zzlist.txt del zzlist.txt
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
for /f "tokens=*" %%f in (zzlist.txt) do (
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
