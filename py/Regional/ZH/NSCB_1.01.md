# NSC_Builder v1.01b - 更新日志

![DeviceTag](https://img.shields.io/badge/Device-SWITCH-e60012.svg)  ![LanguageTag](https://img.shields.io/badge/languages-python_batch_html5_javascript-blue.svg)

## *支持较新的DBI版本（> 155）*

**资源**

DBI 156已经发布，您可以从kefir包中直接获得它：

https://github.com/rashevskyv/switch/releases/

也可以在此处单独下载为nro或nsp。

[DBI_156.nsp](https://github.com/julesontheroad/NSC_BUILDER/raw/master/py/Documentation%20and%20Resources/DBI/156/DBI_0591703820420000.nsp)

[DBI_156.nro](https://github.com/julesontheroad/NSC_BUILDER/raw/master/py/Documentation%20and%20Resources/DBI/156/DBI.nro)

您可以在此处找到有关如何设置NSCB库，Google网盘身份验证令牌和1个文件身份验证令牌的信息：

https://github.com/julesontheroad/NSC_BUILDER/blob/master/py/Documentation%20and%20Resources/Changelogs/NSCB_0.99.md

这也是一些DBI信息的自述文件：

https://github.com/julesontheroad/NSC_BUILDER/tree/master/py/Documentation%20and%20Resources/DBI

## * 1.01-b - 更新日志*
### 1. 修复了界面中nsz和xcz文件不显示文件选择器的问题
### 2. 改进了数据库之间的titledb版本的合并

* 修复了从tinfoil.io而不是从我的titledb存储库下载versions.txt的问题 
* 添加了nutdb.json作为versions.txt合并的源

### 3. 对mtp上的Google网盘请求进行了更改

### 4. 修复了批量验证不会对xcz文件进行哈希处理的问题

## *1.01 - 更新日志*

### 1. 支持DBI 155和156版本的新mtp设置

DBI安装设置和155上的保存管理更改，此版本支持较旧的DBI版本和较新的版本。

### 2. 添加了仅用于已安装游戏的备份保存选项

此选项仅对** DBI> 155 **有效，与更新的DBI函数匹配。

### 3. 添加了从Google Drive远程安装xci和xcz文件

此选项将支持从Google网盘安装多程序文件和普通xci或xcz文件。 **此版本不支持来自Google网盘的多程序文件**，这些文件支持以任何格式或以nsp或nsz格式进行本地安装。

已知的多程序文件是“超级马里奥3D全明星”，“格兰迪亚收藏”，“热线迈阿密收藏”，...

### 4. 为mtp模式添加了固定的xci扫描路径配置

用户现在可以设置DBI将在SD卡上扫描的位置，以在** zconfig \ mtp_xci_locations.txt **上找到xci文件，该文件已包含标准xci位置。如果删除了该文件，DBI将扫描整个SDCard，因此不建议删除它，而是在需要时添加或删除位置。

### 5. 向MTP添加了选项-从库自动更新设备以从游戏注册表中进行检查而不是安装

激活从游戏注册表中进行选择时，自动启动将设置为false，并且将要求用户通过文件选择器手动选择要更新的游戏。

此功能不会检查SDCard上已安装了哪些游戏或xci，而是将使用游戏注册表，其中包括存档的游戏和已注册的xci文件，而与它们的位置无关。例如，这将显示HDD上的文件。

### 6. 修复由于特殊字符而从Google网盘安装某些文件失败的问题

现在将文件ID添加到文本文件，并且文件ID现在也以缓存模式存储在json文件中。

### 7. 文件选择器现在允许一次选择多个文件
现在，使用Windows浏览器的tkinter文件选择器允许一次选择多个文件（如果它们位于同一文件夹中）。

### 8. 在界面的“文件”选项卡上添加了其额外的信息

- 增加了显示“文件”选项卡上Web界面上本地文件的每个nca文件的多个titleid的功能 
- 增加了在“文件”选项卡上的Web界面上为本地程序的每个程序文件显示多个buildid的功能。这在“文件”选项卡底部的部分中显示

![Picture](https://i.ibb.co/6WR2hnq/exefs.png)

### 9. 修正了已经补丁过的多程序文件的校验

删除了标题权的多程序文件将为html手动文件带来错误的肯定肯定的错误，此问题已得到纠正。修补文件是指删除了标题权利或更改了密钥生成的文件

### 10. 支持不自动更新数据库的设置

如果将数据库配置设置为大于** 9999小时**的数字，则会关闭自动更新功能。没有自动更新的zip文件已包含此设置。

### 11. 其他修正和bug修复：

- 将密钥生成字符串更新为** FW 10.2.0 ** 
- 现在，未遵循适当标准的票证会发出警告，而不是阻止某些功能上的所有权被删除。 
- 修复了在某些情况下无法读取buildid时挂起的界面。 
- 增加了有关螺母信息的xci证书的更好表示。 
- 对python版本的库调用速度更快，这应该可以加快批处理菜单的速度。 
- 修复了＃169，其中某些语言组合由于python语义上的更改而破坏了正确的语言标签添加。 
- 其他小错误修正