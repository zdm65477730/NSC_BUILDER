@ECHO OFF
set "pycommand=py -3"
set "op_file=%~dp0zconfig/NSCB_options.cmd"
call :program_logo
setlocal
if exist "%op_file%" call "%op_file%" 	  
endlocal & ( 
set "pycommand=%pycommand%"
)

ECHO.
ECHO ��װ������
ECHO.
%pycommand% -m pip install --upgrade pip
%pycommand% -m pip install wheel
%pycommand% -m pip install urllib3 unidecode tqdm bs4 tqdm requests image pywin32 pycryptodome pykakasi googletrans chardet eel bottle zstandard colorama google-auth-httplib2 google-auth-oauthlib windows-curses oauth2client comtypes
%pycommand% -m pip install --upgrade google-api-python-client
ECHO.
ECHO **********************************************************************************
ECHO ---��Ҫ���ڼ���֮ǰ�����������������Ƿ��Ѿ���ȷ��װ��---
ECHO **********************************************************************************
ECHO.
PAUSE
exit /B

:program_logo

ECHO                                        __          _ __    __         
ECHO                  ____  _____ ____     / /_  __  __(_) /___/ /__  _____
ECHO                 / __ \/ ___/ ___/    / __ \/ / / / / / __  / _ \/ ___/
ECHO                / / / (__  ) /__     / /_/ / /_/ / / / /_/ /  __/ /    
ECHO               /_/ /_/____/\___/____/_.___/\__,_/_/_/\__,_/\___/_/     
ECHO                              /_____/                                  
ECHO -------------------------------------------------------------------------------------
ECHO                         ������SWITCH����������
ECHO                      (����XCI����͸��๦��)
ECHO -------------------------------------------------------------------------------------
ECHO =============================    JULESONTHEROAD����     =============================
ECHO -------------------------------------------------------------------------------------
exit /B