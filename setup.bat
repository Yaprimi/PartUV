@echo off

REM ===================================================================================================================
REM Ask for Python 3.10 folder
REM ===================================================================================================================

echo Enter the path to your Python 3.10 directory (e.g. C:\Python310\)
echo.
:get_python_path
set /p PYTHON_FOLDER=Python 3.10 Directory: 

if not exist "%PYTHON_FOLDER%\python.exe" (
    echo.
	echo   Can't find any python executable here '%PYTHON_FOLDER%\python.exe'.
    echo.
	goto get_python_path    
) else (
	set PYTHON_MAIN=%PYTHON_FOLDER%\python.exe
)

REM ---------------------------------------------------------------------------------------------------
REM VENV & PIP
REM ---------------------------------------------------------------------------------------------------

%PYTHON_MAIN% -m venv .venv

call .venv\Scripts\activate

call python -m pip install --upgrade pip
call python -m pip install wheel

pip install -r requirements.txt

REM ---------------------------------------------------------------------------------------------------
REM DOWNLOAD MODEL
REM ---------------------------------------------------------------------------------------------------

wget https://huggingface.co/mikaelaangel/partfield-ckpt/resolve/main/model_objaverse.ckpt ./

pause

