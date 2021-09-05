:sc1
set "op_file=%~1"
set "listmanager=%~2"
set "batdepend=%~3"
cls
call :logo
echo ********************************************************
echo 选项-配置
echo ********************************************************
echo 输入"1"，自动模式选项
echo 输入"2"，全局和手动模式选项
echo 输入"3"，验证密钥文件keys.txt
echo 输入"4"，更新nutdb
echo 输入"5"，界面选项
echo 输入"6"，服务器选项
echo 输入"7"，谷歌网盘选项
echo 输入"8"，MTP选项
echo.
echo 输入"c"，读取当前配置文件
echo 输入"d"，设置默认设置
echo 输入"0"，返回主程序
echo .......................................................
echo.
set /p bs="输入您的选择： "
if /i "%bs%"=="1" goto sc2
if /i "%bs%"=="2" goto sc3
if /i "%bs%"=="3" goto verify_keys
if /i "%bs%"=="4" goto update_nutdb
if /i "%bs%"=="5" goto interface
if /i "%bs%"=="6" goto server
if /i "%bs%"=="7" goto google_drive
if /i "%bs%"=="8" goto MTP

if /i "%bs%"=="c" call :curr_set1
if /i "%bs%"=="c" call :curr_set2
if /i "%bs%"=="c" echo.
if /i "%bs%"=="c" pause

if /i "%bs%"=="d" call :def_set1
if /i "%bs%"=="d" call :def_set2
if /i "%bs%"=="d" echo.
if /i "%bs%"=="d" pause

if /i "%bs%"=="0" goto salida
echo 错误的选择
echo.
goto sc1

:sc2
cls
call :logo
echo ********************************************************
echo 自动模式配置
echo ********************************************************
echo 输入"1"，更改重新打包配置
echo 输入"2"，更改文件夹的处理方式
echo 输入"3"，更改RSV修补配置
echo 输入"4"，以更改密钥生成配置
echo.
echo 输入"c"，读取当前自动模式设置
echo 输入"d"，设置默认自动模式设置
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo .......................................................
echo.
set /p bs="输入您的选择： "
if /i "%bs%"=="1" goto op_repack
if /i "%bs%"=="2" goto op_pfolder
if /i "%bs%"=="3" goto op_RSV
if /i "%bs%"=="4" goto op_KGEN

if /i "%bs%"=="c" call :curr_set1
if /i "%bs%"=="c" echo.
if /i "%bs%"=="c" pause

if /i "%bs%"=="d" call :def_set1
if /i "%bs%"=="d" echo.
if /i "%bs%"=="d" pause
if /i "%bs%"=="d" goto sc1

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida
echo 错误的选择
echo.
goto sc2

:op_repack
cls
call :logo
echo *******************************************************
echo 重新打包配置
echo *******************************************************
echo 自动模式选择
echo .......................................................
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为XCI
echo 输入"3"，全部都要
echo 输入"4"，从升级包里删除增量部分
echo 输入"5"，按cnmt顺序重建NSPs
echo.
echo 输入"b"，返回自动模式-配置
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo .......................................................
echo.
set /p bs="输入您的选择： "
set "v_rep=none"
if /i "%bs%"=="1" set "v_rep=nsp"
if /i "%bs%"=="2" set "v_rep=xci"
if /i "%bs%"=="3" set "v_rep=both"
if /i "%bs%"=="4" set "v_rep=nodelta"
if /i "%bs%"=="5" set "v_rep=rebuild"

if /i "%bs%"=="b" goto sc2
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_rep%"=="none" echo 错误的选择
if "%v_rep%"=="none" echo.
if "%v_rep%"=="none" goto op_repack

set v_rep="vrepack=%v_rep%"
set v_rep="%v_rep%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "57" -nl "set %v_rep%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "57" -nl "Line in config was changed to: "
echo.
pause
goto sc2

:op_pfolder
cls
call :logo
echo **********************************************************************
echo 文件夹处理
echo **********************************************************************
echo 如何在自动模式下处理文件夹
echo ......................................................................
echo 输入"1"，单独重新打包文件夹的文件（单个内容文件）
echo 输入"2"，将文件夹的文件重新打包在一起（多内容文件）
echo 输入"3"，通过BASE ID重新打包文件夹的文件
echo.
echo 输入"b"，返回自动模式-配置
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ......................................................................
echo.
set /p bs="输入您的选择： "
set "v_fold=none"
if /i "%bs%"=="1" set "v_fold=indiv"
if /i "%bs%"=="2" set "v_fold=multi"
if /i "%bs%"=="3" set "v_fold=baseid"

if /i "%bs%"=="b" goto sc2
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_fold%"=="none" echo 错误的选择
if "%v_fold%"=="none" echo.
if "%v_fold%"=="none" goto op_pfolder

set v_fold="fi_rep=%v_fold%"
set v_fold="%v_fold%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "61" -nl "set %v_fold%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "61" -nl "Line in config was changed to: "
echo.
pause
goto sc2

:op_RSV
cls
call :logo
echo ***************************************************************************
echo 魔改所需的系统版本
echo ***************************************************************************
echo 补丁meta NCA中为所要求的系统版本（自动模式）
echo ...........................................................................
echo 补丁所需的系统版本，以便控制台不要求更新更大的所需固件版本来解密密钥
echo.
echo 输入"1"，魔改
echo 输入"2"，不魔改
echo.
echo 输入"b"，返回自动模式-配置
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_RSV=none"
if /i "%bs%"=="1" set "v_RSV=-pv true"
if /i "%bs%"=="2" set "v_RSV=-pv false"

if /i "%bs%"=="b" goto sc2
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_RSV%"=="none" echo 错误的选择
if "%v_RSV%"=="none" echo.
if "%v_RSV%"=="none" goto op_RSV

set v_RSV="patchRSV=%v_RSV%"
set v_RSV="%v_RSV%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "41" -nl "set %v_RSV%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "41" -nl "Line in config was changed to: "
echo.
pause
goto sc2

:op_KGEN
cls
call :logo
echo ***************************************************************************
echo 所需系统版本
echo ***************************************************************************
echo 如果大于设定值，则更改键生成（自动模式）
echo ...........................................................................
echo 更改动态生成并重新计算密钥块，以使用较低的主密钥解密nca。
echo.
echo 输入"f"，不魔改
echo 输入"0"，魔改版本FW 1.0
echo 输入"1"，魔改版本FW 2.0-2.3
echo 输入"2"，魔改版本FW 3.0
echo 输入"3"，魔改版本FW 3.0.1-3.0.2
echo 输入"4"，魔改版本FW 4.0.0-4.1.0
echo 输入"5"，魔改版本FW 5.0.0-5.1.0
echo 输入"6"，魔改版本FW 6.0.0-6.1.0
echo 输入"7"，魔改版本FW 6.2.0
echo 输入"8"，魔改版本FW 7.0.0-8.0.1
echo 输入"9"，魔改版本FW 8.1.0
echo 输入"10"，魔改版本FW 9.0.0-9.0.1
echo 输入"11"，魔改版本FW 9.1.0-11.0.3
echo 输入"12"，魔改版本FW 12.1.0-
echo.
echo 输入"b"，返回自动模式-配置
echo 输入"c"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_KGEN=none"
set "v_CAPRSV="
if /i "%bs%"=="f" set "v_KGEN=-kp false"
if /i "%bs%"=="0" set "v_KGEN=-kp 0"
if /i "%bs%"=="0" set "v_CAPRSV=--RSVcap 0"
if /i "%bs%"=="1" set "v_KGEN=-kp 1"
if /i "%bs%"=="1" set "v_CAPRSV=--RSVcap 65796"
if /i "%bs%"=="2" set "v_KGEN=-kp 2"
if /i "%bs%"=="2" set "v_CAPRSV=--RSVcap 201327002"
if /i "%bs%"=="3" set "v_KGEN=-kp 3"
if /i "%bs%"=="3" set "v_CAPRSV=--RSVcap 201392178"
if /i "%bs%"=="4" set "v_KGEN=-kp 4"
if /i "%bs%"=="4" set "v_CAPRSV=--RSVcap 268435656"
if /i "%bs%"=="5" set "v_KGEN=-kp 5"
if /i "%bs%"=="5" set "v_CAPRSV=--RSVcap 335544750"
if /i "%bs%"=="6" set "v_KGEN=-kp 6"
if /i "%bs%"=="6" set "v_CAPRSV=--RSVcap 402653494"
if /i "%bs%"=="7" set "v_KGEN=-kp 7"
if /i "%bs%"=="7" set "v_CAPRSV=--RSVcap 404750336"
if /i "%bs%"=="8" set "v_KGEN=-kp 8"
if /i "%bs%"=="8" set "v_CAPRSV=--RSVcap 469762048"
if /i "%bs%"=="9" set "v_KGEN=-kp 9"
if /i "%bs%"=="9" set "v_CAPRSV=--RSVcap 537919488"
if /i "%bs%"=="10" set "v_KGEN=-kp 10"
if /i "%bs%"=="10" set "v_CAPRSV=--RSVcap 603979776"
if /i "%bs%"=="11" set "v_KGEN=-kp 11"
if /i "%bs%"=="11" set "v_CAPRSV=--RSVcap 605028352"
if /i "%bs%"=="12" set "v_KGEN=-kp 12"
if /i "%bs%"=="12" set "v_CAPRSV=--RSVcap 806354944"

if /i "%bs%"=="b" goto sc2
if /i "%bs%"=="c" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_KGEN%"=="none" echo 错误的选择
if "%v_KGEN%"=="none" echo.
if "%v_KGEN%"=="none" goto op_KGEN

set v_KGEN="vkey=%v_KGEN%"
set v_KGEN="%v_KGEN%"
set v_CAPRSV="capRSV=%v_CAPRSV%"
set v_CAPRSV="%v_CAPRSV%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "95" -nl "set %v_KGEN%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "42" -nl "set %v_CAPRSV%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "95" -nl "Line in config was changed to: "
%pycommand% "%listmanager%" -rl "%op_file%" -ln "42" -nl "Line in config was changed to: "
echo.
pause
goto sc2

:sc3
cls
call :logo
echo **********************************************
echo 全局选项-配置
echo **********************************************
echo 输入"1"，更改文本和背景色
echo 输入"2"，更改工作文件夹的名称
echo 输入"3"，更改输出文件夹的名称
echo 输入"4"，更改增量文件处理
echo 输入"5"，更改zip配置 (LEGACY)
echo 输入"6"，更改自动退出配置
echo 输入"7"，跳过密钥生成提示
echo 输入"8"，设置文件流缓冲区
echo 输入"9"，设置文件fat32\exfat选项
echo 输入"10"，组织输出文件
echo 输入"11"，设置新模式或旧模式
echo 输入"12"，设置罗马字母名当使用direct-multi
echo 输入"13"，在文件信息中翻译游戏描述行
echo 输入"14" to 更改工作线程数量（暂时禁用）
echo 输入"15" to 设置用户预设NSZ压缩
echo 输入"16" to 设置压缩的XCI导出格式
echo.
echo 输入"c"，读取当前全局设置
echo 输入"d"，设置默认全局设置
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择： "

if /i "%bs%"=="1" goto op_color
if /i "%bs%"=="2" goto op_wfolder
if /i "%bs%"=="3" goto op_ofolder
if /i "%bs%"=="4" goto op_delta
if /i "%bs%"=="5" goto op_zip
if /i "%bs%"=="6" goto op_aexit
if /i "%bs%"=="7" goto op_kgprompt
if /i "%bs%"=="8" goto op_buffer
if /i "%bs%"=="9" goto op_fat
if /i "%bs%"=="10" goto op_oforg
if /i "%bs%"=="11" goto op_nscbmode
if /i "%bs%"=="12" goto op_romanize
if /i "%bs%"=="13" goto op_translate
if /i "%bs%"=="14" goto op_threads
if /i "%bs%"=="15" goto op_NSZ1
if /i "%bs%"=="16" goto op_NSZ3

if /i "%bs%"=="c" call :curr_set2
if /i "%bs%"=="c" echo.
if /i "%bs%"=="c" pause

if /i "%bs%"=="d" call :def_set2
if /i "%bs%"=="d" echo.
if /i "%bs%"=="d" pause
if /i "%bs%"=="d" goto sc1

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

echo 错误的选择
echo.
goto sc3

:op_color
cls
call :logo
echo ********************************************************
echo 颜色-配置                              
echo ********************************************************
echo --------------------------------------------------------
echo 前景颜色（文本颜色）                     
echo --------------------------------------------------------
echo 输入"1"，将文本颜色更改为亮白色（默认）
echo 输入"2"，将文本颜色更改为黑色
echo 输入"3"，将文本颜色更改为蓝色
echo 输入"4"，将文本颜色更改为绿色
echo 输入"5"，将文本颜色更改为水绿色
echo 输入"6"，将文本颜色更改为红色
echo 输入"7"，将文本颜色更改为紫色
echo 输入"8"，将文本颜色更改为黄色
echo 输入"9"，将文本颜色更改为白色
echo 输入"10"，将文本颜色更改为灰色
echo 输入"11"，将文本颜色更改为浅蓝色
echo 输入"12"，将文本颜色更改为浅绿色
echo 输入"13"，将文本颜色更改为浅水绿色
echo 输入"14"，将文本颜色更改为浅红色
echo 输入"15"，将文本颜色更改为浅紫色
echo 输入"16"，将文本颜色更改为浅黄色
echo.
echo 输入"d"，设置默认颜色配置
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo.
set /p bd="输入您的选择： "

set "v_colF=F"
if /i "%bd%"=="1" set "v_colF=F"
if /i "%bd%"=="2" set /a "v_colF=0"
if /i "%bd%"=="3" set /a "v_colF=3"
if /i "%bd%"=="4" set /a "v_colF=1"
if /i "%bd%"=="5" set /a "v_colF=2"
if /i "%bd%"=="6" set /a "v_colF=4"
if /i "%bd%"=="7" set /a "v_colF=5"
if /i "%bd%"=="8" set /a "v_colF=6"
if /i "%bd%"=="9" set /a "v_colF=7"
if /i "%bd%"=="10" set /a "v_colF=8"
if /i "%bd%"=="11" set /a "v_colF=9"
if /i "%bd%"=="12" set "v_colF=A"
if /i "%bd%"=="13" set "v_colF=B"
if /i "%bd%"=="14" set "v_colF=C"
if /i "%bd%"=="15" set "v_colF=D"
if /i "%bd%"=="16" set "v_colF=E"

if /i "%bd%"=="d" set "v_colF=F"
if /i "%bd%"=="d" set /a "v_colB=1"
if /i "%bd%"=="d" goto do_set_col

if /i "%bd%"=="b" goto sc3
if /i "%bd%"=="0" goto sc1
if /i "%bd%"=="e" goto salida

echo -----------------------------------------------------
echo 背景色
echo -----------------------------------------------------
echo 输入"1"，将背景色更改为蓝色（默认）
echo 输入"2"，将背景色更改为黑色
echo 输入"3"，将背景色更改为绿色
echo 输入"4"，将背景色更改为水绿色
echo 输入"5"，将背景色更改为红色
echo 输入"6"，将背景色更改为紫色
echo 输入"7"，将背景色更改为黄色
echo 输入"8"，将背景色更改为白色
echo 输入"9"，将背景色更改为灰色
echo 输入"10"，将背景色更改为亮白色
echo 输入"11"，将背景色更改为浅蓝色
echo 输入"12"，将背景色更改为浅绿色
echo 输入"13"，将背景色更改为浅水绿色
echo 输入"14"，将背景色更改为浅红色
echo 输入"15"，将背景色更改为浅紫色
echo 输入"16"，将背景色更改为浅黄色
echo.
echo 输入"d"，设置默认颜色配置
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择： "

set /a "v_colB=1"
if /i "%bs%"=="1" set /a "v_colB=1"
if /i "%bs%"=="2" set /a "v_colB=0"
if /i "%bs%"=="3" set /a "v_colB=2"
if /i "%bs%"=="4" set /a "v_colB=3"
if /i "%bs%"=="5" set /a "v_colB=4"
if /i "%bs%"=="6" set /a "v_colB=5"
if /i "%bs%"=="7" set /a "v_colB=6"
if /i "%bs%"=="8" set /a "v_colB=7"
if /i "%bs%"=="9" set /a "v_colB=8"
if /i "%bs%"=="10" set "v_colB=F"
if /i "%bs%"=="11" set /a "v_colB=9"
if /i "%bs%"=="12" set "v_colB=A"
if /i "%bs%"=="13" set "v_colB=B"
if /i "%bs%"=="14" set "v_colB=C"
if /i "%bs%"=="15" set "v_colB=D"
if /i "%bs%"=="16" set "v_colB=E"

if /i "%bs%"=="d" set "v_colF=F"
if /i "%bs%"=="d" set /a "v_colB=1"
if /i "%bs%"=="d" goto do_set_col

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

:do_set_col
setlocal enabledelayedexpansion
set "v_col=!v_colB!!v_colF!"
color !v_col!
%pycommand% "%listmanager%" -cl "%op_file%" -ln "3" -nl "color !v_col!"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "3" -nl "Line in config was changed to: "
endlocal
echo.
pause
goto sc3

:op_wfolder
cls
call :logo
echo ***********************************
echo 工作文件夹名称-配置
echo ***********************************
echo 输入"1"，以设置默认工作文件夹的名称
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo.
set /p bs="Or type a new name: "
set "v_wf=%bs%"
if /i "%bs%"=="1" set "v_wf=NSCB_temp"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

set v_wf="w_folder=%v_wf%"
set v_wf="%v_wf%"

%pycommand% "%listmanager%" -cl "%op_file%" -ln "8" -nl "set %v_wf%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "8" -nl "Line in config was changed to: "
echo.
pause
goto sc3


:op_ofolder
cls
call :logo
echo *************************************
echo 输出文件夹的名称-配置
echo *************************************
echo 输入"1"，设置默认输出文件夹的名称
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo.
set /p bs="Or type a new name: "
set "v_of=%bs%"
if /i "%bs%"=="1" set "v_of=NSCB_output"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

set v_of="fold_output=%v_of%"
set v_of="%v_of%"

%pycommand% "%listmanager%" -cl "%op_file%" -ln "10" -nl "set %v_of%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "10" -nl "Line in config was changed to: "
echo.
pause
goto sc3


:op_delta
cls
call :logo
echo ***************************************************************************
echo 增量文件处理-配置
echo ***************************************************************************
echo 提取更新时跳过增量NCA文件
echo ...........................................................................
echo 增量用于将以前的更新转换为新的更新，更新可以包含完整的更新+增量。
echo 增量部分对于xci而言是不必要的，但它们可用于安装更快的nsp并将先前的更新转换为新的更新。
echo 没有增量更新，您的旧更新将保留在系统中，您需要将其卸载。
echo.
echo 输入"1"，跳过增量（默认配置）
echo 输入"2"，重新打包增量部分
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_delta=none"
if /i "%bs%"=="1" set "v_delta=--C_clean_ND"
if /i "%bs%"=="1" set "v_delta2_=-ND true"
if /i "%bs%"=="2" set "v_delta=--C_clean"
if /i "%bs%"=="2" set "v_delta2_=-ND false"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_delta%"=="none" echo 错误的选择
if "%v_delta%"=="none" echo.
if "%v_delta%"=="none" goto op_delta

set v_delta="nf_cleaner=%v_delta%"
set v_delta="%v_delta%"
set v_delta2_="skdelta=%v_delta2_%"
set v_delta2_="%v_delta2_%"

%pycommand% "%listmanager%" -cl "%op_file%" -ln "36" -nl "set %v_delta%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "36" -nl "Line in config was changed to: "
echo.
%pycommand% "%listmanager%" -cl "%op_file%" -ln "37" -nl "set %v_delta2_%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "37" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_zip
cls
call :logo
echo ***************************************************************************
echo zip文件生成
echo ***************************************************************************
echo 使用键块和文件信息生成zip文件
echo ...........................................................................
echo.
echo 输入"1"，生成zip文件
echo 输入"2"，不生成zip文件（默认配置）
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_gzip=none"
if /i "%bs%"=="1" set "v_gzip=true"
if /i "%bs%"=="2" set "v_gzip=false"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_gzip%"=="none" echo 错误的选择
if "%v_gzip%"=="none" echo.
if "%v_gzip%"=="none" goto op_zip

set v_gzip="zip_restore=%v_gzip%"
set v_gzip="%v_gzip%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "78" -nl "set %v_gzip%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "78" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_aexit
cls
call :logo
echo ***************************************************************************
echo 自动退出配置（手动模式）
echo ***************************************************************************
echo 处理完文件后自动退出或请求下一步处理。
echo ...........................................................................
echo.
echo 输入"1"，以设置自动退出（默认配置）
echo 输入"2"，设置为自动退出
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_exit=none"
if /i "%bs%"=="1" set "v_exit=false"
if /i "%bs%"=="2" set "v_exit=true"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_exit%"=="none" echo 错误的选择
if "%v_exit%"=="none" echo.
if "%v_exit%"=="none" goto op_aexit

set v_exit="va_exit=%v_exit%"
set v_exit="%v_exit%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "101" -nl "set %v_exit%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "101" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_kgprompt
cls
call :logo
echo ***************************************************************************
echo 显示\跳过所需的系统版本和密钥生成更改属性
echo ***************************************************************************
echo.
echo 输入"1"，显示RSV提示（默认配置）
echo 输入"2"，不显示RSV提示
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "skipRSVprompt=none"
if /i "%bs%"=="1" set "skipRSVprompt=false"
if /i "%bs%"=="2" set "skipRSVprompt=true"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%skipRSVprompt%"=="none" echo 错误的选择
if "%skipRSVprompt%"=="none" echo.
if "%skipRSVprompt%"=="none" goto op_kgprompt

set skipRSVprompt="skipRSVprompt=%skipRSVprompt%"
set skipRSVprompt="%skipRSVprompt%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "108" -nl "set %skipRSVprompt%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "108" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_buffer
cls
call :logo
echo ***************************************************************************
echo 为NSP或XCI的文件复制设置附加缓冲区
echo ***************************************************************************
echo 此选项会影响进程的速度。理想的缓冲取决于你的系统。
echo 默认设置为64kb
echo.
echo 输入"1"，将缓冲区更改为80KB
echo 输入"2"，将缓冲区更改为72kb
echo 输入"3"，将缓冲区更改为64KB（默认）
echo 输入"4"，将缓冲区更改为56KB
echo 输入"5"，将缓冲区更改为48kb
echo 输入"6"，将缓冲区更改为40KB
echo 输入"7"，将缓冲区更改为32KB
echo 输入"8"，将缓冲区更改为24kb
echo 输入"9"，将缓冲区更改为16KB
echo 输入"10"，将缓冲区更改为8kb

echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_buffer=none"
if /i "%bs%"=="1" set "v_buffer=-b 81920"
if /i "%bs%"=="2" set "v_buffer=-b 73728"
if /i "%bs%"=="3" set "v_buffer=-b 65536"
if /i "%bs%"=="4" set "v_buffer=-b 57344"
if /i "%bs%"=="5" set "v_buffer=-b 49152"
if /i "%bs%"=="6" set "v_buffer=-b 40960"
if /i "%bs%"=="7" set "v_buffer=-b 32768"
if /i "%bs%"=="8" set "v_buffer=-b 24576"
if /i "%bs%"=="9" set "v_buffer=-b 16384"
if /i "%bs%"=="10" set "v_buffer=-b 8192"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_buffer%"=="none" echo 错误的选择
if "%v_buffer%"=="none" echo.
if "%v_buffer%"=="none" goto op_buffer

set v_buffer="buffer=%v_buffer%"
set v_buffer="%v_buffer%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "32" -nl "set %v_buffer%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "32" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_fat
cls
call :logo
echo ***************************************************************************
echo 设置将SD卡的文件系统格式
echo ***************************************************************************
echo SX OS ROM菜单支持分割后的ns0，ns1...nsp文件：以及已归档文件夹中的00、01文件，以对应所提供的这2个选项。
echo.
echo 输入"1"，将卡格式更改为exfat（默认）
echo 输入"2"，将卡格式更改为FAT32（XC0和NS0文件）
echo 输入"3"，将所有CFW的卡格式更改为FAT32（存档文件夹）
echo.
echo 注意：存档文件夹选项将NSP文件份文件导出为文件夹和XCI文件。
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_fat1=none"
set "v_fat2=none"
if /i "%bs%"=="1" set "v_fat1=-fat exfat"
if /i "%bs%"=="1" set "v_fat2=-fx files"
if /i "%bs%"=="2" set "v_fat1=-fat fat32"
if /i "%bs%"=="2" set "v_fat2=-fx files"
if /i "%bs%"=="3" set "v_fat1=-fat fat32"
if /i "%bs%"=="3" set "v_fat2=-fx folder"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_fat1%"=="none" echo 错误的选择
if "%v_fat1%"=="none" echo.
if "%v_fat1%"=="none" goto op_fat
if "%v_fat2%"=="none" echo 错误的选择
if "%v_fat2%"=="none" echo.
if "%v_fat2%"=="none" goto op_fat

set v_fat1="fatype=%v_fat1%"
set v_fat1="%v_fat1%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "116" -nl "set %v_fat1%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "116" -nl "Line in config was changed to: "
echo.
set v_fat2="fexport=%v_fat2%"
set v_fat2="%v_fat2%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "117" -nl "set %v_fat2%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "117" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_oforg
cls
call :logo
echo ***************************************************************************
echo 输出文件夹中输出项的组织格式
echo ***************************************************************************
echo.
echo 输入"1"，单独组织文件（默认）
echo 输入"2"，组织按内容设置的文件夹中的文件
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_oforg=none"
if /i "%bs%"=="1" set "v_oforg=inline"
if /i "%bs%"=="2" set "v_oforg=subfolder"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_oforg%"=="none" echo 错误的选择
if "%v_oforg%"=="none" echo.
if "%v_oforg%"=="none" goto op_oforg

set v_oforg="oforg=%v_oforg%"
set v_oforg="%v_oforg%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "125" -nl "set %v_oforg%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "125" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_nscbmode
cls
call :logo
echo ***************************************************************************
echo 新模式或旧模式启动程序
echo ***************************************************************************
echo.
echo 输入"1"，以开始新模式（默认）
echo 输入"2"，以从旧模式开始
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_nscbmode=none"
if /i "%bs%"=="1" set "v_nscbmode=new"
if /i "%bs%"=="2" set "v_nscbmode=legacy"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_nscbmode%"=="none" echo 错误的选择
if "%v_nscbmode%"=="none" echo.
if "%v_nscbmode%"=="none" goto op_nscbmode

set v_nscbmode="NSBMODE=%v_nscbmode%"
set v_nscbmode="%v_nscbmode%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "132" -nl "set %v_nscbmode%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "132" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_romanize
cls
call :logo
echo ***************************************************************************
echo 直接多功能的罗马字母结果名称
echo ***************************************************************************
echo.
echo 输入"1"，转换日文或亚洲名称到罗马文（默认）
echo 输入"2"，保留读到的主流基本文件名
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_roma=none"
if /i "%bs%"=="1" set "v_roma=TRUE"
if /i "%bs%"=="2" set "v_roma=FALSE"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_roma%"=="none" echo 错误的选择
if "%v_roma%"=="none" echo.
if "%v_roma%"=="none" goto op_romanize

set v_roma="romaji=%v_roma%"
set v_roma="%v_roma%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "139" -nl "set %v_roma%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "139" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_translate
cls
call :logo
echo *****************************************************************************
echo 将游戏说明行从日语，中文，韩语翻译成英语
echo *****************************************************************************
echo.
echo 注意：与romaji的翻译不同，NSCB向GOOGLE TRANSLATE进行API调用
echo.
echo 输入"1"，翻译描述（默认）
echo 输入"2"，保留从nutdb文件里读到的描述
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_trans=none"
if /i "%bs%"=="1" set "v_trans=TRUE"
if /i "%bs%"=="2" set "v_trans=FALSE"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_trans%"=="none" echo 错误的选择
if "%v_trans%"=="none" echo.
if "%v_trans%"=="none" goto op_translate

set v_trans="transnutdb=%v_trans%"
set v_trans="%v_trans%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "147" -nl "set %v_trans%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "147" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_threads
cls
call :logo
echo ***************************************************************************
echo 设置线程操作的工作线程数
echo ***************************************************************************
echo 当前用于重命名器和数据库构建模式
echo 有关更多值，请使用文本编辑器编辑NSCB_options.cmd
echo.
echo 输入"1"，使用1个线程（默认或没有激活）
echo 输入"2"，使用5个线程
echo 输入"3"，使用10个线程
echo 输入"4"，使用20个线程
echo 输入"5"，使用30个线程
echo 输入"6"，使用40个线程
echo 输入"7"，使用50个线程
echo 输入"8"，使用60个线程
echo 输入"9"，使用70个线程
echo 输入"10"，使用80个线程
echo 输入"11"，使用90个线程
echo 输入"12"，使用100个线程
echo.
echo 输入"b"，返回全局选项
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_workers=none"
if /i "%bs%"=="1" set "v_workers=-threads 1"
if /i "%bs%"=="2" set "v_workers=-threads 5"
if /i "%bs%"=="3" set "v_workers=-threads 10"
if /i "%bs%"=="4" set "v_workers=-threads 20"
if /i "%bs%"=="5" set "v_workers=-threads 30"
if /i "%bs%"=="6" set "v_workers=-threads 40"
if /i "%bs%"=="7" set "v_workers=-threads 50"
if /i "%bs%"=="8" set "v_workers=-threads 60"
if /i "%bs%"=="9" set "v_workers=-threads 70"
if /i "%bs%"=="10" set "v_workers=-threads 80"
if /i "%bs%"=="11" set "v_workers=-threads 90"
if /i "%bs%"=="12" set "v_workers=-threads 100"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_workers%"=="none" echo 错误的选择
if "%v_workers%"=="none" echo.
if "%v_workers%"=="none" goto op_threads

set v_workers="workers=%v_workers%"
set v_workers="%v_workers%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "153" -nl "set %v_workers%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "153" -nl "Line in config was changed to: "
echo.
pause
goto sc3

:op_NSZ1
cls
call :logo
echo ***************************************************************************
echo 用户压缩选项
echo ***************************************************************************
echo ************************
echo 输入压缩级别
echo ************************
echo 输入1到22之间的压缩级别
echo 注：
echo  + Level 1 - 快速但压缩比小
echo  + Level 22 - 缓慢但更好的压缩比
echo  Levels 10-17 推荐
echo.
echo 输入"b"，返回全局选项
echo 输入"x"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_nszlevels=none"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="x" goto sc1
if /i "%bs%"=="e" goto salida

set "v_nszlevels=%bs%"
set v_nszlevels="compression_lv=%v_nszlevels%"
set v_nszlevels="%v_nszlevels%"
if "%v_nszlevels%"=="none" echo 错误的选择
if "%v_nszlevels%"=="none" echo.
if "%v_nszlevels%"=="none" goto op_NSZ1
%pycommand% "%listmanager%" -cl "%op_file%" -ln "158" -nl "set %v_nszlevels%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "158" -nl "Line in config was changed to: "
:op_NSZ2
echo.
echo *******************************************************
echo 输入要使用的线程数
echo *******************************************************
echo 输入要在0和4之间使用的线程数
echo 注：
echo + 通过使用线程，您可能会获得一些减速，但会降低压缩率
echo + 22级和4个线程可能会耗尽您的内存
echo + 建议的最大线程压缩级别为17，但会损失压缩率
echo.
echo 输入"b"，返回全局选项
echo 输入"x"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set "v_nszthreads=none"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="x" goto sc1
if /i "%bs%"=="e" goto salida

set "v_nszthreads=%bs%"
set v_nszthreads="compression_threads=%v_nszthreads%"
set v_nszthreads="%v_nszthreads%"
if "%v_nszthreads%"=="none" echo 错误的选择
if "%v_nszthreads%"=="none" echo.
if "%v_nszthreads%"=="none" goto op_NSZ2
%pycommand% "%listmanager%" -cl "%op_file%" -ln "159" -nl "set %v_nszthreads%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "159" -nl "Line in config was changed to: "
pause
goto sc3
:op_NSZ3
echo.
echo *******************************************************
echo 导出XCI的格式
echo *******************************************************
echo.
echo 输入"1"，导出为XCZ-超级修剪（默认值）
echo 输入"2"，导出为NSZ
echo.
echo 记住，tinfoil可以同时安装两种格式，因此不建议导出为nsz。
echo 如果您真的想将它们作为nsz，请以这种方式进行操作，以使游戏中的nca文件可恢复。
echo 注意：当前，此还原需要首先将文件解压缩为nsp，更好的直接还原功能将很快添加进来。

echo.echo.
echo 输入"b"，返回全局选项
echo 输入"x"，返回配置菜单
echo 输入"e"，返回主程序
echo ...........................................................................
echo.
set "v_xcz_export=none"
set /p bs="输入您的选择： "

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="x" goto sc1
if /i "%bs%"=="e" goto salida

if /i "%bs%"=="1" set "v_xcz_export=xcz"
if /i "%bs%"=="2" set "v_xcz_export=nsz"
set v_xcz_export="xci_export=%v_xcz_export%"
set v_xcz_export="%v_xcz_export%"
if "%v_xcz_export%"=="none" echo 错误的选择
if "%v_xcz_export%"=="none" echo.
if "%v_xcz_export%"=="none" goto op_NSZ3
%pycommand% "%listmanager%" -cl "%op_file%" -ln "160" -nl "set %v_xcz_export%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "160" -nl "Line in config was changed to: "
pause
goto sc3

:def_set1
echo.
echo **自动模式选项**
REM vrepack
set "v_rep=both"
set v_rep="vrepack=%v_rep%"
set v_rep="%v_rep%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "57" -nl "set %v_rep%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "57" -nl "Line in config was changed to: "

REM fi_rep
set "v_fold=multi"
set v_fold="fi_rep=%v_fold%"
set v_fold="%v_fold%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "61" -nl "set %v_fold%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "61" -nl "Line in config was changed to: "

REM v_RSV
set "v_RSV=-pv false"
set v_RSV="patchRSV=%v_RSV%"
set v_RSV="%v_RSV%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "41" -nl "set %v_RSV%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "41" -nl "Line in config was changed to: "

REM vkey
set "v_KGEN=-kp false"
set v_KGEN="vkey=%v_KGEN%"
set v_KGEN="%v_KGEN%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "95" -nl "set %v_KGEN%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "95" -nl "Line in config was changed to: "

exit /B

:def_set2
echo.
echo **全局选项**
REM OP_COLOR
set "v_colF=F"
set /a "v_colB=1"
setlocal enabledelayedexpansion
set "v_col=!v_colB!!v_colF!"
color !v_col!
%pycommand% "%listmanager%" -cl "%op_file%" -ln "3" -nl "color !v_col!"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "3" -nl "Line in config was changed to: "
endlocal

REM w_folder
set "v_wf=NSCB_temp"
set v_wf="w_folder=%v_wf%"
set v_wf="%v_wf%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "8" -nl "set %v_wf%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "8" -nl "Line in config was changed to: "

REM v_of
set "v_of=NSCB_output"
set v_of="fold_output=%v_of%"
set v_of="%v_of%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "10" -nl "set %v_of%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "10" -nl "Line in config was changed to: "

REM v_delta
set "v_delta=--C_clean_ND"
set v_delta="nf_cleaner=%v_delta%"
set v_delta="%v_delta%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "36" -nl "set %v_delta%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "36" -nl "Line in config was changed to: "

REM v_delta2
set "v_delta2_=-ND true"
set v_delta2_="skdelta=%v_delta2_%"
set v_delta2_="%v_delta2_%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "37" -nl "set %v_delta2_%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "37" -nl "Line in config was changed to: "

REM zip_restore
set "v_gzip=false"
set v_gzip="zip_restore=%v_gzip%"
set v_gzip="%v_gzip%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "78" -nl "set %v_gzip%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "78" -nl "Line in config was changed to: "

REM AUTO-EXIT
set "v_exit=false"
set v_exit="va_exit=%v_exit%"
set v_exit="%v_exit%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "101" -nl "set %v_exit%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "101" -nl "Line in config was changed to: "

REM skipRSVprompt
set "skipRSVprompt=false"
set skipRSVprompt="skipRSVprompt=%skipRSVprompt%"
set skipRSVprompt="%skipRSVprompt%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "108" -nl "set %skipRSVprompt%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "108" -nl "Line in config was changed to: "

REM buffer
set "v_buffer=-b 65536"
set v_buffer="buffer=%v_buffer%"
set v_buffer="%v_buffer%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "32" -nl "set %v_buffer%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "32" -nl "Line in config was changed to: "


REM FAT format
set "v_fat1=-fat exfat"
set v_fat1="fatype=%v_fat1%"
set v_fat1="%v_fat1%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "116" -nl "set %v_fat1%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "116" -nl "Line in config was changed to: "

set "v_fat2=-fx files"
set v_fat2="fexport=%v_fat2%"
set v_fat2="%v_fat2%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "117" -nl "set %v_fat2%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "117" -nl "Line in config was changed to: "

REM OUTPUT ORGANIZING format
set "v_oforg=inline"
set v_oforg="oforg=%v_oforg%"
set v_oforg="%v_oforg%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "125" -nl "set %v_oforg%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "125" -nl "Line in config was changed to: "

REM NSCB MODE
set "v_nscbmode=new"
set v_nscbmode="NSBMODE=%v_nscbmode%"
set v_nscbmode="%v_nscbmode%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "132" -nl "set %v_nscbmode%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "132" -nl "Line in config was changed to: "

REM ROMAJI
set "v_roma=TRUE"
set v_roma="romaji=%v_roma%"
set v_roma="%v_roma%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "139" -nl "set %v_roma%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "139" -nl "Line in config was changed to: "

REM TRANSLATE
set "v_trans=FALSE"
set v_trans="transnutdb=%v_trans%"
set v_trans="%v_trans%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "147" -nl "set %v_trans%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "147" -nl "Line in config was changed to: "

REM WORKERS
set v_workers="workers=-threads 1"
set v_workers="%v_workers%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "153" -nl "set %v_workers%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "153" -nl "Line in config was changed to: "

REM COMPRESSION
set "v_nszlevels=17"
set v_nszlevels="compression_lv=%v_nszlevels%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "158" -nl "set %v_nszlevels%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "158" -nl "Line in config was changed to: "
set "v_nszlevels=0"
set v_nszlevels="compression_threads=%v_nszlevels%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "159" -nl "set %v_nszlevels%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "159" -nl "Line in config was changed to: "
set "v_xcz_export=xcz"
set v_xcz_export="xci_export=%v_xcz_export%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "160" -nl "set %v_xcz_export%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "160" -nl "Line in config was changed to: "

exit /B

:curr_set1
echo.
echo **当前自动模式选项**
REM vrepack
%pycommand% "%listmanager%" -rl "%op_file%" -ln "57" -nl "File repack is set to: "

REM fi_rep
%pycommand% "%listmanager%" -rl "%op_file%" -ln "61" -nl "Folder processing is set to: "

REM v_RSV
%pycommand% "%listmanager%" -rl "%op_file%" -ln "41" -nl "RequiredSystemVersion patching is set to: "

REM vkey
%pycommand% "%listmanager%" -rl "%op_file%" -ln "95" -nl "Keygeneration variable is set to: "

exit /B

:curr_set2
echo.
echo **当前全局选项**
REM OP_COLOR
%pycommand% "%listmanager%" -rl "%op_file%" -ln "3" -nl "Color is set to: "
endlocal

REM w_folder
%pycommand% "%listmanager%" -rl "%op_file%" -ln "8" -nl "Work Folder is set to: "

REM v_of
%pycommand% "%listmanager%" -rl "%op_file%" -ln "10" -nl "Output Folder is set to: "

REM v_delta
%pycommand% "%listmanager%" -rl "%op_file%" -ln "36" -nl "Delta Skipping is set to: "

REM v_delta2
%pycommand% "%listmanager%" -rl "%op_file%" -ln "37" -nl "Delta Skipping (direct functions) is set to: "

REM zip_restore
%pycommand% "%listmanager%" -rl "%op_file%" -ln "78" -nl "Zip generation is set to: "

REM AUTO-EXIT
%pycommand% "%listmanager%" -rl "%op_file%" -ln "101" -nl "Auto-exit is set to: "

REM skipRSVprompt
%pycommand% "%listmanager%" -rl "%op_file%" -ln "108" -nl "Skip RSV selection is set to: "

REM buffer
%pycommand% "%listmanager%" -rl "%op_file%" -ln "32" -nl "Buffer is set to: "

REM FAT format
%pycommand% "%listmanager%" -rl "%op_file%" -ln "116" -nl "SD File Format is set to: "
%pycommand% "%listmanager%" -rl "%op_file%" -ln "117" -nl "Split nsp format is set to: "
REM OUTPUT ORGANIZING format
%pycommand% "%listmanager%" -rl "%op_file%" -ln "125" -nl "Output organization is set to: "

REM NSCB MODE
%pycommand% "%listmanager%" -rl "%op_file%" -ln "132" -nl "NSCB mode is set to: "

REM ROMANIZE
%pycommand% "%listmanager%" -rl "%op_file%" -ln "139" -nl "ROMANIZE option is set to: "

REM TRANSLATE
%pycommand% "%listmanager%" -rl "%op_file%" -ln "147" -nl "TRANSLATE option is set to: "

REM WORKERS
%pycommand% "%listmanager%" -rl "%op_file%" -ln "153" -nl "WORKERS option is set to: "

REM COMPRESSION
%pycommand% "%listmanager%" -rl "%op_file%" -ln "158" -nl "COMPRESSION LEVELS option is set to: "
%pycommand% "%listmanager%" -rl "%op_file%" -ln "159" -nl "COMPRESSION THREADS option is set to: "
%pycommand% "%listmanager%" -rl "%op_file%" -ln "160" -nl "COMPRESSED XCIS EXPORT option is set to: "
exit /B

:verify_keys
cls
call :logo
echo ***************************************************************************
echo 根据正确的密钥sha256散列值验证keys.txt中的密钥
echo ***************************************************************************

%pycommand% "%squirrel%" -nint_keys "%dec_keys%"

echo ...........................................................................
echo 输入"0"，返回配置菜单
echo 输入"1"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

:salida
exit /B

:update_nutdb
cls
call :logo
echo ***************************************************************************
echo 强制NUT_DB更新
echo ***************************************************************************

%pycommand% "%squirrel_lb%" -lib_call nutdb force_refresh

echo ...........................................................................
echo 输入"0"，返回配置菜单
echo 输入"1"，返回主程序
echo ...........................................................................
echo.
set /p bs="输入您的选择： "
set bs=%bs:"=%

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

:google_drive
cls
call :logo
echo ********************************************************
echo 谷歌网盘 - 配置
echo ********************************************************
echo 输入"1"，注册账户
echo 输入"2"，刷新远程库文件缓存
echo.
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo .......................................................
echo.
set /p bs="输入您的选择： "
if /i "%bs%"=="1" goto op_google_drive_account
if /i "%bs%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call workers concurrent_cache )
if /i "%bs%"=="2" goto google_drive

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida
echo 错误的选项
echo.
goto google_drive

:op_google_drive_account
cls
call :logo
echo ***************************************************************************
echo 注册谷歌网盘账户
echo ***************************************************************************
echo 您需要一个certificate.json，它可以称为certificate.json或您将生成的令牌的名称.json。
echo certificate.json可以与许多帐户一起使用以生成令牌，但是如果将其与生成该帐户的帐户使用的帐户不同，则会收到警告。
echo 系统实现为在凭据文件夹中有许多凭据json。阅读与NSCB一起分发的文档，并了解如何获取该文件。
echo.
echo 注意：您在此步骤中输入的名称将用于保存令牌和路径。
echo.
echo 示例：名为"drive"的令牌将使用drive:/folder/file.nsp之类的路径
echo.
set /p bs="输入令牌使用的完整路径: "
set "token=%bs%"
echo.
%pycommand% "%squirrel_lb%" -lib_call Drive.Private create_token -xarg "%token%" headless="False"
pause
goto google_drive

:interface
cls
call :logo
echo ********************************************************
echo 自动模式 - 配置
echo ********************************************************
echo 输入"1"，启动可视化配置
echo 输入"2"，选择浏览器来配置界面
echo 输入"3"，停用视频播放
echo 输入"4"，设置端口
echo 输入"5"，设置主机
echo 输入"6"，设置GUI控制台参数
echo.
echo 输入"d"，还原默认界面配置
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo .......................................................
echo.
set /p bs="输入您的选择： "
if /i "%bs%"=="1" goto op_interface_consolevisibility
if /i "%bs%"=="2" goto op_interface_browser
if /i "%bs%"=="3" goto op_interface_video_playback
if /i "%bs%"=="4" goto op_interface_port
if /i "%bs%"=="5" goto op_interface_host
if /i "%bs%"=="6" goto op_interface_noconsole

if /i "%bs%"=="d" goto op_interface_defaults
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida
echo 错误的选择
echo.
goto interface

:op_interface_consolevisibility
cls
call :logo
echo ***************************************************************************
echo 启动INTERFACE.BAT最小化？
echo ***************************************************************************
echo 控制调试控制台是否与Web界面一起最小化启动
echo 界面
echo.
echo 输入"1"，开始最小化
echo 输入"2"，不开始最小化
echo 输入"D"，默认（未最小化）
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回界面菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择： "
set "v_interface=none"
if /i "%bs%"=="1" set "v_interface=yes"
if /i "%bs%"=="2" set "v_interface=no"
if /i "%bs%"=="d" set "v_interface=no"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

if "%v_interface%"=="none" echo 错误的选择
if "%v_interface%"=="none" echo.
if "%v_interface%"=="none" goto op_interface_consolevisibility

set v_interface="start_minimized=%v_interface%"
set v_interface="%v_interface%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "17" -nl "set %v_interface%"
echo.
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "17" -nl "Line in config was changed to: "
echo.
pause
goto interface

:op_interface_browser
cls
call :logo
echo ***************************************************************************
echo 选择浏览器以启动界面
echo ***************************************************************************
echo 选择用于启动界面的浏览器：
echo 选项：
echo 1. 自动。顺序是在ztools\chromium或系统中安装的浏览器的基础上设置的。
echo 这是由squirrel按以下顺序自动设置的：
echo    I.   ztools\chromium（Chromium便携版或Slimjet便携版）
echo    II.  系统中安装的Chrome或Chromium
echo    III. Microsoft Edge （不推荐）
echo 2. 系统默认。使用默认系统浏览器（兼容性低）
echo 3. 通过以下方法之一将原始路径设置为纯chromium浏览器。
echo    I.   浏览器的绝对路径，以.exe结尾
echo    II.  .lnk文件的绝对路径（Windows快捷方式）
echo    III. ztools\chromium中的.lnk文件的名称（以.lnk结尾）
echo         例如: brave.lnk
echo         这将读取ztools\chromium\brave.lnk并重定向到启动brave浏览器的exe路径
echo.
echo 输入"1"或"d"，设置变量为自动
echo 输入"2"，设置变量为系统默认
echo 输入3.III方法的shortcut.lnk名称
echo 输入浏览器或3.I或3.II方法的快捷方式的绝对路径
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回界面菜单
echo 输入"e"，返回朱谌旭
echo.
set /p bs="输入您的选择： "
set "v_interface_browser=%bs%"
if /i "%bs%"=="1" set "v_interface_browser=auto"
if /i "%bs%"=="2" set "v_interface_browser=default"
if /i "%bs%"=="d" set "v_interface_browser=auto"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

set v_interface_browser="browserpath=%v_interface_browser%"
set v_interface_browser="%v_interface_browser%"

%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "31" -nl "set %v_interface_browser%"
echo.
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "31" -nl "Line in config was changed to: "
echo.
pause
goto interface

:op_interface_video_playback
cls
call :logo
echo ***************************************************************************
echo 停用视频播放
echo ***************************************************************************
echo 停用Nintendo.com视频的HLS播放器。
echo 这适用于HLS javascript播放器不能正常工作的旧计算机
echo.
echo 输入"1"，自用视频播放
echo 输入"2"，停用视频播放
echo 输入"D"，默认（不最小化）
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回界面菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择： "
set "v_video_playback=none"
if /i "%bs%"=="1" set "v_video_playback=true"
if /i "%bs%"=="2" set "v_video_playback=false"
if /i "%bs%"=="d" set "v_video_playback=false"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

if "%v_video_playback%"=="none" echo 错误的选项
if "%v_video_playback%"=="none" echo.
if "%v_video_playback%"=="none" goto op_interface_video_playback

set v_video_playback="videoplayback=%v_video_playback%"
set v_video_playback="%v_video_playback%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "35" -nl "set %v_video_playback%"
echo.
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "35" -nl "Line in config was changed to: "
echo.
pause
goto interface

:op_interface_port
cls
call :logo
echo ***************************************************************************
echo 选择界面端口
echo ***************************************************************************
echo.
echo 注意，"rg8000"指位于8000和8999之间的开放端口, 它允许同时打开多个界面窗口。这是默认参数
echo.
echo 输入"1"或"d"，设置端口变量为rg8000
echo 或输入一个端口号
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回界面菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_interface_port=%bs%"
if /i "%bs%"=="1" set "v_interface_port=rg8000"
if /i "%bs%"=="d" set "v_interface_port=rg8000"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

set v_interface_port="port=%v_interface_port%"
set v_interface_port="%v_interface_port%"

%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "48" -nl "set %v_interface_port%"
echo.
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "48" -nl "Line in config was changed to: "
echo.
pause
goto interface

:op_interface_host
cls
call :logo
echo ***************************************************************************
echo 选择界面端口
echo ***************************************************************************
echo Localhost. 界面仅在本地可见（默认）
echo 0.0.0.0. 界面可以在同一网络上可见
echo.
echo 输入"1"或"d"，设置主机为LOCALHOST
echo 输入"2"，设置主机为0.0.0.0
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回界面菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_interface_host=none"
if /i "%bs%"=="1" set "v_interface_host=localhost"
if /i "%bs%"=="2" set "v_interface_host=0.0.0.0"
if /i "%bs%"=="d" set "v_interface_host=localhost"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

if "%v_interface_host%"=="none" echo 错误的选项
if "%v_interface_host%"=="none" echo.
if "%v_interface_host%"=="none" goto op_interface_host

set v_interface_host="host=%v_interface_host%"
set v_interface_host="%v_interface_host%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "55" -nl "set %v_interface_host%"
echo.
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "55" -nl "Line in config was changed to: "
echo.
pause
goto interface

:op_interface_noconsole
cls
call :logo
echo ***************************************************************************
echo 隐藏界面的控制台
echo ***************************************************************************
echo NoConsole=True. 隐藏命令控制台并将控制台打印重定向到界面，这是默认参数。
echo NoConsole=False. 显示命令控制台
echo.
echo 输入"1"或"d"，配置NOCONSOLE为TRUE
echo 输入"2"，配置NOCONSOLE为FALSE
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回界面菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_interface_noconsole=none"
if /i "%bs%"=="1" set "v_interface_noconsole=true"
if /i "%bs%"=="2" set "v_interface_noconsole=false"
if /i "%bs%"=="d" set "v_interface_noconsole=true"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

if "%v_interface_noconsole%"=="none" echo 错误的选项
if "%v_interface_noconsole%"=="none" echo.
if "%v_interface_noconsole%"=="none" goto op_interface_noconsole

set v_interface_noconsole="noconsole=%v_interface_noconsole%"
set v_interface_noconsole="%v_interface_noconsole%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "61" -nl "set %v_interface_noconsole%"
echo.
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "61" -nl "Line in config was changed to: "
echo.
pause
goto interface

:op_interface_defaults
cls
call :logo
::启动
set v_interface="start_minimized=no"
set v_interface="%v_interface%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "17" -nl "set %v_interface%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "17" -nl "Line in config was changed to: "
echo.
::浏览器路径
set v_interface_browser="browserpath=auto"
set v_interface_browser="%v_interface_browser%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "31" -nl "set %v_interface_browser%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "31" -nl "Line in config was changed to: "
echo.
::视频播放
set v_video_playback="videoplayback=true"
set v_video_playback="%v_video_playback%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "35" -nl "set %v_video_playback%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "35" -nl "Line in config was changed to: "
::端口
set v_interface_port="port=rg8000"
set v_interface_port="%v_interface_port%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "48" -nl "set %v_interface_port%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "48" -nl "Line in config was changed to: "
::主机
set v_interface_host="host=localhost"
set v_interface_host="%v_interface_host%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "55" -nl "set %v_interface_host%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "55" -nl "Line in config was changed to: "

::GUI控制台
set v_interface_noconsole="noconsole=true"
set v_interface_noconsole="%v_interface_noconsole%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "61" -nl "set %v_interface_noconsole%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "61" -nl "Line in config was changed to: "
pause
goto sc1

:server
cls
call :logo
echo ********************************************************
echo 服务器 - 配置
echo ********************************************************
echo 输入"1"，修改启动可视化配置
echo 输入"2"，禁止视频播放
echo 输入"3"，设置端口号
echo 输入"4"，设置主机
echo 输入"5"，设置GUI控制台参数
echo 输入"6"，设置SSL参数
echo.
echo 输入"d"，恢复服务器默认配置
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo .......................................................
echo.
set /p bs="输入您的选择："
if /i "%bs%"=="1" goto op_server_consolevisibility
if /i "%bs%"=="2" goto op_server_video_playback
if /i "%bs%"=="3" goto op_server_port
if /i "%bs%"=="4" goto op_server_host
if /i "%bs%"=="5" goto op_server_noconsole
if /i "%bs%"=="6" goto op_server_ssl

if /i "%bs%"=="d" goto op_server_defaults
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida
echo 错误的选项
echo.
goto server

:op_server_consolevisibility
cls
call :logo
echo ***************************************************************************
echo 启动SERVER.BAT最小化?
echo ***************************************************************************
echo 控制调试控制台是否与Web界面一起最小化启动
echo.
echo 输入"1"，最小化启动
echo 输入"2"，正常启动
echo 输入"d"，默认（非最小化启动）
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回服务器菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_server_vis=none"
if /i "%bs%"=="1" set "v_server_vis=yes"
if /i "%bs%"=="2" set "v_server_vis=no"
if /i "%bs%"=="d" set "v_server_vis=no"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_server_vis%"=="none" echo 错误的选项
if "%v_server_vis%"=="none" echo.
if "%v_server_vis%"=="none" goto op_server_consolevisibility

set v_server_vis="start_minimized=%v_server_vis%"
set v_server_vis="%v_server_vis%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "17" -nl "set %v_server_vis%"
echo.
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "17" -nl "Line in config was changed to: "
echo.
pause
goto server

:op_server_video_playback
cls
call :logo
echo ***************************************************************************
echo 禁用视频播放
echo ***************************************************************************
echo 禁用HLS播放器播放Nintendo.com视频。
echo 这适用于可能会因HLS javascript播放器卡住的旧计算机
echo.
echo 输入"1"，启用视频播放
echo 输入"2"，禁用视频播放
echo 输入"d"，默认（启用）
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回服务器菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_video_playback=none"
if /i "%bs%"=="1" set "v_video_playback=true"
if /i "%bs%"=="2" set "v_video_playback=false"
if /i "%bs%"=="d" set "v_video_playback=false"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_video_playback%"=="none" echo 错误的选项
if "%v_video_playback%"=="none" echo.
if "%v_video_playback%"=="none" goto op_server_video_playback

set v_video_playback="videoplayback=%v_video_playback%"
set v_video_playback="%v_video_playback%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "21" -nl "set %v_video_playback%"
echo.
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "21" -nl "Line in config was changed to: "
echo.
pause
goto server

:op_server_port
cls
call :logo
echo ***************************************************************************
echo 选择服务器端口
echo ***************************************************************************
echo.
echo 注意：“rg8000”位于8000和8999之间的开放端口上，它允许同时打开多个接口窗口。这是默认参数。
echo.
echo 输入"1"或"d"，设置变量为rg8000
echo 或者输入一个端口号
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回服务器菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_server_port=%bs%"
if /i "%bs%"=="1" set "v_server_port=rg8000"
if /i "%bs%"=="d" set "v_server_port=rg8000"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

set v_server_port="port=%v_server_port%"
set v_server_port="%v_server_port%"

%pycommand% "%listmanager%" -cl "%opt_server%" -ln "29" -nl "set %v_server_port%"
echo.
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "29" -nl "Line in config was changed to: "
echo.
pause
goto server

:op_server_host
cls
call :logo
echo ***************************************************************************
echo 配置界面主机
echo ***************************************************************************
echo Localhost. 服务器仅在本地可见（默认）
echo 0.0.0.0. 界面可以在同一网络上可见
echo.
echo 输入"1"或"d"，设置主机为LOCALHOST
echo 输入"2"，设置主机为0.0.0.0
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回服务器菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_server_host=none"
if /i "%bs%"=="1" set "v_server_host=localhost"
if /i "%bs%"=="2" set "v_server_host=0.0.0.0"
if /i "%bs%"=="d" set "v_server_host=localhost"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_server_host%"=="none" echo 错误的选项
if "%v_server_host%"=="none" echo.
if "%v_server_host%"=="none" goto op_server_host

set v_server_host="host=%v_server_host%"
set v_server_host="%v_server_host%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "36" -nl "set %v_server_host%"
echo.
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "36" -nl "Line in config was changed to: "
echo.
pause
goto server

:op_server_noconsole
cls
call :logo
echo ***************************************************************************
echo 隐藏服务器的控制台
echo ***************************************************************************
echo NoConsole=True. 隐藏命令控制台并将控制台打印重定向到服务器，这是默认参数。
echo NoConsole=False. 显示命令控制台
echo.
echo 输入"1"或"d"，设置NOCONSOLE为TRUE
echo 输入"2"，设置NOCONSOLE为FALSE
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回服务器菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_server_noconsole=none"
if /i "%bs%"=="1" set "v_server_noconsole=true"
if /i "%bs%"=="2" set "v_server_noconsole=false"
if /i "%bs%"=="d" set "v_server_noconsole=true"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_server_noconsole%"=="none" echo 错误的选项
if "%v_server_noconsole%"=="none" echo.
if "%v_server_noconsole%"=="none" goto op_server_noconsole

set v_server_noconsole="noconsole=%v_server_noconsole%"
set v_server_noconsole="%v_server_noconsole%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "42" -nl "set %v_server_noconsole%"
echo.
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "42" -nl "Line in config was changed to: "
echo.
pause
goto server

:op_server_ssl
cls
call :logo
echo ***************************************************************************
echo SSL协议
echo ***************************************************************************
echo 如果为true，则服务器将使用https协议；
echo 如果zconfig中存在正确签名的certificate.pem和key.pem文件，则可以使用该服务器。
echo 如果找不到这些文件，squirrel将回退到http。
echo.
echo 输入"1"或"D"，设置SSL为OFF（默认）
echo 输入"2"，设置SSL为ON
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回服务器菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_server_SSL=none"
if /i "%bs%"=="1" set "v_server_SSL=false"
if /i "%bs%"=="2" set "v_server_SSL=true"
if /i "%bs%"=="d" set "v_server_SSL=false"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_server_SSL%"=="none" echo 错误的选项
if "%v_server_SSL%"=="none" echo.
if "%v_server_SSL%"=="none" goto op_server_ssl

set v_server_SSL="ssl=%v_server_SSL%"
set v_server_SSL="%v_server_SSL%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "48" -nl "set %v_server_SSL%"
echo.
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "48" -nl "Line in config was changed to: "
echo.
pause
goto server

:op_server_defaults
cls
call :logo
::启动
set v_interface="start_minimized=no"
set v_interface="%v_interface%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "17" -nl "set %v_interface%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "17" -nl "Line in config was changed to: "
echo.
::视频播放
set v_video_playback="videoplayback=true"
set v_video_playback="%v_video_playback%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "21" -nl "set %v_video_playback%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "21" -nl "Line in config was changed to: "
::端口
set v_interface_port="port=rg8000"
set v_interface_port="%v_interface_port%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "29" -nl "set %v_interface_port%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "29" -nl "Line in config was changed to: "
::主机
set v_interface_host="host=localhost"
set v_interface_host="%v_interface_host%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "36" -nl "set %v_interface_host%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "36" -nl "Line in config was changed to: "
::GUI控制台
set v_interface_noconsole="noconsole=true"
set v_interface_noconsole="%v_interface_noconsole%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "42" -nl "set %v_interface_noconsole%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "42" -nl "Line in config was changed to: "
::SSL
set v_server_SSL="ssl=false"
set v_server_SSL="%v_server_SSL%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "48" -nl "set %v_server_SSL%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "48" -nl "Line in config was changed to: "

pause
goto sc1

:MTP
cls
call :logo
echo ********************************************************
echo MTP - 配置
echo ********************************************************
echo 输入"1"，为预装设置校验
echo 输入"2"，自动更新设备时优先选择NSZ
echo 输入"3"，激活标准加密安装
echo 输入"4"，在自动更新中安装更新时排除XCI
echo 输入"5"，SD和EMMC之间的切换取决于可用空间
echo 输入"6"，安装前检查控制台上的固件
echo 输入"7"，必要时修补文件的密钥生成
echo 输入"8"，请在安装前检查是否已安装基本内容
echo 输入"9"，在安装前检查是否安装了旧的更新或DLC
echo 输入"10"，在转储时选择文件夹设置
echo 输入"11"，在转储存档时，选择是否添加titleid和版本信息
echo 输入"12"，选择如何将文件添加到公共链接的远程高速缓存
echo 输入"13"，更改补丁文件和XCI安装规范
echo.
echo 输入"d"，恢复MTP默认配置
echo 输入"0"，返回配置菜单
echo 输入"e"，返回主程序
echo .......................................................
echo.
set /p bs="输入您的选择："
if /i "%bs%"=="1" goto op_MTP_verification
if /i "%bs%"=="2" goto op_MTP_prioritize_NSZ
if /i "%bs%"=="3" goto op_MTP_standard_crypto
if /i "%bs%"=="4" goto op_MTP_exclude_xci_autinst
if /i "%bs%"=="5" goto op_MTP_aut_ch_medium
if /i "%bs%"=="6" goto op_MTP_chk_fw
if /i "%bs%"=="7" goto op_MTP_prepatch_kg
if /i "%bs%"=="8" goto op_MTP_prechk_Base
if /i "%bs%"=="9" goto op_MTP_prechk_Upd
if /i "%bs%"=="10" goto op_MTP_saves_Inline
if /i "%bs%"=="11" goto op_MTP_saves_AddTIDandVer
if /i "%bs%"=="12" goto op_MTP_pdrive_truecopy
if /i "%bs%"=="13" goto op_MTP_ptch_install_spec

if /i "%bs%"=="d" goto op_mtp_defaults
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida
echo 错误的选项
echo.
goto MTP

:op_MTP_verification
cls
call :logo
echo ***************************************************************************
echo 激活文件校验预安装
echo ***************************************************************************
echo False: 禁用校验
echo Level 2 verification: NCA可读，没有文件丢失，titlekey是正确的，并且签名1来自合法可验证的来源。（默认）
echo Hash: Level 2验证 + Hash验证
echo.
echo 输入"1"或"D"，设置VERIFICATION为LEVEL2
echo 输入"2"，设置VERIFICATION为HASH
echo 输入"3"，禁用校验
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_mtp_verification=none"
if /i "%bs%"=="1" set "v_mtp_verification=True"
if /i "%bs%"=="2" set "v_mtp_verification=Hash"
if /i "%bs%"=="3" set "v_mtp_verification=False"
if /i "%bs%"=="d" set "v_mtp_verification=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_mtp_verification%"=="none" echo 错误的选项
if "%v_mtp_verification%"=="none" echo.
if "%v_mtp_verification%"=="none" goto op_MTP_verification

set v_mtp_verification="MTP_verification=%v_mtp_verification%"
set v_mtp_verification="%v_mtp_verification%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "166" -nl "set %v_mtp_verification%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "166" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_prioritize_NSZ
cls
call :logo
echo ***************************************************************************
echo 在检查库中的新更新和DLC时，将选择NSZ优先于NSP
echo ***************************************************************************
echo.
echo 输入"1"或"D"，优先选择NSZ
echo 输入"2"，不优先选择NSZ
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_prioritize_NSZ=none"
if /i "%bs%"=="1" set "v_MTP_prioritize_NSZ=True"
if /i "%bs%"=="3" set "v_MTP_prioritize_NSZ=False"
if /i "%bs%"=="d" set "v_MTP_prioritize_NSZ=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_prioritize_NSZ%"=="none" echo 错误的选择
if "%v_MTP_prioritize_NSZ%"=="none" echo.
if "%v_MTP_prioritize_NSZ%"=="none" goto op_MTP_prioritize_NSZ

set v_MTP_prioritize_NSZ="MTP_prioritize_NSZ=%v_MTP_prioritize_NSZ%"
set v_MTP_prioritize_NSZ="%v_MTP_prioritize_NSZ%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "167" -nl "set %v_MTP_prioritize_NSZ%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "167" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_exclude_xci_autinst
cls
call :logo
echo ***************************************************************************
echo 从自动更新检查中排除XCI以获取新内容
echo ***************************************************************************
echo.
echo 输入"1"或"D"，从自动更新检查中排除XCI
echo 输入"2"，不从自动更新检查中排除XCI
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_exclude_xci_autinst=none"
if /i "%bs%"=="1" set "v_MTP_exclude_xci_autinst=True"
if /i "%bs%"=="2" set "v_MTP_exclude_xci_autinst=False"
if /i "%bs%"=="d" set "v_MTP_exclude_xci_autinst=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_exclude_xci_autinst%"=="none" echo 错误的选项
if "%v_MTP_exclude_xci_autinst%"=="none" echo.
if "%v_MTP_exclude_xci_autinst%"=="none" goto op_MTP_exclude_xci_autinst

set v_MTP_exclude_xci_autinst="MTP_exclude_xci_autinst=%v_MTP_exclude_xci_autinst%"
set v_MTP_exclude_xci_autinst="%v_MTP_exclude_xci_autinst%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "168" -nl "set %v_MTP_exclude_xci_autinst%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "168" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_aut_ch_medium
cls
call :logo
echo ***************************************************************************
echo 根据设备上的空间自动更改介质
echo ***************************************************************************
echo 当所选介质中的空间不足时，如果SD和EMMC之间为true，则更改。如果为false，则跳过安装。
echo.
echo 输入"1"或"D"，根据设备上的空间更改介质
echo 输入"2"，不根据设备上的空间更改介质
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_aut_ch_medium=none"
if /i "%bs%"=="1" set "v_MTP_aut_ch_medium=True"
if /i "%bs%"=="2" set "v_MTP_aut_ch_medium=False"
if /i "%bs%"=="d" set "v_MTP_aut_ch_medium=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_aut_ch_medium%"=="none" echo 错误的选项
if "%v_MTP_aut_ch_medium%"=="none" echo.
if "%v_MTP_aut_ch_medium%"=="none" goto op_MTP_aut_ch_medium

set v_MTP_aut_ch_medium="MTP_aut_ch_medium=%v_MTP_aut_ch_medium%"
set v_MTP_aut_ch_medium="%v_MTP_aut_ch_medium%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "169" -nl "set %v_MTP_aut_ch_medium%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "169" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_chk_fw
cls
call :logo
echo ***************************************************************************
echo 检查设备上和文件上的固件
echo ***************************************************************************
echo.
echo 输入"1"或"D"，不检查固件（默认）
echo 输入"2"，检查固件
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_chk_fw=none"
if /i "%bs%"=="1" set "v_MTP_chk_fw=False"
if /i "%bs%"=="2" set "v_MTP_chk_fw=True"
if /i "%bs%"=="d" set "v_MTP_chk_fw=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_chk_fw%"=="none" echo 错误的选项
if "%v_MTP_chk_fw%"=="none" echo.
if "%v_MTP_chk_fw%"=="none" goto op_MTP_chk_fw

set v_MTP_chk_fw="MTP_chk_fw=%v_MTP_chk_fw%"
set v_MTP_chk_fw="%v_MTP_chk_fw%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "170" -nl "set %v_MTP_chk_fw%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "170" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_prepatch_kg
cls
call :logo
echo ***************************************************************************
echo 检查设备上和文件上的固件
echo ***************************************************************************
echo 在控制台上检查固件和文件后，hte程序将基于此选项决定是否应修补或跳过文件。
echo 注意：目前，在通过MTP推送文件之前，需要先生成一个新文件，因为尚未在mtp挂钩上实现动态修补流的功能。
echo.
echo 输入"1"或"D"，不对文件打补丁（默认）
echo 输入"2"，对文件打补丁
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_prepatch_kg=none"
if /i "%bs%"=="1" set "v_MTP_prepatch_kg=False"
if /i "%bs%"=="2" set "v_MTP_prepatch_kg=True"
if /i "%bs%"=="d" set "v_MTP_prepatch_kg=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_prepatch_kg%"=="none" echo 错误的选项
if "%v_MTP_prepatch_kg%"=="none" echo.
if "%v_MTP_prepatch_kg%"=="none" goto op_MTP_prepatch_kg

set v_MTP_prepatch_kg="MTP_chk_fw=%v_MTP_prepatch_kg%"
set v_MTP_prepatch_kg="%v_MTP_prepatch_kg%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "171" -nl "set %v_MTP_prepatch_kg%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "171" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_prechk_Base
cls
call :logo
echo ***************************************************************************
echo 检查是否已在设备中安装基本游戏
echo ***************************************************************************
echo 如果设备中装有基本游戏，则如果激活，将跳过安装。如果取消激活，安装将被覆盖。
echo.
echo 输入"1"或"D"，已安装检查和跳过游戏（默认）
echo 输入"2"，不检查并跳过已安装的游戏
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_prechk_Base=none"
if /i "%bs%"=="1" set "v_MTP_prechk_Base=True"
if /i "%bs%"=="2" set "v_MTP_prechk_Base=False"
if /i "%bs%"=="d" set "v_MTP_prechk_Base=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_prechk_Base%"=="none" echo 错误的选项
if "%v_MTP_prechk_Base%"=="none" echo.
if "%v_MTP_prechk_Base%"=="none" goto op_MTP_prechk_Base

set v_MTP_prechk_Base="MTP_prechk_Base=%v_MTP_prechk_Base%"
set v_MTP_prechk_Base="%v_MTP_prechk_Base%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "173" -nl "set %v_MTP_prechk_Base%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "173" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_prechk_Upd
cls
call :logo
echo ***************************************************************************
echo 检查更新是否已安装在设备中
echo ***************************************************************************
echo 如果激活该选项，则检查设备中是否存在更新或dlc（如果版本低于发行版本），
echo 则删除旧的预安装以在安装过程之前回收空间（如果设备中的版本等于或更高，则跳过）。
echo 如果停用，则允许安装订单更新或dlc以及覆盖具有相同版本号的更新。
echo.
echo 输入"1"或"D"，不检查和跳过更新或已经安装的dlc（默认）
echo 输入"2"，检查和跳过更新或已经安装的dlc
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_prechk_Upd=none"
if /i "%bs%"=="1" set "v_MTP_prechk_Upd=False"
if /i "%bs%"=="2" set "v_MTP_prechk_Upd=True"
if /i "%bs%"=="d" set "v_MTP_prechk_Upd=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_prechk_Upd%"=="none" echo 错误的选项
if "%v_MTP_prechk_Upd%"=="none" echo.
if "%v_MTP_prechk_Upd%"=="none" goto op_MTP_prechk_Upd

set v_MTP_prechk_Upd="MTP_prechk_Upd=%v_MTP_prechk_Upd%"
set v_MTP_prechk_Upd="%v_MTP_prechk_Upd%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "174" -nl "set %v_MTP_prechk_Upd%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "174" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_saves_Inline
cls
call :logo
echo ***************************************************************************
echo 在文件夹或直接保存游戏转储
echo ***************************************************************************
echo.
echo 输入"1"或"D"，将游戏保存在文件夹中（默认）
echo 输入"2"，直接保存游戏
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_saves_Inline=none"
if /i "%bs%"=="1" set "v_MTP_saves_Inline=False"
if /i "%bs%"=="2" set "v_MTP_saves_Inline=True"
if /i "%bs%"=="d" set "v_MTP_saves_Inline=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_saves_Inline%"=="none" echo 错误的选择
if "%v_MTP_saves_Inline%"=="none" echo.
if "%v_MTP_saves_Inline%"=="none" goto op_MTP_saves_Inline

set v_MTP_saves_Inline="MTP_saves_Inline=%v_MTP_saves_Inline%"
set v_MTP_saves_Inline="%v_MTP_saves_Inline%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "176" -nl "set %v_MTP_saves_Inline%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "176" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_saves_AddTIDandVer
cls
call :logo
echo ***************************************************************************
echo 添加标题和版本标签以保存游戏
echo ***************************************************************************
echo 这是为了在进行保存时知道设备上的游戏版本，以避免兼容性问题。
echo.
echo 输入"1"或"D"，将titleid和版本标签添加到文件中（默认）
echo 输入"2"，不将titleid和版本标签添加到文件中
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_saves_AddTIDandVer=none"
if /i "%bs%"=="1" set "v_MTP_saves_AddTIDandVer=False"
if /i "%bs%"=="2" set "v_MTP_saves_AddTIDandVer=True"
if /i "%bs%"=="d" set "v_MTP_saves_AddTIDandVer=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_saves_AddTIDandVer%"=="none" echo 错误的选项
if "%v_MTP_saves_AddTIDandVer%"=="none" echo.
if "%v_MTP_saves_AddTIDandVer%"=="none" goto op_MTP_saves_AddTIDandVer

set v_MTP_saves_AddTIDandVer="MTP_saves_AddTIDandVer=%v_MTP_saves_AddTIDandVer%"
set v_MTP_saves_AddTIDandVer="%v_MTP_saves_AddTIDandVer%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "177" -nl "set %v_MTP_saves_AddTIDandVer%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "177" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_pdrive_truecopy
cls
call :logo
echo ***************************************************************************
echo 添加标题和版本标签以保存游戏
echo ***************************************************************************
echo 从Google云端硬盘公共链接安装或转移游戏时，NSCB需要在Google云端硬盘帐户中设置令牌身份验证和缓存文件夹设置，以实现更好的兼容性。
echo.
echo 复制游戏以获得所有权到缓存文件夹，如果启用了TRUECOPY，也可以避免配额问题。
echo 如果禁用TRUECOPY，则将游戏作为符号链接添加到缓存文件夹中，这将允许使用auth令牌调用文件，但是如果共享链接，则会出现配额问题。
echo.
echo 输入"1"或"D"，激活TRUECOPY（默认）
echo 输入"2"，禁用TRUECOPY
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP配置
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_op_MTP_pdrive_truecopy=none"
if /i "%bs%"=="1" set "v_op_MTP_pdrive_truecopy=True"
if /i "%bs%"=="2" set "v_op_MTP_pdrive_truecopy=False"
if /i "%bs%"=="d" set "v_op_MTP_pdrive_truecopy=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_op_MTP_pdrive_truecopy%"=="none" echo 错误的选项
if "%v_op_MTP_pdrive_truecopy%"=="none" echo.
if "%v_op_MTP_pdrive_truecopy%"=="none" goto op_MTP_pdrive_truecopy

set v_op_MTP_pdrive_truecopy="MTP_pdrive_truecopy=%v_op_MTP_pdrive_truecopy%"
set v_op_MTP_pdrive_truecopy="%v_op_MTP_pdrive_truecopy%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "179" -nl "set %v_op_MTP_pdrive_truecopy%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "179" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_standard_crypto
cls
call :logo
echo ***************************************************************************
echo 以标准加密方式安装所有NSP文件
echo ***************************************************************************
echo 这意味着将安装没有票证和冠名权的NSP文件，以使控制台中的票证保持干净。
echo.
echo 输入"1"或"D"，用冠名权安装（默认）
echo 输入"2"，以标准加密方式安装
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_standard_crypto=none"
if /i "%bs%"=="1" set "v_MTP_standard_crypto=False"
if /i "%bs%"=="2" set "v_MTP_standard_crypto=True"
if /i "%bs%"=="d" set "v_MTP_standard_crypto=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_standard_crypto%"=="none" echo WRONG CHOICE
if "%v_MTP_standard_crypto%"=="none" echo.
if "%v_MTP_standard_crypto%"=="none" goto op_MTP_standard_crypto

set v_MTP_standard_crypto="MTP_stc_installs=%v_MTP_standard_crypto%"
set v_MTP_standard_crypto="%v_MTP_standard_crypto%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "181" -nl "set %v_MTP_standard_crypto%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "181" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_MTP_ptch_install_spec
cls
call :logo
echo ***************************************************************************
echo 修补NSP和XCI的安装规范
echo ***************************************************************************
echo 旧版将创建修补文件或转换后的文件，然后将其传输到控制台。
echo Spec1创建一个补丁来动态修补流。Spec1将多文件视为触发多个连续安装的不同文件。
echo.
echo 输入"1"或"D"，使用SPECIFICATION1（默认）
echo 输入"2"，使用传统规范
echo.
echo 输入"0"，返回配置菜单
echo 输入"b"，返回MTP菜单
echo 输入"e"，返回主程序
echo.
set /p bs="输入您的选择："
set "v_MTP_ptch_install_spec=none"
if /i "%bs%"=="1" set "v_MTP_ptch_install_spec=spec1"
if /i "%bs%"=="2" set "v_MTP_ptch_install_spec=legacy"
if /i "%bs%"=="d" set "v_MTP_ptch_install_spec=spec1"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_ptch_install_spec%"=="none" echo WRONG CHOICE
if "%v_MTP_ptch_install_spec%"=="none" echo.
if "%v_MTP_ptch_install_spec%"=="none" goto op_MTP_ptch_install_spec

set v_MTP_ptch_install_spec="MTP_ptch_inst_spec=%v_MTP_ptch_install_spec%"
set v_MTP_ptch_install_spec="%v_MTP_ptch_install_spec%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "182" -nl "set %v_MTP_ptch_install_spec%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "182" -nl "Line in config was changed to: "
echo.
pause
goto MTP

:op_mtp_defaults
cls
call :logo
::MTP_verification
set v_mtp_verification="MTP_verification=True"
set v_mtp_verification="%v_mtp_verification%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "166" -nl "set %v_mtp_verification%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "166" -nl "Line in config was changed to: "
::MTP_prioritize_NSZ
set v_MTP_prioritize_NSZ="MTP_prioritize_NSZ=True"
set v_MTP_prioritize_NSZ="%v_MTP_prioritize_NSZ%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "167" -nl "set %v_MTP_prioritize_NSZ%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "167" -nl "Line in config was changed to: "
::MTP_exclude_xci_autinst
set v_MTP_exclude_xci_autinst="MTP_exclude_xci_autinst=True"
set v_MTP_exclude_xci_autinst="%v_MTP_exclude_xci_autinst%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "168" -nl "set %v_MTP_exclude_xci_autinst%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "168" -nl "Line in config was changed to: "
::MTP_aut_ch_medium
set v_MTP_aut_ch_medium="MTP_aut_ch_medium=True"
set v_MTP_aut_ch_medium="%v_MTP_aut_ch_medium%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "169" -nl "set %v_MTP_aut_ch_medium%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "169" -nl "Line in config was changed to: "
::MTP_chk_fw
set v_MTP_chk_fw="MTP_chk_fw=False"
set v_MTP_chk_fw="%v_MTP_chk_fw%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "170" -nl "set %v_MTP_chk_fw%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "170" -nl "Line in config was changed to: "
::MTP_prepatch_kg
set v_MTP_prepatch_kg="MTP_chk_fw=False"
set v_MTP_prepatch_kg="%v_MTP_prepatch_kg%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "171" -nl "set %v_MTP_prepatch_kg%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "171" -nl "Line in config was changed to: "
::MTP_prechk_Base
set v_MTP_prechk_Base="MTP_prechk_Base=True"
set v_MTP_prechk_Base="%v_MTP_prechk_Base%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "173" -nl "set %v_MTP_prechk_Base%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "173" -nl "Line in config was changed to: "
::MTP_prechk_Upd
set v_MTP_prechk_Upd="MTP_prechk_Upd=False"
set v_MTP_prechk_Upd="%v_MTP_prechk_Upd%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "174" -nl "set %v_MTP_prechk_Upd%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "174" -nl "Line in config was changed to: "
::MTP_saves_Inline
set v_MTP_saves_Inline="MTP_saves_Inline=False"
set v_MTP_saves_Inline="%v_MTP_saves_Inline%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "176" -nl "set %v_MTP_saves_Inline%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "176" -nl "Line in config was changed to: "
::MTP_saves_AddTIDandVer
set v_MTP_saves_AddTIDandVer="MTP_saves_AddTIDandVer=False"
set v_MTP_saves_AddTIDandVer="%v_MTP_saves_AddTIDandVer%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "177" -nl "set %v_MTP_saves_AddTIDandVer%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "177" -nl "Line in config was changed to: "
::MTP_pdrive_truecopy
set v_op_MTP_pdrive_truecopy="MTP_pdrive_truecopy=True"
set v_op_MTP_pdrive_truecopy="%v_op_MTP_pdrive_truecopy%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "179" -nl "set %v_op_MTP_pdrive_truecopy%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "179" -nl "Line in config was changed to: "
::MTP_standard_crypto
set v_MTP_standard_crypto="MTP_stc_installs=False"
set v_MTP_standard_crypto="%v_MTP_standard_crypto%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "181" -nl "set %v_MTP_standard_crypto%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "181" -nl "Line in config was changed to: "
::MTP_ptch_install_spec
set v_MTP_ptch_install_spec="MTP_ptch_inst_spec=spec1"
set v_MTP_ptch_install_spec="%v_MTP_ptch_install_spec%"
%pycommand% "%listmanager%" -cl "%op_file%" -ln "182" -nl "set %v_MTP_ptch_install_spec%"
%pycommand% "%listmanager%" -rl "%op_file%" -ln "182" -nl "Line in config was changed to: "
pause
goto sc1

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
ECHO "                    BASED IN THE WORK OF BLAWAR AND LUCA FRAGA                     "
ECHO                                    VERSION 1.01
ECHO -------------------------------------------------------------------------------------
ECHO Program's github: https://github.com/julesontheroad/NSC_BUILDER
ECHO Blawar's github:  https://github.com/blawar
ECHO Luca Fraga's github: https://github.com/LucaFraga
ECHO -------------------------------------------------------------------------------------
exit /B

:idepend
cls
call :logo
call "%batdepend%"
goto sc1
