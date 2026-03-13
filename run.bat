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
