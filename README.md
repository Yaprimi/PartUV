# PartUV (Windows Port)

This repository is a fork of the original **PartUV** project:
https://github.com/EricWang12/PartUV

It provides a **Windows port** of the tool to simplify installation and usage on Windows systems.

---

# Prerequisites

Before installing, make sure the following dependencies are installed:

### Python 3.10

Download and install:
https://www.python.org/ftp/python/3.10.9/python-3.10.9-amd64.exe

### CUDA Toolkit 12.8

Download and install:
https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_571.96_windows.exe

---

# Installation (Windows)

Clone the repository:

```bash
git clone https://github.com/qornflex/PartUV.git
```

Then run the setup script:

```bash
setup.bat
```

The setup script installs the required Python dependencies and configures the environment to run **PartUV** on Windows.

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

## Hyperparameters
By default, the API reads all hyperparameters from config/config.yaml. See config.md for more details on hyperparameters and usage examples for customizing them to suit your needs.

---

# Credits

Original project:
https://github.com/EricWang12/PartUV
