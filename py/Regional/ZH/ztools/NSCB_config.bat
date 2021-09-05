:sc1
set "op_file=%~1"
set "listmanager=%~2"
set "batdepend=%~3"
cls
call :logo
echo ********************************************************
echo ѡ��-����
echo ********************************************************
echo ����"1"���Զ�ģʽѡ��
echo ����"2"��ȫ�ֺ��ֶ�ģʽѡ��
echo ����"3"����֤��Կ�ļ�keys.txt
echo ����"4"������nutdb
echo ����"5"������ѡ��
echo ����"6"��������ѡ��
echo ����"7"���ȸ�����ѡ��
echo ����"8"��MTPѡ��
echo.
echo ����"c"����ȡ��ǰ�����ļ�
echo ����"d"������Ĭ������
echo ����"0"������������
echo .......................................................
echo.
set /p bs="��������ѡ�� "
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
echo �����ѡ��
echo.
goto sc1

:sc2
cls
call :logo
echo ********************************************************
echo �Զ�ģʽ����
echo ********************************************************
echo ����"1"���������´������
echo ����"2"�������ļ��еĴ���ʽ
echo ����"3"������RSV�޲�����
echo ����"4"���Ը�����Կ��������
echo.
echo ����"c"����ȡ��ǰ�Զ�ģʽ����
echo ����"d"������Ĭ���Զ�ģʽ����
echo ����"0"���������ò˵�
echo ����"e"������������
echo .......................................................
echo.
set /p bs="��������ѡ�� "
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
echo �����ѡ��
echo.
goto sc2

:op_repack
cls
call :logo
echo *******************************************************
echo ���´������
echo *******************************************************
echo �Զ�ģʽѡ��
echo .......................................................
echo ����"1"�����´��ΪNSP
echo ����"2"�����´��ΪXCI
echo ����"3"��ȫ����Ҫ
echo ����"4"������������ɾ����������
echo ����"5"����cnmt˳���ؽ�NSPs
echo.
echo ����"b"�������Զ�ģʽ-����
echo ����"0"���������ò˵�
echo ����"e"������������
echo .......................................................
echo.
set /p bs="��������ѡ�� "
set "v_rep=none"
if /i "%bs%"=="1" set "v_rep=nsp"
if /i "%bs%"=="2" set "v_rep=xci"
if /i "%bs%"=="3" set "v_rep=both"
if /i "%bs%"=="4" set "v_rep=nodelta"
if /i "%bs%"=="5" set "v_rep=rebuild"

if /i "%bs%"=="b" goto sc2
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_rep%"=="none" echo �����ѡ��
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
echo �ļ��д���
echo **********************************************************************
echo ������Զ�ģʽ�´����ļ���
echo ......................................................................
echo ����"1"���������´���ļ��е��ļ������������ļ���
echo ����"2"�����ļ��е��ļ����´����һ�𣨶������ļ���
echo ����"3"��ͨ��BASE ID���´���ļ��е��ļ�
echo.
echo ����"b"�������Զ�ģʽ-����
echo ����"0"���������ò˵�
echo ����"e"������������
echo ......................................................................
echo.
set /p bs="��������ѡ�� "
set "v_fold=none"
if /i "%bs%"=="1" set "v_fold=indiv"
if /i "%bs%"=="2" set "v_fold=multi"
if /i "%bs%"=="3" set "v_fold=baseid"

if /i "%bs%"=="b" goto sc2
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_fold%"=="none" echo �����ѡ��
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
echo ħ�������ϵͳ�汾
echo ***************************************************************************
echo ����meta NCA��Ϊ��Ҫ���ϵͳ�汾���Զ�ģʽ��
echo ...........................................................................
echo ���������ϵͳ�汾���Ա����̨��Ҫ����¸��������̼��汾��������Կ
echo.
echo ����"1"��ħ��
echo ����"2"����ħ��
echo.
echo ����"b"�������Զ�ģʽ-����
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_RSV=none"
if /i "%bs%"=="1" set "v_RSV=-pv true"
if /i "%bs%"=="2" set "v_RSV=-pv false"

if /i "%bs%"=="b" goto sc2
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_RSV%"=="none" echo �����ѡ��
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
echo ����ϵͳ�汾
echo ***************************************************************************
echo ��������趨ֵ������ļ����ɣ��Զ�ģʽ��
echo ...........................................................................
echo ���Ķ�̬���ɲ����¼�����Կ�飬��ʹ�ýϵ͵�����Կ����nca��
echo.
echo ����"f"����ħ��
echo ����"0"��ħ�İ汾FW 1.0
echo ����"1"��ħ�İ汾FW 2.0-2.3
echo ����"2"��ħ�İ汾FW 3.0
echo ����"3"��ħ�İ汾FW 3.0.1-3.0.2
echo ����"4"��ħ�İ汾FW 4.0.0-4.1.0
echo ����"5"��ħ�İ汾FW 5.0.0-5.1.0
echo ����"6"��ħ�İ汾FW 6.0.0-6.1.0
echo ����"7"��ħ�İ汾FW 6.2.0
echo ����"8"��ħ�İ汾FW 7.0.0-8.0.1
echo ����"9"��ħ�İ汾FW 8.1.0
echo ����"10"��ħ�İ汾FW 9.0.0-9.0.1
echo ����"11"��ħ�İ汾FW 9.1.0-11.0.3
echo ����"12"��ħ�İ汾FW 12.1.0-
echo.
echo ����"b"�������Զ�ģʽ-����
echo ����"c"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
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

if "%v_KGEN%"=="none" echo �����ѡ��
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
echo ȫ��ѡ��-����
echo **********************************************
echo ����"1"�������ı��ͱ���ɫ
echo ����"2"�����Ĺ����ļ��е�����
echo ����"3"����������ļ��е�����
echo ����"4"�����������ļ�����
echo ����"5"������zip���� (LEGACY)
echo ����"6"�������Զ��˳�����
echo ����"7"��������Կ������ʾ
echo ����"8"�������ļ���������
echo ����"9"�������ļ�fat32\exfatѡ��
echo ����"10"����֯����ļ�
echo ����"11"��������ģʽ���ģʽ
echo ����"12"������������ĸ����ʹ��direct-multi
echo ����"13"�����ļ���Ϣ�з�����Ϸ������
echo ����"14" to ���Ĺ����߳���������ʱ���ã�
echo ����"15" to �����û�Ԥ��NSZѹ��
echo ����"16" to ����ѹ����XCI������ʽ
echo.
echo ����"c"����ȡ��ǰȫ������
echo ����"d"������Ĭ��ȫ������
echo ����"0"���������ò˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ�� "

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

echo �����ѡ��
echo.
goto sc3

:op_color
cls
call :logo
echo ********************************************************
echo ��ɫ-����                              
echo ********************************************************
echo --------------------------------------------------------
echo ǰ����ɫ���ı���ɫ��                     
echo --------------------------------------------------------
echo ����"1"�����ı���ɫ����Ϊ����ɫ��Ĭ�ϣ�
echo ����"2"�����ı���ɫ����Ϊ��ɫ
echo ����"3"�����ı���ɫ����Ϊ��ɫ
echo ����"4"�����ı���ɫ����Ϊ��ɫ
echo ����"5"�����ı���ɫ����Ϊˮ��ɫ
echo ����"6"�����ı���ɫ����Ϊ��ɫ
echo ����"7"�����ı���ɫ����Ϊ��ɫ
echo ����"8"�����ı���ɫ����Ϊ��ɫ
echo ����"9"�����ı���ɫ����Ϊ��ɫ
echo ����"10"�����ı���ɫ����Ϊ��ɫ
echo ����"11"�����ı���ɫ����Ϊǳ��ɫ
echo ����"12"�����ı���ɫ����Ϊǳ��ɫ
echo ����"13"�����ı���ɫ����Ϊǳˮ��ɫ
echo ����"14"�����ı���ɫ����Ϊǳ��ɫ
echo ����"15"�����ı���ɫ����Ϊǳ��ɫ
echo ����"16"�����ı���ɫ����Ϊǳ��ɫ
echo.
echo ����"d"������Ĭ����ɫ����
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo.
set /p bd="��������ѡ�� "

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
echo ����ɫ
echo -----------------------------------------------------
echo ����"1"��������ɫ����Ϊ��ɫ��Ĭ�ϣ�
echo ����"2"��������ɫ����Ϊ��ɫ
echo ����"3"��������ɫ����Ϊ��ɫ
echo ����"4"��������ɫ����Ϊˮ��ɫ
echo ����"5"��������ɫ����Ϊ��ɫ
echo ����"6"��������ɫ����Ϊ��ɫ
echo ����"7"��������ɫ����Ϊ��ɫ
echo ����"8"��������ɫ����Ϊ��ɫ
echo ����"9"��������ɫ����Ϊ��ɫ
echo ����"10"��������ɫ����Ϊ����ɫ
echo ����"11"��������ɫ����Ϊǳ��ɫ
echo ����"12"��������ɫ����Ϊǳ��ɫ
echo ����"13"��������ɫ����Ϊǳˮ��ɫ
echo ����"14"��������ɫ����Ϊǳ��ɫ
echo ����"15"��������ɫ����Ϊǳ��ɫ
echo ����"16"��������ɫ����Ϊǳ��ɫ
echo.
echo ����"d"������Ĭ����ɫ����
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ�� "

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
echo �����ļ�������-����
echo ***********************************
echo ����"1"��������Ĭ�Ϲ����ļ��е�����
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
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
echo ����ļ��е�����-����
echo *************************************
echo ����"1"������Ĭ������ļ��е�����
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
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
echo �����ļ�����-����
echo ***************************************************************************
echo ��ȡ����ʱ��������NCA�ļ�
echo ...........................................................................
echo �������ڽ���ǰ�ĸ���ת��Ϊ�µĸ��£����¿��԰��������ĸ���+������
echo �������ֶ���xci�����ǲ���Ҫ�ģ������ǿ����ڰ�װ�����nsp������ǰ�ĸ���ת��Ϊ�µĸ��¡�
echo û���������£����ľɸ��½�������ϵͳ�У�����Ҫ����ж�ء�
echo.
echo ����"1"������������Ĭ�����ã�
echo ����"2"�����´����������
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_delta=none"
if /i "%bs%"=="1" set "v_delta=--C_clean_ND"
if /i "%bs%"=="1" set "v_delta2_=-ND true"
if /i "%bs%"=="2" set "v_delta=--C_clean"
if /i "%bs%"=="2" set "v_delta2_=-ND false"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_delta%"=="none" echo �����ѡ��
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
echo zip�ļ�����
echo ***************************************************************************
echo ʹ�ü�����ļ���Ϣ����zip�ļ�
echo ...........................................................................
echo.
echo ����"1"������zip�ļ�
echo ����"2"��������zip�ļ���Ĭ�����ã�
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_gzip=none"
if /i "%bs%"=="1" set "v_gzip=true"
if /i "%bs%"=="2" set "v_gzip=false"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_gzip%"=="none" echo �����ѡ��
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
echo �Զ��˳����ã��ֶ�ģʽ��
echo ***************************************************************************
echo �������ļ����Զ��˳���������һ������
echo ...........................................................................
echo.
echo ����"1"���������Զ��˳���Ĭ�����ã�
echo ����"2"������Ϊ�Զ��˳�
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_exit=none"
if /i "%bs%"=="1" set "v_exit=false"
if /i "%bs%"=="2" set "v_exit=true"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_exit%"=="none" echo �����ѡ��
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
echo ��ʾ\���������ϵͳ�汾����Կ���ɸ�������
echo ***************************************************************************
echo.
echo ����"1"����ʾRSV��ʾ��Ĭ�����ã�
echo ����"2"������ʾRSV��ʾ
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "skipRSVprompt=none"
if /i "%bs%"=="1" set "skipRSVprompt=false"
if /i "%bs%"=="2" set "skipRSVprompt=true"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%skipRSVprompt%"=="none" echo �����ѡ��
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
echo ΪNSP��XCI���ļ��������ø��ӻ�����
echo ***************************************************************************
echo ��ѡ���Ӱ����̵��ٶȡ�����Ļ���ȡ�������ϵͳ��
echo Ĭ������Ϊ64kb
echo.
echo ����"1"��������������Ϊ80KB
echo ����"2"��������������Ϊ72kb
echo ����"3"��������������Ϊ64KB��Ĭ�ϣ�
echo ����"4"��������������Ϊ56KB
echo ����"5"��������������Ϊ48kb
echo ����"6"��������������Ϊ40KB
echo ����"7"��������������Ϊ32KB
echo ����"8"��������������Ϊ24kb
echo ����"9"��������������Ϊ16KB
echo ����"10"��������������Ϊ8kb

echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
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

if "%v_buffer%"=="none" echo �����ѡ��
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
echo ���ý�SD�����ļ�ϵͳ��ʽ
echo ***************************************************************************
echo SX OS ROM�˵�֧�ַָ���ns0��ns1...nsp�ļ����Լ��ѹ鵵�ļ����е�00��01�ļ����Զ�Ӧ���ṩ����2��ѡ�
echo.
echo ����"1"��������ʽ����Ϊexfat��Ĭ�ϣ�
echo ����"2"��������ʽ����ΪFAT32��XC0��NS0�ļ���
echo ����"3"��������CFW�Ŀ���ʽ����ΪFAT32���浵�ļ��У�
echo.
echo ע�⣺�浵�ļ���ѡ�NSP�ļ����ļ�����Ϊ�ļ��к�XCI�ļ���
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
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

if "%v_fat1%"=="none" echo �����ѡ��
if "%v_fat1%"=="none" echo.
if "%v_fat1%"=="none" goto op_fat
if "%v_fat2%"=="none" echo �����ѡ��
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
echo ����ļ�������������֯��ʽ
echo ***************************************************************************
echo.
echo ����"1"��������֯�ļ���Ĭ�ϣ�
echo ����"2"����֯���������õ��ļ����е��ļ�
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_oforg=none"
if /i "%bs%"=="1" set "v_oforg=inline"
if /i "%bs%"=="2" set "v_oforg=subfolder"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_oforg%"=="none" echo �����ѡ��
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
echo ��ģʽ���ģʽ��������
echo ***************************************************************************
echo.
echo ����"1"���Կ�ʼ��ģʽ��Ĭ�ϣ�
echo ����"2"���ԴӾ�ģʽ��ʼ
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_nscbmode=none"
if /i "%bs%"=="1" set "v_nscbmode=new"
if /i "%bs%"=="2" set "v_nscbmode=legacy"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_nscbmode%"=="none" echo �����ѡ��
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
echo ֱ�Ӷ๦�ܵ�������ĸ�������
echo ***************************************************************************
echo.
echo ����"1"��ת�����Ļ��������Ƶ������ģ�Ĭ�ϣ�
echo ����"2"���������������������ļ���
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_roma=none"
if /i "%bs%"=="1" set "v_roma=TRUE"
if /i "%bs%"=="2" set "v_roma=FALSE"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_roma%"=="none" echo �����ѡ��
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
echo ����Ϸ˵���д�������ģ����﷭���Ӣ��
echo *****************************************************************************
echo.
echo ע�⣺��romaji�ķ��벻ͬ��NSCB��GOOGLE TRANSLATE����API����
echo.
echo ����"1"������������Ĭ�ϣ�
echo ����"2"��������nutdb�ļ������������
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_trans=none"
if /i "%bs%"=="1" set "v_trans=TRUE"
if /i "%bs%"=="2" set "v_trans=FALSE"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

if "%v_trans%"=="none" echo �����ѡ��
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
echo �����̲߳����Ĺ����߳���
echo ***************************************************************************
echo ��ǰ�����������������ݿ⹹��ģʽ
echo �йظ���ֵ����ʹ���ı��༭���༭NSCB_options.cmd
echo.
echo ����"1"��ʹ��1���̣߳�Ĭ�ϻ�û�м��
echo ����"2"��ʹ��5���߳�
echo ����"3"��ʹ��10���߳�
echo ����"4"��ʹ��20���߳�
echo ����"5"��ʹ��30���߳�
echo ����"6"��ʹ��40���߳�
echo ����"7"��ʹ��50���߳�
echo ����"8"��ʹ��60���߳�
echo ����"9"��ʹ��70���߳�
echo ����"10"��ʹ��80���߳�
echo ����"11"��ʹ��90���߳�
echo ����"12"��ʹ��100���߳�
echo.
echo ����"b"������ȫ��ѡ��
echo ����"0"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
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

if "%v_workers%"=="none" echo �����ѡ��
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
echo �û�ѹ��ѡ��
echo ***************************************************************************
echo ************************
echo ����ѹ������
echo ************************
echo ����1��22֮���ѹ������
echo ע��
echo  + Level 1 - ���ٵ�ѹ����С
echo  + Level 22 - ���������õ�ѹ����
echo  Levels 10-17 �Ƽ�
echo.
echo ����"b"������ȫ��ѡ��
echo ����"x"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_nszlevels=none"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="x" goto sc1
if /i "%bs%"=="e" goto salida

set "v_nszlevels=%bs%"
set v_nszlevels="compression_lv=%v_nszlevels%"
set v_nszlevels="%v_nszlevels%"
if "%v_nszlevels%"=="none" echo �����ѡ��
if "%v_nszlevels%"=="none" echo.
if "%v_nszlevels%"=="none" goto op_NSZ1
%pycommand% "%listmanager%" -cl "%op_file%" -ln "158" -nl "set %v_nszlevels%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "158" -nl "Line in config was changed to: "
:op_NSZ2
echo.
echo *******************************************************
echo ����Ҫʹ�õ��߳���
echo *******************************************************
echo ����Ҫ��0��4֮��ʹ�õ��߳���
echo ע��
echo + ͨ��ʹ���̣߳������ܻ���һЩ���٣����ή��ѹ����
echo + 22����4���߳̿��ܻ�ľ������ڴ�
echo + ���������߳�ѹ������Ϊ17��������ʧѹ����
echo.
echo ����"b"������ȫ��ѡ��
echo ����"x"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set "v_nszthreads=none"

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="x" goto sc1
if /i "%bs%"=="e" goto salida

set "v_nszthreads=%bs%"
set v_nszthreads="compression_threads=%v_nszthreads%"
set v_nszthreads="%v_nszthreads%"
if "%v_nszthreads%"=="none" echo �����ѡ��
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
echo ����XCI�ĸ�ʽ
echo *******************************************************
echo.
echo ����"1"������ΪXCZ-�����޼���Ĭ��ֵ��
echo ����"2"������ΪNSZ
echo.
echo ��ס��tinfoil����ͬʱ��װ���ָ�ʽ����˲����鵼��Ϊnsz��
echo ���������뽫������Ϊnsz���������ַ�ʽ���в�������ʹ��Ϸ�е�nca�ļ��ɻָ���
echo ע�⣺��ǰ���˻�ԭ��Ҫ���Ƚ��ļ���ѹ��Ϊnsp�����õ�ֱ�ӻ�ԭ���ܽ��ܿ���ӽ�����

echo.echo.
echo ����"b"������ȫ��ѡ��
echo ����"x"���������ò˵�
echo ����"e"������������
echo ...........................................................................
echo.
set "v_xcz_export=none"
set /p bs="��������ѡ�� "

if /i "%bs%"=="b" goto sc3
if /i "%bs%"=="x" goto sc1
if /i "%bs%"=="e" goto salida

if /i "%bs%"=="1" set "v_xcz_export=xcz"
if /i "%bs%"=="2" set "v_xcz_export=nsz"
set v_xcz_export="xci_export=%v_xcz_export%"
set v_xcz_export="%v_xcz_export%"
if "%v_xcz_export%"=="none" echo �����ѡ��
if "%v_xcz_export%"=="none" echo.
if "%v_xcz_export%"=="none" goto op_NSZ3
%pycommand% "%listmanager%" -cl "%op_file%" -ln "160" -nl "set %v_xcz_export%"
echo.
%pycommand% "%listmanager%" -rl "%op_file%" -ln "160" -nl "Line in config was changed to: "
pause
goto sc3

:def_set1
echo.
echo **�Զ�ģʽѡ��**
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
echo **ȫ��ѡ��**
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
echo **��ǰ�Զ�ģʽѡ��**
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
echo **��ǰȫ��ѡ��**
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
echo ������ȷ����Կsha256ɢ��ֵ��֤keys.txt�е���Կ
echo ***************************************************************************

%pycommand% "%squirrel%" -nint_keys "%dec_keys%"

echo ...........................................................................
echo ����"0"���������ò˵�
echo ����"1"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set bs=%bs:"=%

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

:salida
exit /B

:update_nutdb
cls
call :logo
echo ***************************************************************************
echo ǿ��NUT_DB����
echo ***************************************************************************

%pycommand% "%squirrel_lb%" -lib_call nutdb force_refresh

echo ...........................................................................
echo ����"0"���������ò˵�
echo ����"1"������������
echo ...........................................................................
echo.
set /p bs="��������ѡ�� "
set bs=%bs:"=%

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida

:google_drive
cls
call :logo
echo ********************************************************
echo �ȸ����� - ����
echo ********************************************************
echo ����"1"��ע���˻�
echo ����"2"��ˢ��Զ�̿��ļ�����
echo.
echo ����"0"���������ò˵�
echo ����"e"������������
echo .......................................................
echo.
set /p bs="��������ѡ�� "
if /i "%bs%"=="1" goto op_google_drive_account
if /i "%bs%"=="2" ( %pycommand% "%squirrel_lb%" -lib_call workers concurrent_cache )
if /i "%bs%"=="2" goto google_drive

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida
echo �����ѡ��
echo.
goto google_drive

:op_google_drive_account
cls
call :logo
echo ***************************************************************************
echo ע��ȸ������˻�
echo ***************************************************************************
echo ����Ҫһ��certificate.json�������Գ�Ϊcertificate.json���������ɵ����Ƶ�����.json��
echo certificate.json����������ʻ�һ��ʹ�����������ƣ�����������������ɸ��ʻ����ʻ�ʹ�õ��ʻ���ͬ������յ����档
echo ϵͳʵ��Ϊ��ƾ���ļ����������ƾ��json���Ķ���NSCBһ��ַ����ĵ������˽���λ�ȡ���ļ���
echo.
echo ע�⣺���ڴ˲�������������ƽ����ڱ������ƺ�·����
echo.
echo ʾ������Ϊ"drive"�����ƽ�ʹ��drive:/folder/file.nsp֮���·��
echo.
set /p bs="��������ʹ�õ�����·��: "
set "token=%bs%"
echo.
%pycommand% "%squirrel_lb%" -lib_call Drive.Private create_token -xarg "%token%" headless="False"
pause
goto google_drive

:interface
cls
call :logo
echo ********************************************************
echo �Զ�ģʽ - ����
echo ********************************************************
echo ����"1"���������ӻ�����
echo ����"2"��ѡ������������ý���
echo ����"3"��ͣ����Ƶ����
echo ����"4"�����ö˿�
echo ����"5"����������
echo ����"6"������GUI����̨����
echo.
echo ����"d"����ԭĬ�Ͻ�������
echo ����"0"���������ò˵�
echo ����"e"������������
echo .......................................................
echo.
set /p bs="��������ѡ�� "
if /i "%bs%"=="1" goto op_interface_consolevisibility
if /i "%bs%"=="2" goto op_interface_browser
if /i "%bs%"=="3" goto op_interface_video_playback
if /i "%bs%"=="4" goto op_interface_port
if /i "%bs%"=="5" goto op_interface_host
if /i "%bs%"=="6" goto op_interface_noconsole

if /i "%bs%"=="d" goto op_interface_defaults
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida
echo �����ѡ��
echo.
goto interface

:op_interface_consolevisibility
cls
call :logo
echo ***************************************************************************
echo ����INTERFACE.BAT��С����
echo ***************************************************************************
echo ���Ƶ��Կ���̨�Ƿ���Web����һ����С������
echo ����
echo.
echo ����"1"����ʼ��С��
echo ����"2"������ʼ��С��
echo ����"D"��Ĭ�ϣ�δ��С����
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ؽ���˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ�� "
set "v_interface=none"
if /i "%bs%"=="1" set "v_interface=yes"
if /i "%bs%"=="2" set "v_interface=no"
if /i "%bs%"=="d" set "v_interface=no"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

if "%v_interface%"=="none" echo �����ѡ��
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
echo ѡ�����������������
echo ***************************************************************************
echo ѡ����������������������
echo ѡ�
echo 1. �Զ���˳������ztools\chromium��ϵͳ�а�װ��������Ļ��������õġ�
echo ������squirrel������˳���Զ����õģ�
echo    I.   ztools\chromium��Chromium��Я���Slimjet��Я�棩
echo    II.  ϵͳ�а�װ��Chrome��Chromium
echo    III. Microsoft Edge �����Ƽ���
echo 2. ϵͳĬ�ϡ�ʹ��Ĭ��ϵͳ������������Եͣ�
echo 3. ͨ�����·���֮һ��ԭʼ·������Ϊ��chromium�������
echo    I.   ������ľ���·������.exe��β
echo    II.  .lnk�ļ��ľ���·����Windows��ݷ�ʽ��
echo    III. ztools\chromium�е�.lnk�ļ������ƣ���.lnk��β��
echo         ����: brave.lnk
echo         �⽫��ȡztools\chromium\brave.lnk���ض�������brave�������exe·��
echo.
echo ����"1"��"d"�����ñ���Ϊ�Զ�
echo ����"2"�����ñ���ΪϵͳĬ��
echo ����3.III������shortcut.lnk����
echo �����������3.I��3.II�����Ŀ�ݷ�ʽ�ľ���·��
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ؽ���˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ�� "
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
echo ͣ����Ƶ����
echo ***************************************************************************
echo ͣ��Nintendo.com��Ƶ��HLS��������
echo ��������HLS javascript�������������������ľɼ����
echo.
echo ����"1"��������Ƶ����
echo ����"2"��ͣ����Ƶ����
echo ����"D"��Ĭ�ϣ�����С����
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ؽ���˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ�� "
set "v_video_playback=none"
if /i "%bs%"=="1" set "v_video_playback=true"
if /i "%bs%"=="2" set "v_video_playback=false"
if /i "%bs%"=="d" set "v_video_playback=false"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

if "%v_video_playback%"=="none" echo �����ѡ��
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
echo ѡ�����˿�
echo ***************************************************************************
echo.
echo ע�⣬"rg8000"ָλ��8000��8999֮��Ŀ��Ŷ˿�, ������ͬʱ�򿪶�����洰�ڡ�����Ĭ�ϲ���
echo.
echo ����"1"��"d"�����ö˿ڱ���Ϊrg8000
echo ������һ���˿ں�
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ؽ���˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
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
echo ѡ�����˿�
echo ***************************************************************************
echo Localhost. ������ڱ��ؿɼ���Ĭ�ϣ�
echo 0.0.0.0. ���������ͬһ�����Ͽɼ�
echo.
echo ����"1"��"d"����������ΪLOCALHOST
echo ����"2"����������Ϊ0.0.0.0
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ؽ���˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_interface_host=none"
if /i "%bs%"=="1" set "v_interface_host=localhost"
if /i "%bs%"=="2" set "v_interface_host=0.0.0.0"
if /i "%bs%"=="d" set "v_interface_host=localhost"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

if "%v_interface_host%"=="none" echo �����ѡ��
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
echo ���ؽ���Ŀ���̨
echo ***************************************************************************
echo NoConsole=True. �����������̨��������̨��ӡ�ض��򵽽��棬����Ĭ�ϲ�����
echo NoConsole=False. ��ʾ�������̨
echo.
echo ����"1"��"d"������NOCONSOLEΪTRUE
echo ����"2"������NOCONSOLEΪFALSE
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ؽ���˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_interface_noconsole=none"
if /i "%bs%"=="1" set "v_interface_noconsole=true"
if /i "%bs%"=="2" set "v_interface_noconsole=false"
if /i "%bs%"=="d" set "v_interface_noconsole=true"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto interface
if /i "%bs%"=="e" goto salida

if "%v_interface_noconsole%"=="none" echo �����ѡ��
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
::����
set v_interface="start_minimized=no"
set v_interface="%v_interface%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "17" -nl "set %v_interface%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "17" -nl "Line in config was changed to: "
echo.
::�����·��
set v_interface_browser="browserpath=auto"
set v_interface_browser="%v_interface_browser%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "31" -nl "set %v_interface_browser%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "31" -nl "Line in config was changed to: "
echo.
::��Ƶ����
set v_video_playback="videoplayback=true"
set v_video_playback="%v_video_playback%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "35" -nl "set %v_video_playback%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "35" -nl "Line in config was changed to: "
::�˿�
set v_interface_port="port=rg8000"
set v_interface_port="%v_interface_port%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "48" -nl "set %v_interface_port%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "48" -nl "Line in config was changed to: "
::����
set v_interface_host="host=localhost"
set v_interface_host="%v_interface_host%"
%pycommand% "%listmanager%" -cl "%opt_interface%" -ln "55" -nl "set %v_interface_host%"
%pycommand% "%listmanager%" -rl "%opt_interface%" -ln "55" -nl "Line in config was changed to: "

::GUI����̨
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
echo ������ - ����
echo ********************************************************
echo ����"1"���޸��������ӻ�����
echo ����"2"����ֹ��Ƶ����
echo ����"3"�����ö˿ں�
echo ����"4"����������
echo ����"5"������GUI����̨����
echo ����"6"������SSL����
echo.
echo ����"d"���ָ�������Ĭ������
echo ����"0"���������ò˵�
echo ����"e"������������
echo .......................................................
echo.
set /p bs="��������ѡ��"
if /i "%bs%"=="1" goto op_server_consolevisibility
if /i "%bs%"=="2" goto op_server_video_playback
if /i "%bs%"=="3" goto op_server_port
if /i "%bs%"=="4" goto op_server_host
if /i "%bs%"=="5" goto op_server_noconsole
if /i "%bs%"=="6" goto op_server_ssl

if /i "%bs%"=="d" goto op_server_defaults
if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="e" goto salida
echo �����ѡ��
echo.
goto server

:op_server_consolevisibility
cls
call :logo
echo ***************************************************************************
echo ����SERVER.BAT��С��?
echo ***************************************************************************
echo ���Ƶ��Կ���̨�Ƿ���Web����һ����С������
echo.
echo ����"1"����С������
echo ����"2"����������
echo ����"d"��Ĭ�ϣ�����С��������
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ط������˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_server_vis=none"
if /i "%bs%"=="1" set "v_server_vis=yes"
if /i "%bs%"=="2" set "v_server_vis=no"
if /i "%bs%"=="d" set "v_server_vis=no"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_server_vis%"=="none" echo �����ѡ��
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
echo ������Ƶ����
echo ***************************************************************************
echo ����HLS����������Nintendo.com��Ƶ��
echo �������ڿ��ܻ���HLS javascript��������ס�ľɼ����
echo.
echo ����"1"��������Ƶ����
echo ����"2"��������Ƶ����
echo ����"d"��Ĭ�ϣ����ã�
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ط������˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_video_playback=none"
if /i "%bs%"=="1" set "v_video_playback=true"
if /i "%bs%"=="2" set "v_video_playback=false"
if /i "%bs%"=="d" set "v_video_playback=false"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_video_playback%"=="none" echo �����ѡ��
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
echo ѡ��������˿�
echo ***************************************************************************
echo.
echo ע�⣺��rg8000��λ��8000��8999֮��Ŀ��Ŷ˿��ϣ�������ͬʱ�򿪶���ӿڴ��ڡ�����Ĭ�ϲ�����
echo.
echo ����"1"��"d"�����ñ���Ϊrg8000
echo ��������һ���˿ں�
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ط������˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
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
echo ���ý�������
echo ***************************************************************************
echo Localhost. ���������ڱ��ؿɼ���Ĭ�ϣ�
echo 0.0.0.0. ���������ͬһ�����Ͽɼ�
echo.
echo ����"1"��"d"����������ΪLOCALHOST
echo ����"2"����������Ϊ0.0.0.0
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ط������˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_server_host=none"
if /i "%bs%"=="1" set "v_server_host=localhost"
if /i "%bs%"=="2" set "v_server_host=0.0.0.0"
if /i "%bs%"=="d" set "v_server_host=localhost"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_server_host%"=="none" echo �����ѡ��
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
echo ���ط������Ŀ���̨
echo ***************************************************************************
echo NoConsole=True. �����������̨��������̨��ӡ�ض��򵽷�����������Ĭ�ϲ�����
echo NoConsole=False. ��ʾ�������̨
echo.
echo ����"1"��"d"������NOCONSOLEΪTRUE
echo ����"2"������NOCONSOLEΪFALSE
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ط������˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_server_noconsole=none"
if /i "%bs%"=="1" set "v_server_noconsole=true"
if /i "%bs%"=="2" set "v_server_noconsole=false"
if /i "%bs%"=="d" set "v_server_noconsole=true"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_server_noconsole%"=="none" echo �����ѡ��
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
echo SSLЭ��
echo ***************************************************************************
echo ���Ϊtrue�����������ʹ��httpsЭ�飻
echo ���zconfig�д�����ȷǩ����certificate.pem��key.pem�ļ��������ʹ�ø÷�������
echo ����Ҳ�����Щ�ļ���squirrel�����˵�http��
echo.
echo ����"1"��"D"������SSLΪOFF��Ĭ�ϣ�
echo ����"2"������SSLΪON
echo.
echo ����"0"���������ò˵�
echo ����"b"�����ط������˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_server_SSL=none"
if /i "%bs%"=="1" set "v_server_SSL=false"
if /i "%bs%"=="2" set "v_server_SSL=true"
if /i "%bs%"=="d" set "v_server_SSL=false"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto server
if /i "%bs%"=="e" goto salida

if "%v_server_SSL%"=="none" echo �����ѡ��
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
::����
set v_interface="start_minimized=no"
set v_interface="%v_interface%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "17" -nl "set %v_interface%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "17" -nl "Line in config was changed to: "
echo.
::��Ƶ����
set v_video_playback="videoplayback=true"
set v_video_playback="%v_video_playback%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "21" -nl "set %v_video_playback%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "21" -nl "Line in config was changed to: "
::�˿�
set v_interface_port="port=rg8000"
set v_interface_port="%v_interface_port%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "29" -nl "set %v_interface_port%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "29" -nl "Line in config was changed to: "
::����
set v_interface_host="host=localhost"
set v_interface_host="%v_interface_host%"
%pycommand% "%listmanager%" -cl "%opt_server%" -ln "36" -nl "set %v_interface_host%"
%pycommand% "%listmanager%" -rl "%opt_server%" -ln "36" -nl "Line in config was changed to: "
::GUI����̨
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
echo MTP - ����
echo ********************************************************
echo ����"1"��ΪԤװ����У��
echo ����"2"���Զ������豸ʱ����ѡ��NSZ
echo ����"3"�������׼���ܰ�װ
echo ����"4"�����Զ������а�װ����ʱ�ų�XCI
echo ����"5"��SD��EMMC֮����л�ȡ���ڿ��ÿռ�
echo ����"6"����װǰ������̨�ϵĹ̼�
echo ����"7"����Ҫʱ�޲��ļ�����Կ����
echo ����"8"�����ڰ�װǰ����Ƿ��Ѱ�װ��������
echo ����"9"���ڰ�װǰ����Ƿ�װ�˾ɵĸ��»�DLC
echo ����"10"����ת��ʱѡ���ļ�������
echo ����"11"����ת���浵ʱ��ѡ���Ƿ����titleid�Ͱ汾��Ϣ
echo ����"12"��ѡ����ν��ļ���ӵ��������ӵ�Զ�̸��ٻ���
echo ����"13"�����Ĳ����ļ���XCI��װ�淶
echo.
echo ����"d"���ָ�MTPĬ������
echo ����"0"���������ò˵�
echo ����"e"������������
echo .......................................................
echo.
set /p bs="��������ѡ��"
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
echo �����ѡ��
echo.
goto MTP

:op_MTP_verification
cls
call :logo
echo ***************************************************************************
echo �����ļ�У��Ԥ��װ
echo ***************************************************************************
echo False: ����У��
echo Level 2 verification: NCA�ɶ���û���ļ���ʧ��titlekey����ȷ�ģ�����ǩ��1���ԺϷ�����֤����Դ����Ĭ�ϣ�
echo Hash: Level 2��֤ + Hash��֤
echo.
echo ����"1"��"D"������VERIFICATIONΪLEVEL2
echo ����"2"������VERIFICATIONΪHASH
echo ����"3"������У��
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_mtp_verification=none"
if /i "%bs%"=="1" set "v_mtp_verification=True"
if /i "%bs%"=="2" set "v_mtp_verification=Hash"
if /i "%bs%"=="3" set "v_mtp_verification=False"
if /i "%bs%"=="d" set "v_mtp_verification=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_mtp_verification%"=="none" echo �����ѡ��
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
echo �ڼ����е��¸��º�DLCʱ����ѡ��NSZ������NSP
echo ***************************************************************************
echo.
echo ����"1"��"D"������ѡ��NSZ
echo ����"2"��������ѡ��NSZ
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_prioritize_NSZ=none"
if /i "%bs%"=="1" set "v_MTP_prioritize_NSZ=True"
if /i "%bs%"=="3" set "v_MTP_prioritize_NSZ=False"
if /i "%bs%"=="d" set "v_MTP_prioritize_NSZ=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_prioritize_NSZ%"=="none" echo �����ѡ��
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
echo ���Զ����¼�����ų�XCI�Ի�ȡ������
echo ***************************************************************************
echo.
echo ����"1"��"D"�����Զ����¼�����ų�XCI
echo ����"2"�������Զ����¼�����ų�XCI
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_exclude_xci_autinst=none"
if /i "%bs%"=="1" set "v_MTP_exclude_xci_autinst=True"
if /i "%bs%"=="2" set "v_MTP_exclude_xci_autinst=False"
if /i "%bs%"=="d" set "v_MTP_exclude_xci_autinst=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_exclude_xci_autinst%"=="none" echo �����ѡ��
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
echo �����豸�ϵĿռ��Զ����Ľ���
echo ***************************************************************************
echo ����ѡ�����еĿռ䲻��ʱ�����SD��EMMC֮��Ϊtrue������ġ����Ϊfalse����������װ��
echo.
echo ����"1"��"D"�������豸�ϵĿռ���Ľ���
echo ����"2"���������豸�ϵĿռ���Ľ���
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_aut_ch_medium=none"
if /i "%bs%"=="1" set "v_MTP_aut_ch_medium=True"
if /i "%bs%"=="2" set "v_MTP_aut_ch_medium=False"
if /i "%bs%"=="d" set "v_MTP_aut_ch_medium=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_aut_ch_medium%"=="none" echo �����ѡ��
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
echo ����豸�Ϻ��ļ��ϵĹ̼�
echo ***************************************************************************
echo.
echo ����"1"��"D"�������̼���Ĭ�ϣ�
echo ����"2"�����̼�
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_chk_fw=none"
if /i "%bs%"=="1" set "v_MTP_chk_fw=False"
if /i "%bs%"=="2" set "v_MTP_chk_fw=True"
if /i "%bs%"=="d" set "v_MTP_chk_fw=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_chk_fw%"=="none" echo �����ѡ��
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
echo ����豸�Ϻ��ļ��ϵĹ̼�
echo ***************************************************************************
echo �ڿ���̨�ϼ��̼����ļ���hte���򽫻��ڴ�ѡ������Ƿ�Ӧ�޲��������ļ���
echo ע�⣺Ŀǰ����ͨ��MTP�����ļ�֮ǰ����Ҫ������һ�����ļ�����Ϊ��δ��mtp�ҹ���ʵ�ֶ�̬�޲����Ĺ��ܡ�
echo.
echo ����"1"��"D"�������ļ��򲹶���Ĭ�ϣ�
echo ����"2"�����ļ��򲹶�
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_prepatch_kg=none"
if /i "%bs%"=="1" set "v_MTP_prepatch_kg=False"
if /i "%bs%"=="2" set "v_MTP_prepatch_kg=True"
if /i "%bs%"=="d" set "v_MTP_prepatch_kg=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_prepatch_kg%"=="none" echo �����ѡ��
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
echo ����Ƿ������豸�а�װ������Ϸ
echo ***************************************************************************
echo ����豸��װ�л�����Ϸ������������������װ�����ȡ�������װ�������ǡ�
echo.
echo ����"1"��"D"���Ѱ�װ����������Ϸ��Ĭ�ϣ�
echo ����"2"������鲢�����Ѱ�װ����Ϸ
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_prechk_Base=none"
if /i "%bs%"=="1" set "v_MTP_prechk_Base=True"
if /i "%bs%"=="2" set "v_MTP_prechk_Base=False"
if /i "%bs%"=="d" set "v_MTP_prechk_Base=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_prechk_Base%"=="none" echo �����ѡ��
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
echo �������Ƿ��Ѱ�װ���豸��
echo ***************************************************************************
echo ��������ѡ������豸���Ƿ���ڸ��»�dlc������汾���ڷ��а汾����
echo ��ɾ���ɵ�Ԥ��װ���ڰ�װ����֮ǰ���տռ䣨����豸�еİ汾���ڻ���ߣ�����������
echo ���ͣ�ã�������װ�������»�dlc�Լ����Ǿ�����ͬ�汾�ŵĸ��¡�
echo.
echo ����"1"��"D"���������������»��Ѿ���װ��dlc��Ĭ�ϣ�
echo ����"2"�������������»��Ѿ���װ��dlc
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_prechk_Upd=none"
if /i "%bs%"=="1" set "v_MTP_prechk_Upd=False"
if /i "%bs%"=="2" set "v_MTP_prechk_Upd=True"
if /i "%bs%"=="d" set "v_MTP_prechk_Upd=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_prechk_Upd%"=="none" echo �����ѡ��
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
echo ���ļ��л�ֱ�ӱ�����Ϸת��
echo ***************************************************************************
echo.
echo ����"1"��"D"������Ϸ�������ļ����У�Ĭ�ϣ�
echo ����"2"��ֱ�ӱ�����Ϸ
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_saves_Inline=none"
if /i "%bs%"=="1" set "v_MTP_saves_Inline=False"
if /i "%bs%"=="2" set "v_MTP_saves_Inline=True"
if /i "%bs%"=="d" set "v_MTP_saves_Inline=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_saves_Inline%"=="none" echo �����ѡ��
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
echo ��ӱ���Ͱ汾��ǩ�Ա�����Ϸ
echo ***************************************************************************
echo ����Ϊ���ڽ��б���ʱ֪���豸�ϵ���Ϸ�汾���Ա�����������⡣
echo.
echo ����"1"��"D"����titleid�Ͱ汾��ǩ��ӵ��ļ��У�Ĭ�ϣ�
echo ����"2"������titleid�Ͱ汾��ǩ��ӵ��ļ���
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_MTP_saves_AddTIDandVer=none"
if /i "%bs%"=="1" set "v_MTP_saves_AddTIDandVer=False"
if /i "%bs%"=="2" set "v_MTP_saves_AddTIDandVer=True"
if /i "%bs%"=="d" set "v_MTP_saves_AddTIDandVer=False"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_MTP_saves_AddTIDandVer%"=="none" echo �����ѡ��
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
echo ��ӱ���Ͱ汾��ǩ�Ա�����Ϸ
echo ***************************************************************************
echo ��Google�ƶ�Ӳ�̹������Ӱ�װ��ת����Ϸʱ��NSCB��Ҫ��Google�ƶ�Ӳ���ʻ����������������֤�ͻ����ļ������ã���ʵ�ָ��õļ����ԡ�
echo.
echo ������Ϸ�Ի������Ȩ�������ļ��У����������TRUECOPY��Ҳ���Ա���������⡣
echo �������TRUECOPY������Ϸ��Ϊ����������ӵ������ļ����У��⽫����ʹ��auth���Ƶ����ļ�����������������ӣ�������������⡣
echo.
echo ����"1"��"D"������TRUECOPY��Ĭ�ϣ�
echo ����"2"������TRUECOPY
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP����
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
set "v_op_MTP_pdrive_truecopy=none"
if /i "%bs%"=="1" set "v_op_MTP_pdrive_truecopy=True"
if /i "%bs%"=="2" set "v_op_MTP_pdrive_truecopy=False"
if /i "%bs%"=="d" set "v_op_MTP_pdrive_truecopy=True"

if /i "%bs%"=="0" goto sc1
if /i "%bs%"=="b" goto MTP
if /i "%bs%"=="e" goto salida

if "%v_op_MTP_pdrive_truecopy%"=="none" echo �����ѡ��
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
echo �Ա�׼���ܷ�ʽ��װ����NSP�ļ�
echo ***************************************************************************
echo ����ζ�Ž���װû��Ʊ֤�͹���Ȩ��NSP�ļ�����ʹ����̨�е�Ʊ֤���ָɾ���
echo.
echo ����"1"��"D"���ù���Ȩ��װ��Ĭ�ϣ�
echo ����"2"���Ա�׼���ܷ�ʽ��װ
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP�˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
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
echo �޲�NSP��XCI�İ�װ�淶
echo ***************************************************************************
echo �ɰ潫�����޲��ļ���ת������ļ���Ȼ���䴫�䵽����̨��
echo Spec1����һ����������̬�޲�����Spec1�����ļ���Ϊ�������������װ�Ĳ�ͬ�ļ���
echo.
echo ����"1"��"D"��ʹ��SPECIFICATION1��Ĭ�ϣ�
echo ����"2"��ʹ�ô�ͳ�淶
echo.
echo ����"0"���������ò˵�
echo ����"b"������MTP�˵�
echo ����"e"������������
echo.
set /p bs="��������ѡ��"
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
