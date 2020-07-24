:sc1
set "info_dir=%~1INFO"
cls
call :logo
echo ********************************************************
echo 文件-信息
echo ********************************************************
echo.
echo -- 输入"0"，返回主程序 --
echo.
set /p bs="或拖放XCI/NSP/NSX/NCA文件到窗口并按ENTER键："
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
echo 文件类型错误
pause
goto sc1
:sc2
cls
call :logo
echo .......................................................
echo 输入"1"，获取文件列表
echo 输入"2"，获取内容列表
echo 输入"3"，获取NUT信息
echo 输入"4"，获取游戏信息和固件要求
echo 输入"5"，读取CNMT
echo 输入"6"，读取NACP
echo 输入"7"，读取main.NPDM
echo 输入"8"，校验文件(XCI/NSP/NSX/NCA)
echo.
echo 输入"b"，返回文件加载
echo 输入"0"，返回主程序
echo.
echo --- 或拖动新文件更改当前目标 ---
echo .......................................................
echo.
set /p bs="输入您的选择： "
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
echo 输入"1"，获取文件列表
echo 输入"2"，获取内容列表
echo 输入"3"，获取游戏信息和固件要求
echo 输入"4"，读取CNMT
echo 输入"5"，读取NACP
echo 输入"6"，文件校验
echo.
echo 输入"b"，返回文件加载
echo 输入"0"，返回主程序
echo.
echo --- 或拖动新文件更改当前目标 ---
echo .......................................................
echo.
set /p bs="输入您的选择： "
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
echo 错误的选择
pause
goto sc2

:wch2
echo 错误的选择
pause
goto sc2_1

:g_file_content
cls
call :logo
echo ********************************************************
echo 显示NSP文件内容或XCI安全分区内容
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --ADVfilelist "%targt%"
goto sc2

:g_file_content2
cls
call :logo
echo ********************************************************
echo 显示NSZ文件内容或XCZ安全分区内容
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --ADVfilelist "%targt%"
goto sc2_1

:g_content_list
cls
call :logo
echo ********************************************************
echo 显示按ID排列的NSP或XCI内容
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --ADVcontentlist "%targt%"
goto sc2

:g_content_list2
cls
call :logo
echo ********************************************************
echo 显示按ID排列的NSP或XCI内容
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --ADVcontentlist "%targt%"
goto sc2_1

:n_info
cls
call :logo
echo ********************************************************
echo NUT信息 - BY BLAWAR
echo ********************************************************
%pycommand% "%squirrel%" -i "%targt%"
echo.
ECHO ********************************************************
echo 是否要将信息复制到文本文件？
ECHO ********************************************************
:n_info_wrong
echo 输入"1"，复制
echo 输入"2"，不复制
echo.
set /p bs="输入您的选择： "
if /i "%bs%"=="1" goto n_info_print
if /i "%bs%"=="2" goto sc2
echo 错误的选择
echo.
goto n_info_wrong
:n_info_print
if not exist "%info_dir%" MD "%info_dir%">NUL 2>&1
set "i_file=%info_dir%\%Name%-info.txt"
%pycommand% "%squirrel%" -i "%targt%">"%i_file%"
%pycommand% "%squirrel%" --strip_lines "%i_file%" "2"
ECHO 完成
goto sc2

:f_info
cls
call :logo
echo ********************************************************
echo 显示有关所需固件的信息和数据
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --translate %transnutdb% --fw_req "%targt%"
goto sc2

:f_info2
cls
call :logo
echo ********************************************************
echo 显示有关所需固件的信息和数据
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --translate %transnutdb% --fw_req "%targt%"

goto sc2_1

:r_cnmt
cls
call :logo
echo ********************************************************
echo 从NSP或XCI META NCA里显示CMT数据
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_cnmt "%targt%"
if "%Extension%" EQU ".nsz" ( goto sc2_1 )
if "%Extension%" EQU ".xcz" ( goto sc2_1 )
goto sc2

:r_cnmt2
cls
call :logo
echo ********************************************************
echo 从NSP或XCI META NCA里显示CMT数据
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_cnmt "%targt%"
if "%Extension%" EQU ".nsz" ( goto sc2_1 )
if "%Extension%" EQU ".xcz" ( goto sc2_1 )
goto sc2_1

:r_nacp
cls
call :logo
echo ********************************************************
echo 从NSP或XCI CONTROL NCA里显示CMT数据
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
echo 从NSP或XCI CONTROL NCA里显示CMT数据
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
echo 从NSP或XCI PROGRAM NCA里显示MAIN.NPDM DATA数据
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_npdm "%targt%"
goto sc2


:verify
cls
call :logo
echo ********************************************************
echo 校验NSP，XCI或NCA
echo ********************************************************
%pycommand% "%squirrel%" %buffer% -o "%info_dir%" -v "%targt%"

goto sc2

:verify2
cls
call :logo
echo ********************************************************
echo 校验NSZ或XCZ文件
echo ********************************************************
%pycommand% "%squirrel%" %buffer% -o "%info_dir%" -v "%targt%"

goto sc2_1

:sc3
cls
call :logo
echo .......................................................
echo 输入"1"，获取NCA NUT-INFO
echo 输入"2"，读取meta NCA CNMT
echo 输入"3"，读取control NCA NACP
echo 输入"4"，读取program NCA NPDM
echo 输入"5"，校验NCA
echo.
echo 输入"b"，返回文件加载
echo 输入"0"，返回主程序
echo.
echo --- 或拖动新文件更改当前目标 ---
echo .......................................................
echo.
set /p bs="输入您的选择： "
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
echo 错误的选择
pause
goto sc3

:n_info_nca
cls
call :logo
echo ********************************************************
echo NUT信息
echo ********************************************************
%pycommand% "%squirrel%" -i "%targt%"
echo.
ECHO ********************************************************
echo 是否要将信息复制到文本文件？
ECHO ********************************************************
:n_info_wrong_nca
echo 输入"1"，复制
echo 输入"2"，不复制
echo.
set /p bs="输入您的选择： "
if /i "%bs%"=="1" goto n_info_print_nca
if /i "%bs%"=="2" goto sc3
echo 错误的选择
echo.
goto n_info_wrong_nca
:n_info_print_nca
if not exist "%info_dir%" MD "%info_dir%">NUL 2>&1
set "i_file=%info_dir%\%Name%-info.txt"
%pycommand% "%squirrel%" -i "%targt%">"%i_file%"
%pycommand% "%squirrel%" -i "%targt%">"%i_file%"
%pycommand% "%squirrel%" --strip_lines "%i_file%" "2"
ECHO 完成
goto sc3

:r_cnmt_nca
cls
call :logo
echo ********************************************************
echo 从NSP或XCI META NCA中显示CMT数据
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_cnmt "%targt%"
goto sc3

:r_nacp_nca
cls
call :logo
echo ********************************************************
echo 从NSP或XCI CONTROL NCA中显示NACP DATA数据
echo ********************************************************
echo 0LIAM的NACP库的实现
%pycommand% "%squirrel%" -o "%info_dir%" --Read_nacp "%targt%"
goto sc3

:r_npdm_nca
cls
call :logo
echo ********************************************************
echo 从NSP或XCI PROGRAM NCA中显示MAIN.NPDM数据
echo ********************************************************
%pycommand% "%squirrel%" -o "%info_dir%" --Read_npdm "%targt%"
goto sc3

:verify_nca
cls
call :logo
echo ********************************************************
echo 检验NSP，XCI或NCA
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
ECHO                                    VERSION 1.00c
ECHO -------------------------------------------------------------------------------------
ECHO Program's github: https://github.com/julesontheroad/NSC_BUILDER
ECHO Blawar's github:  https://github.com/blawar
ECHO Luca Fraga's github: https://github.com/LucaFraga
ECHO -------------------------------------------------------------------------------------
exit /B
