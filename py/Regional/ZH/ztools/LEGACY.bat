echo 自动模式。单文件打包已设置
::NSP文件
::XCI文件
echo 从XCI提取安全分区
ECHO *********** 所有文件都已处理！ *************
echo 自动模式。多文件处理已设置
::NSP文件
::XCI文件
echo 从XCI提取安全分区
ECHO *********** 所有文件都已处理！ *************
echo 未拖动有效文件。程序只接受XCI或NSP文件。
echo 您将被重定向到手动模式。
echo 从XCI提取安全分区
if /i "%va_exit%"=="true" echo  程序将立即关闭
echo 输入"0"，进入模式选择
echo 输入"1"，退出程序
set /p bs="输入您的选择： "
echo 您已进入手动模式
echo 输入"1"，单文件处理 (legacy)
echo 输入"2"，多文件处理 (legacy)
echo 输入"3"，拆分模式 (legacy)
echo 输入"4"，更新模式 (legacy)
echo 输入"5"，文件信息
echo 输入"6"，数据构建
echo 输入"0"，配置选项
echo 输入"N"，进入新模式
echo 输入"M"，进入MTP模式
echo 输入"D"，进入谷歌网盘模式
echo 输入"L"，进入传统模式
set /p bs="输入您的选择： "
REM 启动手动模式。独立处理
echo 单文件处理已激活
ECHO 发现了以前的列表, 你想做什么？
echo 输入"1"，从上一列表自动开始处理
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo 注意：输入3，在开始处理文件之前，您将看到上一个列表，并且您可
echo 以从列表中添加和删除项目。
echo 或输入"0"，返回模式选择菜单
set /p bs="输入您的选择： "
echo 错误的选项
echo 单文件处理已激活
echo 你已经开始一个新的列表
echo 输入"0"返回模式选择菜单
set /p bs="请将文件或文件夹拖到窗口上，然后按回车键： "
echo 你想做什么？
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo 输入"1"，开始处理
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo 或输入"0"，返回模式选择菜单
set /p bs="拖放文件/文件夹或设置选项： "
set /p bs="输入要删除的文件数（从底部开始）： "
echo 单文件处理已激活
ECHO                 要处理的文件
echo 你加了 !conta! 个要处理的文件
echo 错误的选项
echo 接下来选择您要执行的操作
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为XCI
echo 输入"3"，全部都要
echo 或输入"b"，返回列表选项
set /p bs="输入您的选择： "
echo 是否要魔改所需的系统版本
echo 如果你选择魔改，它将被设置为与nca加密匹配，因此它只会在必要的
echo 情况下要求更新你的系统。
echo 输入"0"，不魔改
echo 输入"1"，魔改
echo 或输入"b"，返回列表选项
set /p bs="输入您的选择： "
if /i "%patchRSV%"=="none" echo 错误的选项
echo 设置魔改系统最大版本号
echo 根据您的选择，如果读取密钥生成值大于程序中指定的值，则密钥生
echo 成和RSV将降低到相应的密钥生成范围。
echo 这并不总能降低系统要求。
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
echo 输入"12"，魔改版本FW 12.1.0
echo 输入"13"，魔改版本FW 13.0.0-13.2.1
echo 输入"14"，魔改版本FW 14.0.0-14.1.2
echo 输入"15"，魔改版本FW 15.0.0-15.0.1
echo 输入"16"，魔改版本FW 16.0.0-16.1.0
echo 输入"17"，魔改版本FW 17.0.0-17.0.1
echo 输入"18"，魔改版本FW 18.0.0-18.1.0
echo 输入"19"，魔改版本FW 19.0.0-
echo 或输入"b"，返回列表选项
set /p bs="输入您的选择： "
if /i "%bs%"=="14" set "vkey=-kp 14"
if /i "%bs%"=="14" set "capRSV=--RSVcap 939524096"
if /i "%bs%"=="15" set "vkey=-kp 15"
if /i "%bs%"=="15" set "capRSV=--RSVcap 1006632960"
if /i "%bs%"=="16" set "vkey=-kp 16"
if /i "%bs%"=="16" set "capRSV=--RSVcap 1073741824"
if /i "%bs%"=="17" set "vkey=-kp 17"
if /i "%bs%"=="17" set "capRSV=--RSVcap 1140850688"
if /i "%bs%"=="18" set "vkey=-kp 18"
if /i "%bs%"=="18" set "capRSV=--RSVcap 1207959552"
if /i "%bs%"=="19" set "vkey=-kp 19"
if /i "%bs%"=="19" set "capRSV=--RSVcap 1275068416"
if /i "%vkey%"=="none" echo 错误的选项
ECHO *********** 所有文件都已处理！ *************
if /i "%va_exit%"=="true" echo  程序将立即关闭
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
set /p bs="输入您的选择： "
::XCI文件
echo 从XCI提取安全分区
echo 仍然有 !conta! 个要处理的文件
:: 多文件模式
echo 多文件处理已激活
ECHO 发现了以前的列表, 你想做什么？
echo 输入"1"，从上一列表自动开始处理
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo 注意：输入3，您将在开始处理文件之前看到上一个列表，并且您可以
echo 添加和删除列表中的项目。
echo 或输入"0"，返回模式选择菜单
set /p bs="输入您的选择： "
echo 错误的选项
echo 多文件处理已激活
echo 你已经开始一个新的列表
echo 输入"0"，返回模式选择菜单
set /p bs="请将文件或文件夹拖到窗口上，然后按回车键： "
echo 你想做什么？
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo 输入"1"，开始处理
echo 输入"2"，从NSP或NCA中提取并设置自定义图标
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo 或输入"0"，返回模式选择菜单
set /p bs="拖放文件/文件夹或设置选项： "
set /p bs="输入要删除的文件数（从底部开始）： "
echo 多文件处理已激活
ECHO                要处理的文件
echo 你加了 !conta! 个要处理的文件
echo 错误的选项
echo 接下来选择您要执行的操作
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为xci
echo 输入"3"，打包为NSP和XCI
echo 或输入"b"，返回选项列表
set /p bs="输入您的选择： "
echo 是否要魔改所需的系统版本
echo 如果你选择魔改，它将被设置为与nca加密匹配，因此它只会在必要的情况下要求更新你的系统。
echo 的情况下要求更新你的系统。
echo 输入"0"，不魔改
echo 输入"1"，魔改
echo 或输入"b"，返回选项列表
set /p bs="输入您的选择： "
if /i "%patchRSV%"=="none" echo 错误的选项
echo 设置魔改允许的最大版本号
echo 根据您的选择，如果读取密钥生成值大于程序中指定的值，则密钥生成和RSV将降低到相应的密钥生成范围。
echo 成和RSV将降低到相应的密钥生成范围。
echo 这并不总能降低系统要求。
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
echo 输入"12"，魔改版本FW 12.1.0
echo 输入"13"，魔改版本FW 13.0.0-13.2.1
echo 输入"14"，魔改版本FW 14.0.0-14.1.2
echo 输入"15"，魔改版本FW 15.0.0-15.0.1
echo 输入"16"，魔改版本FW 16.0.0-16.1.0
echo 输入"17"，魔改版本FW 17.0.0-17.0.1
echo 输入"18"，魔改版本FW 18.0.0-18.1.0
echo 输入"19"，魔改版本FW 19.0.0-
echo 或输入"b"，返回选项列表
set /p bs="输入您的选择： "
if /i "%bs%"=="14" set "vkey=-kp 14"
if /i "%bs%"=="14" set "capRSV=--RSVcap 939524096"
if /i "%bs%"=="15" set "vkey=-kp 15"
if /i "%bs%"=="15" set "capRSV=--RSVcap 1006632960"
if /i "%bs%"=="16" set "vkey=-kp 16"
if /i "%bs%"=="16" set "capRSV=--RSVcap 1073741824"
if /i "%bs%"=="17" set "vkey=-kp 17"
if /i "%bs%"=="17" set "capRSV=--RSVcap 1140850688"
if /i "%bs%"=="18" set "vkey=-kp 18"
if /i "%bs%"=="18" set "capRSV=--RSVcap 1207959552"
if /i "%bs%"=="19" set "vkey=-kp 19"
if /i "%bs%"=="19" set "capRSV=--RSVcap 1275068416"
if /i "%vkey%"=="none" echo 错误的选项
echo 最终文件名
echo 或输入"b"，返回选项列表
set /p bs="请键入不带扩展名的名称： "
ECHO *********** 所有文件都已处理！ *************
if /i "%va_exit%"=="true" echo  程序将立即关闭
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
set /p bs="输入您的选择： "
::XCI文件
echo 从XCI提取安全分区
echo 仍然有 !conta! 个要处理的文件
echo 自定义图标
echo 用于多游戏xci。
echo 当前自定义图标和名称是通过拖动nsp或控件nca设置的
echo 这样，程序将复制正常分区中的控件nca
echo 如果您不添加自定义图标，则徽标将从您的某个游戏中设置
echo 输入"b"，返回列表生成器
set /p bs="将NSP或NCA文件拖到窗口上，然后按回车键： "
echo "提取LOGO"
::拆分模式
echo 拆分模式已激活
ECHO 发现了以前的列表, 你想做什么？
echo 输入"1"，从上一列表自动开始处理
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo 注意：选择3，您将在开始处理文件之前看到上一个列表，并且您可以
echo 添加和删除列表中的项目。
echo 或输入"0"，返回模式选择菜单
set /p bs="输入您的选择： "
echo 错误的选项
echo 拆分模式已激活
echo 你已经开始一个新的列表
echo 输入"0"，返回模式选择菜单
set /p bs="请将文件或文件夹拖到窗口上，然后按回车键： "
echo 你想做什么？
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo 输入"1"，开始处理
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo 或输入"0"，返回模式选择菜单
set /p bs="拖放文件/文件夹或设置选项： "
set /p bs="输入要删除的文件数（从底部开始）： "
echo 拆分模式已激活
ECHO                要处理的文件
echo 你加了 !conta! 个要处理的文件
echo 错误的选项
echo 接下来选择您要执行的操作
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为xci
echo 输入"3"，全部都要
echo 或输入"b"，返回列表选项
set /p bs="输入您的选择： "
ECHO *********** 所有文件都已处理！ *************
if /i "%va_exit%"=="true" echo  程序将立即关闭
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
set /p bs="输入您的选择： "
echo 仍然有 !conta! 个要处理的文件
::更新模式 -> 第一步
echo                      更新模式已激活
echo 输入"0"，返回模式选择菜单
ECHO                         添加基本内容
set /p bs="请拖动要更新的文件，然后按回车键： "
echo ---文件类型错误。请重试---
ECHO 发现了以前的列表，你想做什么？
echo 输入"1"，开始更新 基本内容
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo 注意：选择3，您将在开始处理文件之前看到上一个列表，并且您可以添加和删除列
echo 表中的项目。
echo 或输入"0"，返回模式选择菜单
set /p bs="输入您的选择： "
echo 错误的选项
echo                      更新模式已激活
echo 你已经开始一个新的列表
echo 输入"1"，将文件夹添加到列表中
echo 输入"2"，将文件添加到列表中
echo 输入"3"，通过本地文件库，将文件添加到列表
echo 输入"4"，通过folder-walker递归的方式，将文件添加到列表
ECHO 请添加要用于更新基本内容的文件
echo 输入"0"，返回模式选择菜单
echo 你想做什么？
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo 输入"1"，开始处理
echo 输入"2"，将另一个文件夹添加到列表中
echo 输入"3"，将另一个文件添加到列表中
echo 输入"4"，通过本地文件库，将文件添加到列表
echo 输入"5"，通过folder-walker递归的方式，将文件添加到列表
echo 输入"6"，更改基本内容
echo 输入"i"，查看要处理的文件列表
echo 输入"b"，查看当前基本内容
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo 输入"e"，退出
echo 或输入"0"，返回模式选择菜单
ECHO                基本内容
set /p bs="输入要删除的文件数（从底部开始）： "
echo              更新模式 已激活
ECHO                要处理的文件
echo 你加了 !conta! 个要处理的文件
echo 错误的选项
echo 您希望如何处理基本文件
echo 输入"1"，以删除以前的更新
echo 输入"2"，以删除以前的DLC
echo 输入"3"，以删除以前的更新和DLC
echo 输入"b"，返回列表选项
set /p bs="输入您的选择： "
echo 错误的选项
echo 接下来选择您要执行的操作
echo 输入"1"，重新打包为NSP
echo 输入"2"，重新打包为xci
echo 输入"3"，全部都要
echo 或输入"b"，返回列表选项
set /p bs="输入您的选择： "
echo 是否要魔改所需的系统版本
echo 如果你选择魔改，它将被设置为与nca加密匹配，因此它只会在必要的
echo 情况下要求更新你的系统。
echo 输入"0"，不魔改
echo 输入"1"，魔改
echo 或输入"b"，返回列表选项
set /p bs="输入您的选择： "
if /i "%patchRSV%"=="none" echo 错误的选项
echo 设置魔改最大系统版本号
echo 根据您的选择，如果读取密钥生成值大于程序中指定的值，则密钥生
echo 成和RSV将降低到相应的密钥生成范围。
echo 这并不总是能降低固件需求。
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
echo 输入"12"，魔改版本FW 12.1.0
echo 输入"13"，魔改版本FW 13.0.0-13.2.1
echo 输入"14"，魔改版本FW 14.0.0-14.1.2
echo 输入"15"，魔改版本FW 15.0.0-15.0.1
echo 输入"16"，魔改版本FW 16.0.0-16.1.0
echo 输入"17"，魔改版本FW 17.0.0-17.0.1
echo 输入"18"，魔改版本FW 18.0.0-18.1.0
echo 输入"19"，魔改版本FW 19.0.0-
echo 或输入"b"，返回列表选项
set /p bs="输入您的选择： "
if /i "%bs%"=="14" set "vkey=-kp 14"
if /i "%bs%"=="14" set "capRSV=--RSVcap 939524096"
if /i "%bs%"=="15" set "vkey=-kp 15"
if /i "%bs%"=="15" set "capRSV=--RSVcap 1006632960"
if /i "%bs%"=="16" set "vkey=-kp 16"
if /i "%bs%"=="16" set "capRSV=--RSVcap 1073741824"
if /i "%bs%"=="17" set "vkey=-kp 17"
if /i "%bs%"=="17" set "capRSV=--RSVcap 1140850688"
if /i "%bs%"=="18" set "vkey=-kp 18"
if /i "%bs%"=="18" set "capRSV=--RSVcap 1207959552"
if /i "%bs%"=="19" set "vkey=-kp 19"
if /i "%bs%"=="19" set "capRSV=--RSVcap 1275068416"
if /i "%vkey%"=="none" echo 错误的选项
ECHO *********** 所有文件都已处理！ *************
if /i "%va_exit%"=="true" echo  程序将立即关闭
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
set /p bs="输入您的选择： "
echo 从XCI提取安全分区
echo 仍然有 !conta! 个要处理的文件
:: 数据库生成模式
echo 数据库生成模式 已激活
ECHO 发现了以前的列表, 你想做什么？
echo 输入"1"，从上一列表自动开始处理
echo 输入"2"，删除列表并创建新列表.
echo 输入"3"，继续构建上一个列表
echo 注意：输入3，您将在开始处理文件之前看到上一个列表，并且您可以
echo 添加和删除列表中的项目。
echo 或输入"0"，返回模式选择菜单
set /p bs="输入您的选择： "
echo 错误的选项
echo 单文件处理已激活
echo 你已经开始一个新的列表
echo 输入"0"，返回模式选择菜单
set /p bs="请将文件或文件夹拖到窗口上，然后按回车键： "
echo 你想做什么？
echo "拖动另一个文件或文件夹，然后按回车键将项目添加到列表中"
echo 输入"1"，开始处理
echo 输入"e"，退出
echo 输入"i"，查看要处理的文件列表
echo 输入"r"，删除一些文件（从底部开始计数）
echo 输入"z"，删除整个列表
echo 或输入"0"，返回模式选择菜单
set /p bs="拖放文件/文件夹或设置选项： "
set /p bs="输入要删除的文件数（从底部开始）： "
echo 单文件处理已激活
ECHO                 要处理的文件
echo 你加了 !conta! 个要处理的文件
echo 错误的选项
echo 接下来选择您要执行的操作
echo 输入"1"，nutdb数据库生成
echo 输入"2"，扩展数据库生成
echo 输入"3"，生成无钥数据库（扩展）
echo 输入"4"，生成上述3个数据库
echo 输入"Z"，生成zip文件S
echo 或输入"0"，返回列表选项
set /p bs="输入您的选择： "
ECHO *********** 所有文件都已处理！ *************
if /i "%va_exit%"=="true" echo  程序将立即关闭
echo 输入"0"，返回模式选择菜单
echo 输入"1"，退出程序
set /p bs="输入您的选择： "
ECHO *********** 所有文件都已处理！ *************
echo 仍然有 !conta! 个要处理的文件
::NSCB文件信息模式
::NSCB_options.cmd 配置脚本
::子程序
echo 希望你玩的开心
