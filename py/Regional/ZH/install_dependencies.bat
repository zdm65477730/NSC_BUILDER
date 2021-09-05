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
ECHO 安装依赖项
ECHO.
%pycommand% -m pip install --upgrade pip
%pycommand% -m pip install wheel
%pycommand% -m pip install urllib3 unidecode tqdm bs4 tqdm requests image pywin32 pycryptodome pykakasi googletrans chardet eel bottle zstandard colorama google-auth-httplib2 google-auth-oauthlib windows-curses oauth2client comtypes
%pycommand% -m pip install --upgrade google-api-python-client
ECHO.
ECHO **********************************************************************************
ECHO ---重要：在继续之前，请检查所有依赖项是否都已经正确安装了---
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
ECHO                         任天堂SWITCH清理打包工具
ECHO                      (多重XCI打包和更多功能)
ECHO -------------------------------------------------------------------------------------
ECHO =============================    JULESONTHEROAD开发     =============================
ECHO -------------------------------------------------------------------------------------
exit /B