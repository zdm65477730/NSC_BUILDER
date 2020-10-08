# Nintendo Switch Cleaner and Builder (NSC_Builder)
![DeviceTag](https://img.shields.io/badge/Device-SWITCH-e60012.svg)  ![LanguageTag](https://img.shields.io/badge/languages-python_batch_html5_javascript-blue.svg)

## 1.说明

Nintendo Switch清洁和生成器。基于hacbuild和Nut的python库的批处理文件，python和html脚本。最初设计用于从nsp文件中删除标题权加密并制作多内容的nsp / xci文件，如今，它是一种专门用于批处理和文件信息的多内容工具，有人称其为Switch's Knife，他也许是正确的。

NSC_Builder既基于Blawar's nut.py的作品，又基于Luca Fraga的hacbuild，并且由“松鼠”提供动力，该松鼠原本是坚果叉，具有附加功能，如今，它可以被认为是自己的独立程序。
从v0.8版本开始，该程序不再依赖hacbuild生成xci，并且开发了新代码以更好地与squirrel集成。

## 2.“删除所有权”的含义是什么。
当您从nsp文件中删除标题权利加密时，您无需门票即可安装游戏，前提是您不向任天堂发送遥测数据，因此控制台上的可跟踪足迹较小。
它还有助于从nsp到xci文件的转换，从而无需在外部安装票证。

## 3.我可以使用该程序做什么？

该程序的当前版本允许您：

1.-制作多内容的xci或nsp文件。

2.-从nsp文件中“擦除标题权限”加密。

3.-无需“更新分区”即可构建xci文件**，这意味着它们占用的存储空间更少。

4.-从更新中删除**增量**

5.- **将多内容**拆分回xci或nsp文件

6.-更改xci和nsp之间内容的包装

7.- **降低所需的系统版本**到游戏的实际加密。

8.-降低解密游戏所需的万能钥匙。

9.- **从xci和nsp签出信息**，包括能够执行它的固件，游戏信息，nca内容的大小…

10.- **从nacp和cnmt文件中检查数据**而无需从nsp \ xci中提取它们

10.-重新包装xci和nsp内容，格式与** fat32 **兼容

11.-``大量构建''xci文件和nsp文件以单内容和多内容格式

12.-``重命名''nsp，xci文件以匹配其内容

13.- **验证** nsp，nsx，nsz，xci和nca文件

14.-以文本格式输出信息

15.-提取nsp文件的内容**和xci文件的安全分区

16.-将作业设置为以后在多模式下

17.-在多模式下按基本标题分隔作业

18.- **从文件名中删除坏字符**（清除）或将亚洲名称转换为罗马字

19.-为基本游戏和DLC提取nca文件内容，或将ncas提取为纯文本

20.- ** Joiner **适用于xc *，ns *和0 * fat32文件

21.-将nsp文件压缩为.nsz文件

22.- **图形界面**，用于通过在Chrome \ chrome上运行的gui的gui本地文件和Google驱动器上的文件的信息

23.-使用NSC_Builder修改的nsp \ xci的“恢复”到其原始游戏nca文件。

## 3.1在DBI安装程序的帮助下，它可以：

24.- **通过本地交换机从Google驱动器（身份验证和链接）或从1fichier安装或传输文件**至mtp

25.- **从PC到交换机的** xcis和多内容xcis生成和传输**

26.- **自动更新**您的Nintendo Switch在本地或从谷歌驱动器

27- **通过nutdb搜索已安装游戏的新更新和DLC **，以便在游戏卡中搜索已安装游戏和xci

28- **从Nintendo Switch上转储或保存游戏**

29- **卸载**您的游戏并删除存档的游戏/占位符

30- **生成并传输SX自动加载器文件**，用于自动将xcis挂载到SD和HDD位置，以供可扫描位置使用，而不能被SX OS扫描

31- **清理重复的SX OS自动加载器文件**，以避免SD和HDD文件之间发生冲突

## 4.批处理模式：

批处理有2种模式：

-**自动模式：**您可以分别拖动nsp文件或具有多个文件的文件夹，以进入自动模式。

-**手动模式：**双击批处理，您可以建立要处理的文件列表。

通过“手动模式下的配置菜单”配置自动模式的行为。

## 5.手动模式选项：

-**模式0：配置模式。**让您配置程序在自动和手动模式下的运行方式。
-**模式1：独立打包。**让您处理文件列表并单独打包
  *打包为nsp \ xci
  * Supertrimm \ Trimm \ Untrimm xci文件
  *重命名xci或nsp文件
  *按cnmt顺序重建nsp文件并添加cnmt.xml
  *验证nsp，xci文件
-**模式2：多次打包。**让您将文件列表打包到单个xci或nsp文件中。
  *通过baseid分开文件
  *设置作业以供以后
  *处理以前的工作
-**模式3：Multi-Content-Splitter。**让您将内容分离为nsp和xci文件。
-**模式4：文件信息。**让您查看并导出有关nsp和xci文件的一些信息
  *有关nsp \ xci中包含文件的数据
  *有关文件中内容ID的数据
  *螺母信息由blawar实施
  *有关固件要求和其他游戏数据的信息
  *从meta nca读取cnmt文件
  *从控件nca读取nacp文件
  *从程序nca读取npdm文件
  *验证文件是否具有检测NSCB更改的能力
-**模式5：数据库模式。**让您大量输出信息
-**模式6：高级模式。**
  *从nsp \ xci提取所有内容
  *以原始模式从nsp \ xci中提取所有内容
  *以纯文本格式从nsp \ xci中提取所有内容
  *从nsp \ xci中的nca提取文件
  *修补需要链接链接数的游戏
-**模式7：文件合并器模式。**加入fat32分割的文件
-**模式8：压缩\解压缩**
  *将nsp文件压缩为nsz格式
  *将nsz文件解压缩为nsp文件
-**模式9：文件还原模式。**恢复可验证的修改文件
-** L：旧版模式。**旧功能
-** D：GOOGLE DRIVE MODE：**
  *从谷歌驱动器下载文件
    *正常下载功能
    *搜索过滤器和库选择
    *下载修整过的xci文件
    *下载解压的nsz文件
  *检查有关文件的信息
-** M：MTP模式：**
  *从本地文件或远程库安装游戏
  *从本地文件或远程库进行文件传输
    *正常转移
    *生成xci并传输
    *生成多xci并传输
  * **通过本地库或Google驱动器库自动更新**设备
  * **转储或卸载文件**
    *将安装的内容从设备转储到PC
    *卸载设备上已安装的内容
    *从PC删除存档的游戏或占位符条目
  * **遵循JKSV格式的zip备份Savegames **
  * **显示设备信息**
    *通过mtp共享的设备信息
    *在设备上显示已安装的游戏和xci
    *显示设备上已安装的游戏和xci的新更新和dlc。为了准确性，xci必须遵循NSCB格式，包括content_number标签
    *显示存档的游戏/占位符注册表
    *显示存档游戏的可用更新和DLC列表
  * **生成SX自动加载器文件**
    *在SD上为xci生成文件
    *在硬盘中为xci生成文件，可以选择推送并与SD文件运行冲突检查
    *从库文件夹中推送SX自动加载器文件
    *运行冲突检查，清理未使用的SD自动加载器文件，清理指向HDD的冲突自动加载器文件（如果SD中已经存在具有该ID的xci）

## 6.配置模式：

####自动模式选项。 （仅影响自动模式）

##### I.REPACK配置

-NSP
-XCI
-两者

##### II。文件夹的处理

-分别重新打包文件夹的文件（单个内容文件）
-重新包装文件夹的文件（多内容文件）

##### III。 RSV修补程序配置

-修补程序要求的系统版本（如果大于加密版本）
-如果修补程序大于加密版本，请不要对其进行修补

##### IV。 KEYGENERATION配置

-设置文件允许的最大密钥生成（加密）。

##### V.全局选项。 （影响程序在全球范围内的工作方式）

##### VI。文字和背景颜色

-让我们选择cmd窗口的颜色

七。工作文件夹的名称

-让我们选择工作文件夹的名称

八。输出文件夹的名称

-让我们选择输出文件夹的名称和位置

##### IX。 DELTA文件处理

-让您选择是否要打包增量NCA文件。默认情况下设置为false。

##### X. AUTO-EXIT配置
-让我们选择是否在完成作业后关闭cmd窗口。

十一。密钥生成提示

-让您选择是否要查看提示，要求您在手动模式下修补RSV和密钥生成。

##### XII。文件流BUFFER

-文件流操作的缓冲区

##### XIII。文件FAT32 \ EXFAT选项

将xci或nsp打包为fat32兼容格式或exfat格式。

-将卡格式更改为exfat（默认）
-将SX OS的CARD FORMAT更改为fat32（xc0和ns0文件）
-将所有CFW（存档文件夹）的CARD FORMAT更改为fat32

##### XIV。如何组织输出文件（当前未在新模式下使用）

-分开组织文件（默认）
-组织按内容设置的文件夹中的文件

##### XV。设置新模式或旧模式

-使用新的更高级的方法（默认）
-使用旧的文件处理方法

##### XVI。使用直接多重时的ROMANIZE名称

-将名称转换为罗马字（默认）
-从文件中读取名称，并在读取时保留亚洲名称

##### XVII。使用Google翻译器从游戏信息中翻译说明

-FALSE（默认）
-是的翻译日文，中文和韩文说明。

##### XVIII。工人使用多线程进行重命名和数据库构建

-1（默认\已停用）
- 你的号码。使用多个工作程序同时进行多个重命名或创建多个数据库字符串

## 7. Gui提供文件信息：

-** NSCB File_Info **是基于html的gui，它为NSCB信息提供了图形界面。
  是的，它包含游戏图标，图片以及您喜欢的东西。

-当前功能是：

  * **游戏信息**。结合了从文件读取的数据和来自Nutdb的eshop数据
  * **描述：**来自eshop（nutdb）的描述
  * **图片库：**来自eshop的图片（nutdb）
  * ** BaseID文件树：**显示DLC的最新版本以及与游戏（nutdb）相关的更新
  * **标题：**来自NSCB的高级文件列表（新增）
  * NSCB的** NACP Reader **
  * NSCB的** NPDM Reader **
  * **来自NSCB的CNMT阅读器**
  * **来自NSCB的验证**，直到第2级，因此可以快速加载。现在使用普通NSCB进行哈希处理。
  * **游戏信息**。结合了从文件读取的数据和来自Nutdb的eshop数据
  * **图书馆**。从本地库或Google驱动器加载文件，并且之前已设置了库位置
  * **直接链接**。从直接链接中读取信息。

-您会注意到现在添加了诸如BuildIDs之类的一些信息，使cnmt更具可读性，并且我添加了对Grandia和Hotline Miami等多程序游戏的检测

- **已知的问题：**

  * CSS可能需要做一些工作，特别是对于全屏显示。
  *上角菜单是一个占位符
  *在某些游戏中NPDM解密失败，在我的TODO列表中
  *多内容文件（通常为xci）可能需要做一些工作以提高解析速度
  *不读取尚未分割的文件（ns *，xc *，0 *），但很快就会添加

- **去做：**

  *输出CSS到主题文件
  *语言翻译
  *移植NSCB功能
  *让用户选择nutdb文件

- **如何使用：**

  *如果您已安装Chrome或Chromium，则可以使用。
  *如果您不想安装这些浏览器，则可以使用便携式Chrome。
1.在此处获取系统的最新版本：https://chromium.woolyss.com/
2.在ztools中创建一个名为“ Chromium”的文件夹
3.解压缩PC上的Chrome文件，然后执行“ chrlauncher 2.5.6（64位）.exe”或zip中的任何调用，以下载所需的文件
4.将所有文件移动到ztools \ Chromium，然后将“ chrlauncher 2.5.6（64位）.exe”重命名为“ chrlauncher.exe”。这优先于chrome \ chromium安装
  *完成所有设置后，只需执行“ Interface.bat”
5.记住，您需要在ztools中填写keys_template.txt，但我想您已经知道
-我使用python：
  *只需获取最新的python 3并安装以下依赖项：
urllib3 unidecode tqdm bs4 tqdm请求图像pywin32 pycryptodome pykakasi googletrans chardet鳗鱼瓶
  *现在棘手的部分是，我使用的是未在pypy中发布的鳗鱼的未发布版本，所以请转到此处https://github.com/ChrisKnott/Eel下载母版，找到您的鳗鱼安装所在的文件夹，并使用那些在主人。
如果您找不到它，请尝试再次执行pip install eel，它将告诉您最新信息并安装在“ X”文件夹中。
  *然后执行“ Interface.bat”
-我使用linux或mac：
  *好吧，我在Linux上进行了测试，以后我会给您一个版本，必须承认我没有在Mac上进行任何测试，尽管我认为它可以工作
  *安装python并：
urllib3 unidecode tqdm bs4 tqdm请求图像pycryptodome pykakasi googletrans chardet鳗鱼瓶
  *与之前忽略NSCB用于在文件夹中设置存档位的pywin32相同
  *将鳗鱼文件替换为上面说明的master文件中的文件。
  *运行松鼠：
squirrel.py -lib_call接口启动
  *或者，如果您不喜欢python，请等待几天进行构建

## 8. File_Info Gui示例：

！[图片]（https://i.ibb.co/12kCsDk/FI1.png）
！[Picture2]（https://i.ibb.co/R93H02v/FI3.png）
！[Picture3]（https://i.ibb.co/HCfTdxj/FI11.png）

## 9.重要

由于该原因，该程序试图修改nsp和xci文件中的最小数据，因此它需要签名补丁来忽略NCA标头中的两个签名。已经包含它们的固件是：
-SX操作系统
-ReiNX
https://github.com/Reisyukaku/ReiNX/releases
-对于Kosmos，请使用joonie86 sigpatches和Hekate5.0或joonie86 Hekate Mode，即J
https://github.com/Joonie86/hekate/releases/tag/5.0.0J
-对于大气使用4n信号
https://gbatemp.net/attachments/2-0-0-8-1-0-zip.170607/

要安装multi-nsp，您需要与它们兼容的安装程序。报告的兼容安装程序是：
-SX OS rom菜单
-SX OS安装程序
-布拉瓦尔的锡箔纸：
http://tinfoil.io/Download
-Blawar的tinfoil或者Lithium：
http://tinfoil.io/Download

要安装ncz文件，您需要：
-SX OS安装程序
-Blawar的Tinfoil：
http://tinfoil.io/Download

## 10.要求

-需要装有Windows操作系统的计算机
-在ztools文件夹中填充keys_template.txt并将其重命名为keys.txt
  如果您的控制台为FW6.2或以下版本，则可以使用Lockpick获取完整的密钥集
  朋友可以借给您所需的钥匙。
  如果要添加xci_header_key，则朋友需要将其借给您。
  https://github.com/shchmue/Lockpick/releases
-mtp功能要求4.0或更高版本，但以4.7.2网络框架为目标构建。网络框架的推荐版本为4.7.2和4.8.0

## 11.局限性
-制作超过8个游戏的多内容xci文件。在水平方向加载时会出错。我怀疑这可能是qlauncher的限制，因此可以与主题mod一起使用，但INTRO并未对其进行测试。
注意：这意味着“游戏”，更新和dl car不受此限制。
-从6.0开始，某些游戏的标题权利删除dlc会给出消息提示，内容不完整，该消息可以跳过，并且尽管有提示，但dlc仍可以正常工作。
-当前的mtp模式无法即时对游戏进行补丁\转换，它需要实现对流进行补丁的功能或通过来自松鼠的套接字发送文件的功能。将来将实施这两个选项之一。

## 12.感谢和感谢

** NSC_Builder基于**

a。）坚果：如果没有最出色的Switch场景制作人之一的“ blawar”的工作，那么在这一点上是不可能的。
https://github.com/blawar/nut

b。）Hacbuild：xci重新打包功能基于LucaFraga制造的hacbuild的代码

-原始hacbuild：LucaFraga的https://github.com/LucaFraga/hacbuild）

-我修改过的hacbuild：https://github.com/julesontheroad/hacbuild

c。）mtp模式在很大程度上依赖于DUCKBILL的DBI安装程序。具体来说，已使用DBI 1.25进行了测试

-DBI包含在keffir CFW包中：https://github.com/rashevskyv/switch/releases

-DBI 1.25首先包含在此版本中：https://github.com/rashevskyv/switch/releases/tag/456

-在NSCB主文件夹（称为“ DBI”）中，也可以在nro和nsp中找到od的副本od。

d。）blawar的nsz，xcz和ncz规范：https：//github.com/blawar/nsz

e。）感谢他的不间断帮助，达到0Liam。

f。）从pythac（Rikikooo制造）改编的pyNCA3，pyNPDM，pyPFS0，pyRomFS库

g。）从dagnelies改编Pysos用于某些操作：https://github.com/dagnelies/pysos

**还感谢：**

Nicoboss最初的nsp和xci压缩思想：
https://github.com/nicoboss/nsZip/

模拟人。他制作了splitNSP.py，计算出Horizo​​n格式分割的nsps所需的块大小（与分割的xci块大小不同）和存档文件夹的需要）
https://github.com/AnalogMan151/splitNSP/releases

向MadScript77提出他的伟大建议，特别是该批次的配置文件的想法。

Thx为0mn0，老SH团队总是乐于助人。

感谢evOLved，朱砂和某些巨龙，他们提供了帮助和好的建议。

同时还要感谢来自gbatemp，elotrolado.net的所有成员以及不和谐的我的朋友;）


* 2020年-JulesOnTheRoad-https://github.com/julesontheroad/NSC_BUILDER*