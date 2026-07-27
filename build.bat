@echo off

:: Needed VCPKG installs to build PartUV on Windows:

:: .\vcpkg install yaml-cpp:x64-windows
:: .\vcpkg install cgal:x64-windows
:: .\vcpkg install easy-profiler:x64-windows
:: .\vcpkg install tbb:x64-windows
:: .\vcpkg install pybind11:x64-windows
:: .\vcpkg install eigen3:x64-windows libigl:x64-windows
:: .\vcpkg install nlohmann-json:x64-windows

setlocal

:: Repo root (this script's own folder) -- matches the layout produced by
:: bootstrap_env.ps1, where CMake/Python all live under toolchain\ next to
:: this script.
set "ROOT=%~dp0"

:: --- Preconditions: this script must be run from a console where
:: activate_env.bat has ALREADY been called (it sets up vcvars/CUDA/Windows
:: SDK/VCPKG_ROOT). Running this standalone gives a confusing CMake error
:: instead of a clear one -- check up front instead.
where cl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] cl.exe not found in PATH.
    echo         Run "call activate_env.bat" first, from this same console,
    echo         before running build.bat.
    pause
    exit /b 1
)
if not defined VCPKG_ROOT (
    echo [ERROR] VCPKG_ROOT is not set.
    echo         Run "call activate_env.bat" first -- it aliases vcpkg onto a
    echo         short subst drive letter and sets VCPKG_ROOT to it. Without
    echo         this, vcpkg's CGAL/gmp/mpfr ports fail to build because this
    echo         repo's own path contains spaces.
    pause
    exit /b 1
)
if not exist "%VCPKG_ROOT%\vcpkg.exe" (
    echo [ERROR] %VCPKG_ROOT%\vcpkg.exe not found.
    echo         VCPKG_ROOT is set to "%VCPKG_ROOT%" but vcpkg.exe isn't there --
    echo         the subst mapping from activate_env.bat may not have taken.
    echo         Re-run "call activate_env.bat" and try again.
    pause
    exit /b 1
)
where nvcc.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] nvcc.exe not found in PATH.
    echo         Run "call activate_env.bat" first -- it sets CUDA_PATH/PATH
    echo         for the local CUDA toolchain.
    pause
    exit /b 1
)
:: activate_env.bat's local CUDA toolchain (conda-forge cuda-nvcc, see the
:: Ninja-generator comment above) lives under toolchain\conda\Library, not
:: toolchain\cuda -- that old path doesn't exist, so anything relying on it
:: (including a stale CUDA_PATH some earlier env picked up) silently falls
:: through to whatever system-wide CUDA Toolkit happens to be installed
:: (e.g. "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9"). Force
:: CUDA_PATH to the correct local location so both CMake and this script
:: agree on which CUDA install is actually being used.
set "CUDA_PATH=%ROOT%toolchain\conda\Library"
set "CUDA_BIN_DIR="
if exist "%CUDA_PATH%\bin\nvcc.exe" set "CUDA_BIN_DIR=%CUDA_PATH%\bin\"
if not defined CUDA_BIN_DIR (
    for /f "delims=" %%n in ('where nvcc.exe') do if not defined CUDA_BIN_DIR set "CUDA_BIN_DIR=%%~dpn"
)

set PATH=%ROOT%toolchain\cmake\bin\;%PATH%
set PYTHON_MAIN=%ROOT%toolchain\python

:: CONFIGURATION
set "target_path=all_build\release"
set "main_file=main.cpp"
:: NOTE: vcpkg is aliased onto a short subst drive letter by activate_env.bat
:: (VCPKG_ROOT), specifically because this repo's own path contains spaces and
:: several vcpkg ports (gmp, mpfr -- anything built via MSYS/autoreconf) fail
:: outright when their build path does. Route through %VCPKG_ROOT%, not
:: through %ROOT%toolchain\..., or you'll hit that exact failure again.
set "VCPKG_PATH=%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake"

echo [1/3] Cleaning and Configuring...
if exist "%target_path%" rd /s /q "%target_path%"
mkdir "%target_path%"
pushd "%target_path%"

:: Use -S (Source) and -B (Build) explicitly to avoid path confusion
::
:: Generator: Ninja, not "Visual Studio 17 2022". The VS generator compiles
:: CUDA through MSBuild, which needs CUDA's "Visual Studio Integration"
:: (BuildCustomizations\CUDA *.props/targets) copied into the VS install --
:: that integration is installed ONLY by NVIDIA's official CUDA Toolkit .exe,
:: never by conda-forge's cuda-nvcc package (which bootstrap_env.ps1 uses
:: deliberately, to keep CUDA local/isolated instead of a system-wide
:: install). Ninja calls nvcc.exe directly and doesn't need any of that.
cmake -G Ninja ^
      -DCMAKE_TOOLCHAIN_FILE="%VCPKG_PATH%" ^
      -DPYTHON_EXECUTABLE="%PYTHON_MAIN%\python.exe" ^
      -DPYTHON_INCLUDE_DIR="%PYTHON_MAIN%\include" ^
      -DPYTHON_LIBRARY="%PYTHON_MAIN%\libs\python310.lib" ^
      -DMAIN_FILE="%main_file%" ^
      -DCMAKE_BUILD_TYPE=Release ^
      -DUSE_ALL_SRC_FILES=ON ^
      -DENABLE_PROFILING=OFF ^
      -DOpenMP_CUDA_FOUND=ON ^
      -S ../.. -B .

if %errorlevel% neq 0 (
    echo [ERROR] Configuration failed.
    popd
    pause
    exit /b %errorlevel%
)

echo [2/3] Compiling...
:: --config is a multi-config-generator concept (VS/Xcode) -- Ninja is
:: single-config and already got Release via -DCMAKE_BUILD_TYPE above, so
:: it's dropped here instead of silently ignored by cmake.
cmake --build . -j %NUMBER_OF_PROCESSORS%
if %errorlevel% neq 0 (
    echo [ERROR] Build failed.
    popd
    pause
    exit /b %errorlevel%
)

popd

:: --- No "cmake --install" is run by this project's CMakeLists (confirmed --
:: the fork never calls it either), so the compiled _core*.pyd is left sitting
:: in the build tree instead of next to partuv\__init__.py where `import partuv`
:: needs it. Do that copy here instead of leaving it as a manual step.
:: _core*.pyd dynamically links against the vcpkg-built shared libs (yaml-cpp,
:: tbb, easy-profiler, gmp/mpfr via CGAL, etc). Those .dll files land in
:: vcpkg's own "installed" tree and get copied by the linker into
:: %target_path%\ next to the .pyd (see the "-> ...done" lines CMake just
:: printed above) -- but never into partuv\ itself, so `import partuv` fails
:: with a bare "DLL load failed" (no missing-symbol name) unless we copy them
:: there ourselves. NOTE: this whole step must stay free of "::" comments
:: inside any parenthesized if/for block below -- cmd.exe's parser breaks on
:: a ")" appearing inside a "::" comment that's nested in a block, and fails
:: with ". was unexpected at this time" instead of a useful error.
:: MSVC_REDIST_ROOT and CUDA_BIN_DIR are set here, at top level -- NOT inside
:: the parenthesized if/else block below. A variable set with `set` inside a
:: parenthesized block and read with %...% in that same block still sees its
:: OLD value, because cmd.exe expands the whole block up front before running
:: any of it (this bit us with MSVC_REDIST_ROOT coming out empty). Setting it
:: here, before the block starts, avoids that.
set "MSVC_REDIST_ROOT=%ROOT%toolchain\vs\VC\Redist\MSVC"
echo [3/3] Placing built _core*.pyd and its dependent DLLs next to partuv\__init__.py ...
set "PYD_SRC="
for /f "delims=" %%f in ('dir /s /b "%target_path%\_core*.pyd" 2^>nul') do set "PYD_SRC=%%f"
if not defined PYD_SRC (
    echo [WARN] Could not find a built _core*.pyd under %target_path%\
    echo        Build may have failed silently, or the output filename/pattern changed --
    echo        check %target_path%\ manually.
) else (
    copy /y "%PYD_SRC%" "%ROOT%partuv\" >nul
    if errorlevel 1 (
        echo [WARN] Found %PYD_SRC% but could not copy it to %ROOT%partuv\ -- copy it manually.
    ) else (
        echo   Copied %PYD_SRC% -^> %ROOT%partuv\
        echo   Copying dependent DLLs from the build tree...
        for /f "delims=" %%d in ('dir /s /b "%target_path%\*.dll" 2^>nul') do (
            copy /y "%%d" "%ROOT%partuv\" >nul
        )
        echo   Copying dependent DLLs from vcpkg release bin...
        if exist "%VCPKG_ROOT%\installed\x64-windows\bin" (
            for %%d in (%VCPKG_ROOT%\installed\x64-windows\bin\*.dll) do (
                copy /y "%%~fd" "%ROOT%partuv\" >nul
            )
        ) else (
            echo   [WARN] %VCPKG_ROOT%\installed\x64-windows\bin not found -- skipped.
        )
        echo   Copying python310.dll ^(needed next to the .pyd -- LOAD_WITH_ALTERED_SEARCH_PATH
        echo   means Python does NOT fall back to the python.exe folder for this^)...
        if exist "%PYTHON_MAIN%\python310.dll" (
            copy /y "%PYTHON_MAIN%\python310.dll" "%ROOT%partuv\" >nul
        ) else (
            echo   [WARN] %PYTHON_MAIN%\python310.dll not found -- skipped.
        )
        echo   Copying CUDA runtime DLLs...
        if defined CUDA_BIN_DIR (
            if exist "%CUDA_BIN_DIR%cudart64*.dll" (
                for %%d in ("%CUDA_BIN_DIR%cudart64*.dll") do (
                    copy /y "%%~fd" "%ROOT%partuv\" >nul
                )
            ) else (
                echo   [WARN] No cudart64*.dll found under %CUDA_BIN_DIR% -- skipped.
            )
        ) else (
            echo   [WARN] Could not resolve nvcc.exe's directory -- skipped.
        )
        echo   Copying MSVC redistributable DLLs ^(vcruntime/msvcp/vcomp^)...
        if exist "%MSVC_REDIST_ROOT%" (
            for /f "delims=" %%d in ('dir /s /b "%MSVC_REDIST_ROOT%\vcruntime140.dll" "%MSVC_REDIST_ROOT%\vcruntime140_1.dll" "%MSVC_REDIST_ROOT%\msvcp140.dll" "%MSVC_REDIST_ROOT%\msvcp140_atomic_wait.dll" "%MSVC_REDIST_ROOT%\vcomp140.dll" 2^>nul') do (
                copy /y "%%d" "%ROOT%partuv\" >nul
            )
        ) else (
            echo   [WARN] %MSVC_REDIST_ROOT% not found -- skipped ^(install the VC++ Redistributable system-wide if the sanity check below still fails^).
        )
        echo   Done. DLLs now present in %ROOT%partuv\ :
        dir /b "%ROOT%partuv\*.dll"
        echo   Sanity check: %PYTHON_MAIN%\python.exe -c "import sys; sys.path.insert(0, r'%ROOT%'); import partuv; print(partuv.__file__)"
    )
)

pause