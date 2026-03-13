@echo off

set PYTHON_MAIN="D:\Python\python3.10.9\python.exe"

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

