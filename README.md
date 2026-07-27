# PartUV (Windows Port)

This repository is a fork of https://github.com/qornflex/PartUV, which is itself a fork of the original **PartUV** project:
https://github.com/EricWang12/PartUV

It provides a **Windows port** of the tool to simplify installation and usage on Windows systems.

---

# Installation (Windows)

There are two ways to get **PartUV** running on Windows: installing a prebuilt wheel (fast, no compiler needed), or building from source (needed if you want to modify the C++/CUDA code).

## Option A: Install prebuilt wheel (recommended)

Prebuilt `.whl` files are published on the [Releases page](https://github.com/Yaprimi/PartUV/releases). Each wheel is self-contained — it already bundles the compiled `_core` extension along with its CUDA runtime, MSVC redistributable, and vcpkg-built dependency DLLs, so you don't need to install the CUDA Toolkit or a compiler to use it.

### Prerequisites

- **Python 3.10** — [download and install](https://www.python.org/ftp/python/3.10.9/python-3.10.9-amd64.exe)
- **NVIDIA GPU with an up-to-date driver** (the CUDA runtime itself ships inside the wheel)

### Steps

1. Download the latest `.whl` from the [Releases page](https://github.com/Yaprimi/PartUV/releases).
2. Install it into your virtual environment:

```bash
pip install --force-reinstall path\to\partuv-<version>-cp310-cp310-win_amd64.whl
```

3. Install the remaining Python dependencies:

```bash
pip install -r requirements.txt
```

## Option B: Build from source

Clone the repository:

```bash
git clone https://github.com/Yaprimi/PartUV.git
```

### Prerequisites

Before building, make sure the following dependencies are installed:

- **Python 3.10** — [download and install](https://www.python.org/ftp/python/3.10.9/python-3.10.9-amd64.exe)
- **CUDA Toolkit 12.8** — [download and install](https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_571.96_windows.exe)

Then run the setup script:

```bash
setup.bat
```

The setup script installs the required Python dependencies and configures the environment to run **PartUV** on Windows.

> **Note:** the repository also includes `bootstrap_env.ps1`, `build.bat`, and `build_wheel.bat` — a fully local, self-contained build toolchain (CMake, Ninja, VS Build Tools, CUDA, vcpkg, Python venv, all installed under `toolchain\` / `envs\` next to the scripts, nothing written to system PATH permanently). Use these if you want to rebuild `partuv` from source or produce your own wheel; see the comments at the top of `bootstrap_env.ps1` for usage and parameters.

---

# Example

An example is provided to demonstrate how to run the tool.

You can start the example by running:

```bash
run.bat
```

The `run.bat` file activates the virtual environment and launches the script using a sample mesh.

You can modify the file to process other meshes by changing the `MESH_PATH` variable or adjusting the parameters.

Example `run.bat`:

```bat
@echo off

call .venv\Scripts\activate

set OCIO=

set MESH_PATH="demo/meshes/table.obj"
set OUTPUT_PATH="output"

python run.py --mesh_path %MESH_PATH% ^
              --pack_method blender ^
              --output_path %OUTPUT_PATH% ^
              --save_visuals ^
              --num_atlas 1
```

* `MESH_PATH` specifies the input mesh.
* `OUTPUT_PATH` defines where the results will be written.
* `--pack_method blender` uses Blender's UV packing method.
* `--save_visuals` outputs visualization images.
* `--num_atlas` defines how many atlases will be generated.

You can replace the mesh path with your own `.obj` files to process different models.

### Hyperparameters
By default, the API reads all hyperparameters from `config/config.yaml`.
See [config.md](doc/config.md) for more details on hyperparameters and usage examples for customizing them to suit your needs.

---

# Credits

Original project:
https://github.com/EricWang12/PartUV

Upstream fork (Windows port base):
https://github.com/qornflex/PartUV