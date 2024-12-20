::--------------------------------------------------------------
::为批处理文件设置自定义颜色
::--------------------------------------------------------------
color 1F
::--------------------------------------------------------------
::设置1: 文件夹
::--------------------------------------------------------------
::work folder
set "w_folder=NSCB_temp"
::输出文件夹
set "fold_output=NSCB_output"
::zip压缩文件夹
set "zip_fold=NSCB_zips"
::--------------------------------------------------------------
::设置2：程序路径
::--------------------------------------------------------------
set "nut=ztools\squirrel.py"
set "xci_lib=ztools\XCI.bat"
set "nsp_lib=ztools\NSP.bat"
set "zip=ztools\squirrel.py"
set "listmanager=ztools\squirrel.py"
set "batconfig=ztools\NSCB_config.bat"
set "batdepend=ztools\install_dependencies.bat"
set "infobat=ztools\info.bat"
::--------------------------------------------------------------
::设置3：储存选项
::--------------------------------------------------------------
::python命令
set "pycommand=python3"
::拷贝功能缓存
::修改字节数以工作得更好
::32768=32kB ; 65536=64kB
set "buffer=-b 262144"
::带或者不带增量部分的拷贝功能
::--C_clean -> 复制或者删除titlerights。不忽略增量部分
::--C_clean_ND-> 复制或者删除titlerights。忽略增量部分
set "nf_cleaner=--C_clean_ND"
set "skdelta=-ND true"
::解密密钥所需的固件
::true -> 魔改meta nca中所需系统版本
::false-> 不魔改meta nca中所需系统版本
set "patchRSV=-pv false"
set "capRSV=--RSVcap 738197504"
::--------------------------------------------------------------
::设置4：重要文件
::--------------------------------------------------------------
::
set "uinput=ztools\uinput"
::keys.txt路径
set "dec_keys=ztools\keys.txt"
::--------------------------------------------------------------
::设置5：打包选项
::--------------------------------------------------------------
::自动模式选择
::nsp->打包为NSP
::xci-打包为XCI
::both->打包为XCI和NSP
set "vrepack=xci"
::文件夹重打包类型
::indiv->重打包多个输入文件为多个输出文件。单文件模式
::multi->重打包多个输入文件为单个输出文件。多文件模式
set "fi_rep=multi"
::--------------------------------------------------------------
::设置6：手动模式信息
::--------------------------------------------------------------
::在手动模式下首先显示的重新打包模式
::indiv->单文件打包模式
::multi->多文件打包模式
::split->文件拆分模式
::update->文件更新模式
::choose->提示选择输入方式
set "manual_intro=choose"
::--------------------------------------------------------------
::设置7：zip文件
::--------------------------------------------------------------
::还原模式的ZIP压缩文件
::true->压缩所需文件
::false->不压缩所需文件
set "zip_restore=false"

::--------------------------------------------------------------
::设置8：最大系统版本
::--------------------------------------------------------------
:: 将加密更改为自动模式下的设置密钥生成
:: 不魔改加密              -> vkey = false
:: "1.0.0"                 -> vkey = 0
:: "2.0.0 - 2.3.0"         -> vkey = 1
:: "3.0.0"                 -> vkey = 2
:: "3.0.1 - 3.0.2"         -> vkey = 3
:: "4.0.0 - 4.1.0"         -> vkey = 4
:: "5.0.0 - 5.1.0"         -> vkey = 5
:: "6.0.0-4 - 6.1.0"       -> vkey = 6
:: "6.2.0"                 -> vkey = 7
:: "7.0.0 - 8.0.1"         -> vkey = 8
:: "8.1.0"                 -> vkey = 9
:: "9.0.0 - 9.0.1"         -> vkey = 10
:: "9.1.0 - 11.0.3"        -> vkey = 11
:: "12.1.0"                -> vkey = 12
:: "13.0.0 - 13.2.1"       -> vkey = 13
:: "14.0.0 - 14.1.2"       -> vkey = 14
:: "15.0.0 - 15.0.1"       -> vkey = 15
:: "16.0.0 - 16.1.0"       -> vkey = 16
:: "17.0.0 - 17.0.1"       -> vkey = 17
:: "18.0.0 - 18.1.0"       -> vkey = 18
:: "19.0.0 -       "       -> vkey = 19
set "vkey=-kp false"

::--------------------------------------------------------------
::设置10：自动退出
::--------------------------------------------------------------
:: 如果设置为true，程序将在手动模式下自动退出
set "va_exit=false"

::--------------------------------------------------------------
::设置11: 跳过RSV和生成密钥被修改提示
::--------------------------------------------------------------
:: 在手动模式下跳过所需的系统版本和密钥生成提示
set "skipRSVprompt=false"

::--------------------------------------------------------------
::设置12：SD卡格式化
::--------------------------------------------------------------
:: 选择打包为exFat或Fat32 SD卡存储格式的XCI文件
::fattype可以是fat32或者exfat
::fexport 将拆分后的nsp打包为files（sxos ROM菜单）或folder（其他安装程序）
set "fatype=-fat exfat"
set "fexport=-fx files"

::--------------------------------------------------------------
::设置13：输出文件夹结构
::--------------------------------------------------------------
::输出文件夹中的文件组织结构
::inline -> 所有文件放置在根目录下
::subfolder -> 文件放到以游戏命名的文件夹下
set "oforg=inline"

::--------------------------------------------------------------
::设置14：新模式/旧模式
::--------------------------------------------------------------
::为新模式或旧模式设置程序启动
::值是new或legacy
set "NSBMODE=new"

::--------------------------------------------------------------
::设置15: 罗马，日本和中国的TITLES
::--------------------------------------------------------------
::romanice ->TRUE
::don't romanize -> FALSE
set "romaji=TRUE"

::--------------------------------------------------------------
::设置16: 翻译亚洲地区的NutDB描述
::--------------------------------------------------------------
::调用谷歌API
::translate ->TRUE
::don't transnutdb ->FALSE
set "transnutdb=FALSE"

::--------------------------------------------------------------
::设置17: 多线程模式
::--------------------------------------------------------------
::当前应用于数据库
set "workers=-threads 1"

::--------------------------------------------------------------
::设置18: NSZ格式用户选项
::--------------------------------------------------------------
set compression_lv=22
set compression_threads=0
set "xci_export=xcz"

::--------------------------------------------------------------
::MTP
::--------------------------------------------------------------
set "MTP=ztools\bin\nscb_mtp.exe"
set "MTP_verification=True"
set "MTP_prioritize_NSZ=True"
set "MTP_exclude_xci_autinst=True"
set "MTP_aut_ch_medium=True"
set "MTP_chk_fw=False"
set "MTP_prepatch_kg=False"
:: 预检查是否已经安装
set "MTP_prechk_Base=True"
set "MTP_prechk_Upd=False"
:: 转储保存
set "MTP_saves_Inline=False"
set "MTP_saves_AddTIDandVer=False"
:: 为公共Google驱动器缓存激活TrueCopy或使用符号链接
set "MTP_pdrive_truecopy=True"
:: 高级安装选项
set "MTP_stc_installs=False"
set "MTP_ptch_inst_spec=spec1"
::--------------------------------------------------------------
:: 调用库
::--------------------------------------------------------------
set "squirrel_lb=ztools\squirrel_lib_call.py"