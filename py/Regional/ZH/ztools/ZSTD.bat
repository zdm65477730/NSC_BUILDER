@ECHO OFF
:TOP_INIT
CD /d "%prog_dir%"

REM //////////////////////////////////////////////////
REM /////////////////////////////////////////////////
REM 压缩
REM /////////////////////////////////////////////////
REM ////////////////////////////////////////////////
:normalmode
cls
call :program_logo
echo -------------------------------------------------
echo 压缩或解压模式已激活
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
ECHO 发现以前的列表。你想做什么？?
:prevlist0
ECHO .......................................................
echo 输入"1"，从上一个列表自动开始处理
echo 输入"2"，删除列表并创建一个新列表。
echo 输入"3"，继续构建上一个列表
echo .......................................................
echo 注意：输入 3，您将在开始处理文件之前看到上一个列表，
echo 并且可以从列表中添加和删除项目
echo.
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
ECHO *************************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
if /i "%bs%"=="3" goto showlist
if /i "%bs%"=="2" goto delist
if /i "%bs%"=="1" goto start
if /i "%bs%"=="0" exit /B
echo.
echo 错误的选择
goto prevlist0
:delist
del zzlist.txt
cls
call :program_logo
echo -------------------------------------------------
echo 压缩或解压缩模式已激活
echo -------------------------------------------------
echo ..................................
echo 已经开始一个新的列表
echo ..................................

:manual_INIT
endlocal
echo "拖动另一个文件或文件夹并按回车键将项目添加到列表中"
echo.
ECHO ***********************************************
echo 输入"1"，将文件夹添加到列表中
echo 输入"2"，将文件添加到列表中
echo 输入"3"，通过本地文件库，将文件添加到列表
echo 输入"4"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"0"，返回模式选择菜单
ECHO ***********************************************
echo.
%pycommand% "%squirrel%" -t nsp xci nsz xcz -tfile "%prog_dir%zzlist.txt" -uin "%uinput%" -ff "uinput"
set /p eval=<"%uinput%"
set eval=%eval:"=%
setlocal enabledelayedexpansion
echo+ >"%uinput%"
endlocal
if /i "%eval%"=="0" exit /B
if /i "%eval%"=="1" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%zzlist.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%zzlist.txt" mode=file ext="nsp xci nsz xcz" )  2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%zzlist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="4" ( %pycommand% "%squirrel%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%zzlist.txt" "extlist=nsp xci nsz xcz" )

goto checkagain
echo.
:checkagain
echo 你想要做什么？?
echo ......................................................................
echo "拖动另一个文件或文件夹并按回车键将项目添加到列表中"
echo.
echo 输入"1"，开始处理
echo 输入"2"，将另一个文件夹添加到列表中
echo 输入"3"，将另一个文件添加到列表中
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"e"，退出
echo 输入"i"，以查看要处理的文件列表
echo 输入"r"，删除一些文件 (从底部计数)
echo 输入"z"，删除整个列表
echo ......................................................................
ECHO *************************************************
echo 或输入"0"，返回模式选择菜单
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
if /i "%eval%"=="2" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%zzlist.txt" mode=folder ext="nsp xci nsz xcz" ) 2>&1>NUL
if /i "%eval%"=="3" ( %pycommand% "%squirrel%" -lib_call listmanager selector2list -xarg "%prog_dir%zzlist.txt" mode=file ext="nsp xci nsz xcz" )  2>&1>NUL
if /i "%eval%"=="4" ( %pycommand% "%squirrel%" -lib_call picker_walker select_from_local_libraries -xarg "%prog_dir%zzlist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="5" ( %pycommand% "%squirrel%" -lib_call picker_walker get_files_from_walk -xarg "%prog_dir%zzlist.txt" "extlist=nsp xci nsz xcz" )
if /i "%eval%"=="e" goto salida
if /i "%eval%"=="i" goto showlist
if /i "%eval%"=="r" goto r_files
if /i "%eval%"=="z" del zzlist.txt

goto checkagain

:r_files
set /p bs="输入要删除的文件数 (从底部): "
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
echo 压缩或解压缩模式已激活
echo -------------------------------------------------
ECHO 要处理的文件:
for /f "tokens=*" %%f in (zzlist.txt) do (
echo %%f
)
setlocal enabledelayedexpansion
set conta=
for /f "tokens=*" %%f in (zzlist.txt) do (
set /a conta=!conta! + 1
)
echo .................................................
echo 你添加了 !conta! 要处理的文件
echo .................................................
endlocal

goto checkagain

:s_cl_wrongchoice
echo 错误的选择
echo ............
:start
echo *******************************************************
echo 选择如何处理文件
echo *******************************************************
echo 输入"1"，将nsp或xci压缩成nsz或xcz
echo 输入"2"，并行压缩
echo 输入"3"，解压缩nsz或者xcz
echo.
ECHO ******************************************
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="b" goto checkagain
if /i "%bs%"=="1" goto compression_presets_menu
if /i "%bs%"=="2" goto pararell_compress
if /i "%bs%"=="3" goto decompress
if %choice%=="none" goto s_cl_wrongchoice


:compression_presets_wrongchoice
echo 错误的选择
echo ............
:compression_presets_menu
echo *******************************************************
echo 压缩预设
echo *******************************************************
echo 易于使用的压缩预设
echo.
echo 0. 手动设置
echo 1. 快速 (多线程)           - 等级 1  _ 4   线程
echo 2. 快速 (单线程)           - 等级 1  _ no  线程
echo 3. 中等 (多线程)           - 等级 10 _ 4   线程
echo 4. 中等 (单线程)           - 等级 10 _ no  线程
echo 5. 平均 (多线程)           - 等级 17 _ 2   线程
echo 6. 平均 (单线程)           - 等级 17 _ no  线程
echo 7. 最慢 (单线程)           - 等级 22 _ no  线程
echo 8. 最慢 (多线程)           - 等级 22 _ 1   线程
echo 9. 自定义 (在配置中设置)
echo.
ECHO ******************************************
echo 输入"d"，默认(等级 17_no 线程)
echo 或输入"b"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入压缩等级数据: "
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
echo 错误的选择
echo ............
:levels
echo *******************************************************
echo 输入压缩级别
echo *******************************************************
echo 输入1到22之间的压缩级别
echo 注意:
echo  + 等级 1     -快速和更小的压缩比
echo  + 等级 22    -缓慢但更好的压缩比
echo  等级 10-17 是推荐设置的压缩比
echo.
ECHO ******************************************
echo 输入"d"，默认（等级 17）
echo 或输入"b"，返回上一选项
echo 或输入"x"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入压缩等级数字[1-22]："
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="x" goto checkagain
if /i "%bs%"=="b" goto compression_presets_menu
if /i "%bs%"=="d" set "bs=17"
set "level=%bs%"
if %choice%=="none" goto levels_wrongchoice
goto threads
:threads_wrongchoice
echo 错误的选择
echo ............
:threads
echo *******************************************************
echo 输入要使用的线程数
echo *******************************************************
echo 输入要在0和4之间使用的线程数
echo 注意：建议保持默认
echo   通过使用线程，您可能会获得一些减速，但会降低压缩率
echo   + 22级和4个线程可能会耗尽您的内存
echo   + 建议最大线程压缩级别为17，但会损失压缩率
echo   + -1将其设置为您的逻辑线程数
echo.
ECHO *********************************************
echo 输入"d"，默认（0个线程）
echo 或输入"b"，返回上一选项
echo 或输入"x"，返回列表选项
ECHO *********************************************
echo.
set /p bs="输入压缩线程数："
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="x" goto checkagain
if /i "%bs%"=="b" goto levels
if /i "%bs%"=="d" set "bs=0"
set "workers=%bs%"
if %choice%=="none" goto threads_wrongchoice

:compress
cls
call :program_logo
echo *******************************
echo 压缩NSP或XCI
echo *******************************
CD /d "%prog_dir%"
%pycommand% "%squirrel%" -lib_call listmanager filter_list "%prog_dir%zzlist.txt","ext=nsp xci","token=False",Print="False"
for /f "tokens=*" %%f in (zzlist.txt) do (

%pycommand% "%squirrel%" %buffer% -o "%fold_output%" -tfile "%prog_dir%zzlist.txt" --compress "%level%" --threads "%workers%" --nodelta "%skdelta%" --fexport "%xci_export%"
REM %pycommand% "%squirrel%" %buffer% -o "%fold_output%" -tfile "%prog_dir%zzlist.txt" --compress "%level%" --threads "%workers%" --nodelta "%skdelta%" --pararell "true"

%pycommand% "%squirrel%" --strip_lines "%prog_dir%zzlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:pararell_compress_wrongchoice
echo 错误的选择
echo ............
:pararell_compress
echo *******************************************************
echo 输入要使用的实例数目
echo *******************************************************
echo 输入多个实例以使用大于0的实例
echo 错误的值转换为2。0转换为1
echo 注意：
echo   + 您将创建数量与实例数相等的压缩文件
echo   + 如果您有足够的磁盘空间，则实例比线程更有效，并且计算能力较低
echo   + 如果您有足够的磁盘空间和计算能力，请不要害怕尝试使用10-20个实例
echo   + tqdm在打印带有螺纹的平行条纹时有点不习惯，因此屏幕将在平行模式下每3秒刷新一次以清除不良打印。
echo.
ECHO *********************************************
echo 输入"d"，使用默认值（4个实例）
echo 或输入"b"，返回之前的选项
echo 或输入"x"，返回列表选项
ECHO *********************************************
echo.
set /p bs="输入实例数目 [>1]: "
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="x" goto checkagain
if /i "%bs%"=="b" goto start
if /i "%bs%"=="d" set "bs=4"
set "workers=%bs%"
if %choice%=="none" goto pararell_compress_wrongchoice

:pararell_levels_wrongchoice
echo 错误的选择
echo ............
:pararell_levels
echo *******************************************************
echo 输入压缩级别
echo *******************************************************
echo 输入1到22之间的压缩级别
echo 注意:
echo  + 等级 1     -快速和更小的压缩比
echo  + 等级 22    -缓慢但更好的压缩比
echo  等级10-17是推荐设置的压缩比

echo.
ECHO ******************************************
echo 输入"d"，使用默认值（level 17）
echo 或输入"b"，返回之前的选项
echo 或输入"x"，返回列表选项
ECHO ******************************************
echo.
set /p bs="输入级别数 [1-22]: "
set bs=%bs:"=%
set choice=none
if /i "%bs%"=="x" goto checkagain
if /i "%bs%"=="b" goto pararell_compress
if /i "%bs%"=="d" set "bs=17"
set "level=%bs%"
if %choice%=="none" goto pararell_levels_wrongchoice
goto pcompress
:pcompress
cls
call :program_logo
echo *******************************
echo NSP或XCI并行压缩
echo *******************************
CD /d "%prog_dir%"
echo 过滤列表里的文件扩展名
%pycommand% "%squirrel%" -lib_call listmanager filter_list "%prog_dir%zzlist.txt","ext=nsp xci","token=False",Print="False"
echo Arrange list by filesizes
%pycommand% "%squirrel%" -lib_call listmanager size_sorted_from_tfile -xarg "%prog_dir%zzlist.txt"
echo Start compression by batches of "%workers%"
%pycommand% "%squirrel%" %buffer% -o "%fold_output%" -tfile "%prog_dir%zzlist.txt" --compress "%level%" --threads "%workers%" --nodelta "%skdelta%" --fexport "%xci_export%" --pararell "true"

ECHO ---------------------------------------------------
ECHO *********** 所有文件已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:decompress
cls
call :program_logo
echo **************************
echo 解压NSZ或XCZ
echo **************************
CD /d "%prog_dir%"
%pycommand% "%squirrel%" -lib_call listmanager filter_list "%prog_dir%zzlist.txt","ext=nsz xcz","token=False",Print="False"
for /f "tokens=*" %%f in (zzlist.txt) do (

%pycommand% "%squirrel%" -o "%fold_output%" -tfile "%prog_dir%zzlist.txt" --decompress "auto"

%pycommand% "%squirrel%" --strip_lines "%prog_dir%zzlist.txt"
call :contador_NF
)
ECHO ---------------------------------------------------
ECHO *********** 所有文件都已处理！ *************
ECHO ---------------------------------------------------
goto s_exit_choice

:s_exit_choice
if exist zzlist.txt del zzlist.txt
if /i "%va_exit%"=="true" echo PROGRAM WILL CLOSE NOW
if /i "%va_exit%"=="true" ( PING -n 2 127.0.0.1 >NUL 2>&1 )
if /i "%va_exit%"=="true" goto salida
echo.
echo 输入"0"，返回模式选择
echo 输入"1"，退出程序
echo.
set /p bs="输入您的选择： "
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
echo 仍有 !conta! 要处理的文件
echo ...................................................
PING -n 2 127.0.0.1 >NUL 2>&1
set /a conta=0
endlocal
exit /B



::///////////////////////////////////////////////////
::子程序
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
ECHO                                    VERSION 1.00c
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
echo 希望您玩的开心
exit /B


:salida
exit /B
