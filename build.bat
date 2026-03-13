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

set PATH=D:\Cpp\cmake\4.2.0\bin\;%PATH%
set PYTHON_MAIN=D:\Python\python3.10.9

:: CONFIGURATION
set "target_path=all_build\release"
set "main_file=main.cpp"
set "VCPKG_PATH=D:/Cpp/vcpkg/scripts/buildsystems/vcpkg.cmake"

echo [1/2] Cleaning and Configuring...
if exist "%target_path%" rd /s /q "%target_path%"
mkdir "%target_path%"
pushd "%target_path%"

:: Use -S (Source) and -B (Build) explicitly to avoid path confusion
cmake -G "Visual Studio 17 2022" -A x64 ^
      -DCMAKE_TOOLCHAIN_FILE="%VCPKG_PATH%" ^
      -DPYTHON_EXECUTABLE=%PYTHON_MAIN%\python.exe ^
      -DPYTHON_INCLUDE_DIR=%PYTHON_MAIN%\include ^
      -DPYTHON_LIBRARY=%PYTHON_MAIN%\libs\python310.lib ^
      -DMAIN_FILE=%main_file% ^
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

echo [2/2] Compiling...
cmake --build . --config Release -j %NUMBER_OF_PROCESSORS%

popd
pause