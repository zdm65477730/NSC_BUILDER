:sc1
set "info_dir=%~1INFO"
cls
call :logo
echo ********************************************************
echo �ļ�-��Ϣ
echo ********************************************************
echo.
echo -- ����"0"������������ --
echo.
set /p bs="���Ϸ�XCI/NSP/NSX/NCA�ļ������ڲ���ENTER����"
set bs=%bs:"=%
if /i "%bs%"=="0" goto salida
set "targt=%bs%"
for /f "delims=" %%a in ("%bs%") do set "Extension=%%~xa"
for /f "delims=" %%a in ("%bs%") do set "Name=%%~na"
if "%Extension%" EQU ".nsp" ( goto sc2 )
if "%Extension%" EQU ".nsx" ( goto sc2 )
if "%Extension%" EQU ".xci" ( goto sc2 )
if "%Extension%" EQU ".nca" ( goto sc3 )
if "%Extension%" EQU ".nsz" ( goto sc2_1 )
if "%Extension%" EQU ".xcz" ( goto sc2_1 )
echo �ļ����ʹ���
pause
goto sc1
:sc2
cls
call :logo
echo .......................................................
echo ����"1"����ȡ�ļ��б�
echo ����"2"����ȡ�����б�
echo ����"3"����ȡNUT��Ϣ
echo ����"4"����ȡ��Ϸ��Ϣ�͹̼�Ҫ��
echo ����"5"����ȡCNMT
echo ����"6"����ȡNACP
echo ����"7"����ȡmain.NPDM
echo ����"8"��У���ļ�(XCI/NSP/NSX/NCA)
echo.
echo ����"b"�������ļ�����
echo ����"0"������������
echo.
echo --- ���϶����ļ����ĵ�ǰĿ�� ---
echo .......................................................
echo.
set /p bs="��������ѡ�� "
set bs=%bs:"=%
for /f "delims=" %%a in ("%bs%") do set "Extension=%%~xa"
if "%Extension%" EQU ".*" ( goto wch )
if "%Extension%" EQU ".nsp" ( goto snfi )
if "%Extension%" EQU ".nsx" ( goto snfi )
if "%Extension%" EQU ".xci" ( goto snfi )
if "%Extension%" EQU ".nsz" ( goto snfi2 )
if "%Extension%" EQU ".xcz" ( goto snfi2 )
if "%Extension%" EQU ".nca" ( goto snfi_nca )

if /i "%bs%"=="1" goto g_file_content
if /i "%bs%"=="2" goto g_content_list
if /i "%bs%"=="3" goto n_info
if /i "%bs%"=="4" goto f_info
if /i "%bs%"=="5" goto r_cnmt
if /i "%bs%"=="6" goto r_nacp
if /i "%bs%"=="7" goto r_npdm
if /i "%bs%"=="8" goto verify

if /i "%bs%"=="b" goto sc1
if /i "%bs%"=="0" goto salida
goto wch

:sc2_1
cls
call :logo
echo .......................................................
echo ����"1"����ȡ�ļ��б�
echo ����"2"����ȡ�����б�
echo ����"3"����ȡ��Ϸ��Ϣ�͹̼�Ҫ��
echo ����"4"����ȡCNMT
echo ����"5"����ȡNACP
echo ����"6"���ļ�У��
echo.
echo ����"b"�������ļ�����
echo ����"0"������������
echo.
echo --- ���϶����ļ����ĵ�ǰĿ�� ---
echo .......................................................
echo.
set /p bs="��������ѡ�� "
set bs=%bs:"=%
for /f "delims=" %%a in ("%bs%") do set "Extension=%%~xa"
if "%Extension%" EQU ".*" ( goto wch )
if "%Extension%" EQU ".nsp" ( goto snfi )
if "%Extension%" EQU ".nsx" ( goto snfi )
if "%Extension%" EQU ".xci" ( goto snfi )
if "%Extension%" EQU ".nsz" ( goto snfi2 )
if "%Extension%" EQU ".xcz" ( goto snfi2 )
if "%Extension%" EQU ".nca" ( goto snfi_nca )

if /i "%bs%"=="1" goto g_file_content2
if /i "%bs%"=="2" goto g_content_list2
if /i "%bs%"=="3" goto f_info2
if /i "%bs%"=="4" goto r_cnmt2
if /i "%bs%"=="5" goto r_nacp2
if /i "%bs%"=="6" goto verify2

if /i "%bs%"=="b" goto sc1
if /i "%bs%"=="0" goto salida
goto wch2

:snfi
for /f "delims=" %%a in ("%bs%") do set "Name=%%~na"
set "targt=%bs%"
goto sc2
:snfi2
for /f "delims=" %%a in ("%bs%") do set "Name=%%~na"
set "targt=%bs%"
goto sc2_1
:wch
echo �����ѡ��
pause
goto sc2

:wch2
echo �����ѡ��
pause
goto sc2_1

:g_file_content
cls
call :logo
echo ********************************************************
echo ��ʾNSP�ļ����ݻ�XCI��ȫ��������
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --ADVfilelist "%targt%"
goto sc2

:g_file_content2
cls
call :logo
echo ********************************************************
echo ��ʾNSZ�ļ����ݻ�XCZ��ȫ��������
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --ADVfilelist "%targt%"
goto sc2_1

:g_content_list
cls
call :logo
echo ********************************************************
echo ��ʾ��ID���е�NSP��XCI����
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --ADVcontentlist "%targt%"
goto sc2

:g_content_list2
cls
call :logo
echo ********************************************************
echo ��ʾ��ID���е�NSP��XCI����
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --ADVcontentlist "%targt%"
goto sc2_1

:n_info
cls
call :logo
echo ********************************************************
echo NUT��Ϣ - BY BLAWAR
echo ********************************************************
%pycommand% "%squirrel%" -i "%targt%"
echo.
ECHO ********************************************************
echo �Ƿ�Ҫ����Ϣ���Ƶ��ı��ļ���
ECHO ********************************************************
:n_info_wrong
echo ����"1"������
echo ����"2"��������
echo.
set /p bs="��������ѡ�� "
if /i "%bs%"=="1" goto n_info_print
if /i "%bs%"=="2" goto sc2
echo �����ѡ��
echo.
goto n_info_wrong
:n_info_print
if not exist "%info_dir%" MD "%info_dir%">NUL 2>&1
set "i_file=%info_dir%\%Name%-info.txt"
%pycommand% "%squirrel%" -i "%targt%">"%i_file%"
%pycommand% "%squirrel%" --strip_lines "%i_file%" "2"
ECHO ���
goto sc2

:f_info
cls
call :logo
echo ********************************************************
echo ��ʾ�й�����̼�����Ϣ������
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --translate %transnutdb% --fw_req "%targt%"
goto sc2

:f_info2
cls
call :logo
echo ********************************************************
echo ��ʾ�й�����̼�����Ϣ������
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --translate %transnutdb% --fw_req "%targt%"

goto sc2_1

:r_cnmt
cls
call :logo
echo ********************************************************
echo ��NSP��XCI META NCA����ʾCMT����
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_cnmt "%targt%"
if "%Extension%" EQU ".nsz" ( goto sc2_1 )
if "%Extension%" EQU ".xcz" ( goto sc2_1 )
goto sc2

:r_cnmt2
cls
call :logo
echo ********************************************************
echo ��NSP��XCI META NCA����ʾCMT����
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_cnmt "%targt%"
if "%Extension%" EQU ".nsz" ( goto sc2_1 )
if "%Extension%" EQU ".xcz" ( goto sc2_1 )
goto sc2_1

:r_nacp
cls
call :logo
echo ********************************************************
echo ��NSP��XCI CONTROL NCA����ʾCMT����
echo ********************************************************
echo IMPLEMENTATION OF 0LIAM'S NACP LIBRARY
%pycommand% "%squirrel%" -o "%info_dir%" --Read_nacp "%targt%"
if "%Extension%" EQU ".nsz" ( goto sc2_1 )
if "%Extension%" EQU ".xcz" ( goto sc2_1 )
goto sc2

:r_nacp2
cls
call :logo
echo ********************************************************
echo ��NSP��XCI CONTROL NCA����ʾCMT����
echo ********************************************************
echo IMPLEMENTATION OF 0LIAM'S NACP LIBRARY
%pycommand% "%squirrel%" -o "%info_dir%" --Read_nacp "%targt%"
if "%Extension%" EQU ".nsz" ( goto sc2_1 )
if "%Extension%" EQU ".xcz" ( goto sc2_1 )
goto sc2_1

:r_npdm
cls
call :logo
echo ********************************************************
echo ��NSP��XCI PROGRAM NCA����ʾMAIN.NPDM DATA����
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_npdm "%targt%"
goto sc2


:verify
cls
call :logo
echo ********************************************************
echo У��NSP��XCI��NCA
echo ********************************************************
%pycommand% "%squirrel%" %buffer% -o "%info_dir%" -v "%targt%"

goto sc2

:verify2
cls
call :logo
echo ********************************************************
echo У��NSZ��XCZ�ļ�
echo ********************************************************
%pycommand% "%squirrel%" %buffer% -o "%info_dir%" -v "%targt%"

goto sc2_1

:sc3
cls
call :logo
echo .......................................................
echo ����"1"����ȡNCA NUT-INFO
echo ����"2"����ȡmeta NCA CNMT
echo ����"3"����ȡcontrol NCA NACP
echo ����"4"����ȡprogram NCA NPDM
echo ����"5"��У��NCA
echo.
echo ����"b"�������ļ�����
echo ����"0"������������
echo.
echo --- ���϶����ļ����ĵ�ǰĿ�� ---
echo .......................................................
echo.
set /p bs="��������ѡ�� "
set bs=%bs:"=%
for /f "delims=" %%a in ("%bs%") do set "Extension=%%~xa"
if "%Extension%" EQU ".*" ( goto wch_nca )
if "%Extension%" EQU ".nca" ( goto snfi_nca )
if "%Extension%" EQU ".nsp" ( goto snfi )
if "%Extension%" EQU ".nsx" ( goto snfi )
if "%Extension%" EQU ".xci" ( goto snfi )

if /i "%bs%"=="1" goto n_info_nca
if /i "%bs%"=="2" goto r_cnmt_nca
if /i "%bs%"=="3" goto r_nacp_nca
if /i "%bs%"=="4" goto r_npdm_nca
if /i "%bs%"=="5" goto verify_nca

if /i "%bs%"=="b" goto sc1
if /i "%bs%"=="0" goto salida
goto wch

:snfi_nca
for /f "delims=" %%a in ("%bs%") do set "Name=%%~na"
set "targt=%bs%"
goto sc3
:wch_nca
echo �����ѡ��
pause
goto sc3

:n_info_nca
cls
call :logo
echo ********************************************************
echo NUT��Ϣ
echo ********************************************************
%pycommand% "%squirrel%" -i "%targt%"
echo.
ECHO ********************************************************
echo �Ƿ�Ҫ����Ϣ���Ƶ��ı��ļ���
ECHO ********************************************************
:n_info_wrong_nca
echo ����"1"������
echo ����"2"��������
echo.
set /p bs="��������ѡ�� "
if /i "%bs%"=="1" goto n_info_print_nca
if /i "%bs%"=="2" goto sc3
echo �����ѡ��
echo.
goto n_info_wrong_nca
:n_info_print_nca
if not exist "%info_dir%" MD "%info_dir%">NUL 2>&1
set "i_file=%info_dir%\%Name%-info.txt"
%pycommand% "%squirrel%" -i "%targt%">"%i_file%"
%pycommand% "%squirrel%" -i "%targt%">"%i_file%"
%pycommand% "%squirrel%" --strip_lines "%i_file%" "2"
ECHO ���
goto sc3

:r_cnmt_nca
cls
call :logo
echo ********************************************************
echo ��NSP��XCI META NCA����ʾCMT����
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_cnmt "%targt%"
goto sc3

:r_nacp_nca
cls
call :logo
echo ********************************************************
echo ��NSP��XCI CONTROL NCA����ʾNACP DATA����
echo ********************************************************
echo 0LIAM��NACP���ʵ��
%pycommand% "%squirrel%" -o "%info_dir%" --Read_nacp "%targt%"
goto sc3

:r_npdm_nca
cls
call :logo
echo ********************************************************
echo ��NSP��XCI PROGRAM NCA����ʾMAIN.NPDM����
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_npdm "%targt%"
goto sc3

:verify_nca
cls
call :logo
echo ********************************************************
echo ����NSP��XCI��NCA
echo ********************************************************
%pycommand% "%squirrel%" %buffer% -o "%info_dir%" -v "%targt%"
goto sc3


:salida
exit /B

:logo
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
