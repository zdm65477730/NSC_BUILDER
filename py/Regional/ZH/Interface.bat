@ECHO OFF
:TOP_INIT
set "prog_dir=%~dp0"
set "bat_name=%~n0"
set "ofile_name=%bat_name%_options.cmd"
Title NSC_Builder v1.01-b -- Profile: %ofile_name% -- by JulesOnTheRoad
set "list_folder=%prog_dir%lists"
::-----------------------------------------------------
::�༭�˱�������������ѡ���ļ�
::-----------------------------------------------------
set "op_file=%~dp0zconfig\%ofile_name%"

::-----------------------------------------------------
::��ѡ���ļ�����ѡ��
::-----------------------------------------------------
setlocal
if exist "%op_file%" call "%op_file%"
endlocal & (
REM environment
set "pycommand=%pycommand%"
set "start_minimized=%start_minimized%"
set "browserpath=%browserpath%"
set "videoplayback=%videoplayback%"
set "height=%height%"
set "width=%width%"
set "port=%port%"
set "host=%host%"
set "noconsole=%noconsole%"
set "pycommandw=%pycommandw%"
REM ����
set "squirrel=%nut%"
REM �ļ�
set "dec_keys=%dec_keys%"
)
::-----------------------------------------------------
::���þ���·��
::-----------------------------------------------------
::��������·��
if exist "%~dp0%squirrel%" set "squirrel=%~dp0%squirrel%"

::��Ҫ�ļ�����·��
if exist "%~dp0%dec_keys%"  set "dec_keys=%~dp0%dec_keys%"
::����ļ���
CD /d "%~dp0"
if not exist "%dec_keys%" ( goto missing_things )

if "%start_minimized%" EQU "yes" ( goto minimize )
goto start
:minimize
if not "%1" == "min" start /MIN cmd /c %0 min & exit/b >nul 2>&1
:start
if "%noconsole%" == "false" (%pycommand% "%squirrel%" -lib_call nutdb  check_files )
if "%noconsole%" == "false" goto n1
start %pycommandw% "%squirrel%" -lib_call workers  back_check_files
start %pycommandw% "%squirrel%" -lib_call workers  scrape_local_libs
start %pycommandw% "%squirrel%" -lib_call workers  scrape_remote_libs
:n1
if "%noconsole%" == "false" (%pycommand% "%squirrel%" -lib_call Interface start -xarg "%browserpath%" "%videoplayback%" "%height%" "%width%" "%port%" "%host%" )
if "%noconsole%" == "false" goto salida
start %pycommandw% "%squirrel%" -lib_call Interface start -xarg "%browserpath%" "%videoplayback%" "%height%" "%width%" "%port%" "%host%" "%noconsole%"
goto salida

:missing_things
echo ....................................
echo ��ȱ���������ݣ�
echo ....................................
echo.
::�ļ�����·��
if not exist "%dec_keys%" echo - "keys.txt"�ļ�ָ����ȷ���߶�ʧ��
echo.
pause
echo ���򼴽��˳�
PING -n 2 127.0.0.1 >NUL 2>&1
goto salida
:salida
REM ��ͣ
exit
