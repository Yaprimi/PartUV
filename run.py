import os
import torch
import yaml
import bpy
import pathlib


def convert_fbx2glb(input_filepath, mesh_scale=1.0):
    # 1. Setup paths
    input_dir = os.path.dirname(input_filepath)
    fbx_file_name = pathlib.Path(input_filepath).stem
    output_filepath = os.path.join(input_dir, f"{fbx_file_name}.glb")

    # 2. Clear existing scene to ensure a clean slate
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 3. Import FBX
    input_filepath = os.path.abspath(input_filepath)
    if not os.path.exists(input_filepath):
        raise FileNotFoundError(f"FBX file not found: {input_filepath}")

    # FBX import often needs specific scaling depending on the source (e.g., Maya vs Unity)
    bpy.ops.import_scene.fbx(filepath=input_filepath)

    # 4. Process Mesh Objects
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            # Set as active object
            bpy.context.view_layer.objects.active = obj

            # Apply scale if requested
            obj.scale = (mesh_scale, mesh_scale, mesh_scale)

            # Standardize transformations (Position, Rotation, Scale)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # 5. Export to GLB
    # glTF/GLB is the modern standard for web/AR and handles PBR materials well.
    try:
        bpy.ops.export_scene.gltf(
            filepath=output_filepath,
            export_format='GLB',
            export_image_format='AUTO',  # Automatically handles PNG/JPEG
            export_apply=True,  # Applies modifiers
            export_materials='EXPORT',
            export_colors=True
        )
        print(f"Successfully converted: {fbx_file_name}.fbx -> {output_filepath}")
    except Exception as e:
        print(f"Error during export: {e}")

    return output_filepath


def load_config(filepath):
    with open(filepath, 'r') as file:
        # safe_load converts YAML nodes to native Python dicts/lists
        data = yaml.safe_load(file)
    return data


def partuv_pipeline(args, save_output=True):
    mesh_path = args.mesh_path
    output_path = args.output_path
    config_path = args.config_path
    hierarchy_path = args.hierarchy_path

    config = load_config(config_path)

    if mesh_path.lower().endswith(".fbx"):
        mesh_path = convert_fbx2glb(mesh_path)

    stem, _ = os.path.splitext(os.path.basename(mesh_path))
    output_path = os.path.join(output_path, stem)
    os.makedirs(output_path, exist_ok=True)

    if torch.cuda.is_available():
        torch.cuda.empty_cache()

    from pack.eval_charts import evaluate_mesh
    from pack.pack import pack_mesh
    import partuv
    from partuv.preprocess import preprocess, save_results
    from preprocess_utils.partfield_official.run_PF import PFInferenceModel

    if hierarchy_path is None:
        
        """
        Preprocessing the mesh.

        The code does the following:
        - Load the mesh.
        - Remove existing UV layers, if any.
        - Merge overlapping vertices, and set epsilon to None to disable merging.
        - Fix non-2-manifold meshes, if present.
        - (Optional) export the mesh to an .obj file.
        - Run PartField to generate the hierarchical part tree.

        Notable parameters:
        - sample_on_faces and sample_batch_size: sample points on faces to obtain PartField features for part assignment.
        The larger sample_on_faces is, the more robust the part assignment is, but more points will be sampled and thus it takes more time.
        The larger sample_batch_size is, the less time it takes, but the more GPU memory it uses. Reduce it if you run out of memory.
        - merge_vertices_epsilon: epsilon for merging overlapping vertices; set to None to disable merging.
        - save_processed_mesh: set to False to disable exporting the processed mesh.
        - save_tree_file: set to False to disable saving the tree file for reproducibility.
        - output_path: path where the processed mesh and tree file will be saved.
        """

        pf_model = PFInferenceModel(device="cuda")
        
        mesh, tree_filename, tree_dict, preprocess_times = preprocess(mesh_path, pf_model, output_path,
                                                                      save_tree_file=True,
                                                                      save_processed_mesh=True,
                                                                      sample_on_faces=10,
                                                                      sample_batch_size=100_000,
                                                                      merge_vertices_epsilon=1e-7
                                                                      # merge_vertices_epsilon=None
                                                                      )
        V = mesh.vertices
        F = mesh.faces

        print(f"F.shape after preprocessing: {F.shape}, V.shape: {V.shape}")
        final_parts, individual_parts = partuv.pipeline_numpy(
            V=V,
            F=F,
            tree_dict=tree_dict,
            configPath=config_path,
            threshold=config["pipeline"]["threshold"]
        )
    else:
        """
        Use the provided hierarchy file and processed mesh instead of running Preprocessing.
        """
        tree_filename = hierarchy_path
        mesh_filename = mesh_path

        final_parts, individual_parts = partuv.pipeline(
            tree_filename=tree_filename,
            mesh_filename=mesh_filename,
            configPath=config_path,
            threshold=config["pipeline"]["threshold"]
        )
        
    if save_output:
        save_results(output_path, final_parts, individual_parts)

    print(f"Pipeline completed successfully!")
    print(f"Final parts: {final_parts.num_components} components")
    print(f"Final distortion: {final_parts.distortion}")
    print(f"Individual parts: {len(individual_parts)}")
    
    if final_parts.num_components > 0:
        uv_coords = final_parts.getUV()
        print(f"UV coordinates shape: {uv_coords.shape}")
        
        # You can also access individual components
        for i, component in enumerate(final_parts.components):
            print(f"Chart {i}: {component.F.shape[0]} faces, distortion: {component.distortion}")

    if args.pack_method in ["uvpackmaster", "blender"]:
        print(f"Starting to pack mesh with {args.pack_method} method")
        try:
            pack_mesh(output_path, uvpackmaster = args.pack_method == "uvpackmaster", save_visuals=args.save_visuals, num_atlas=args.num_atlas)
        except Exception as e:
            print(f"Error packing mesh with {args.pack_method} method: {e}")
            print(f"Skipping packing")
    
    print(f"Evaluating final {output_path}/final_packed.obj")

    # metrics_after = evaluate_mesh(os.path.join(output_path, "final_packed.obj"))
    # print(metrics_after)
    
    # Access the UV coordinates
        
def main():
    import argparse

    parser = argparse.ArgumentParser(description="Run PartUV demo pipeline.")
    parser.add_argument("--mesh_path", type=str, default="demo/meshes/0c3ca2b32545416f8f1e6f0e87def1a6.obj", help="input mesh path")
    parser.add_argument("--config_path", "-cf", type=str, default="config/config.yaml", help="Config path.")
    parser.add_argument("--hierarchy_path", "-hp", type=str, default=None, help="(optional) Hierarchy path. If provided, it will be used directly in pipeline and skip the preprocessing (including PartField) entirely, make sure the mesh is preprocessed if the hierarchy file is provided.")
    parser.add_argument("--output_path", "-op", type=str, default=None, help="Output path.")
    parser.add_argument("--pack_method", "-pm", type=str, default="blender", choices=["blender", "uvpackmaster", "none"], help="Pack method.")
    parser.add_argument("--save_visuals", "-sv", action="store_true", default=False, help="Save visuals (such as) after packing. This will be ignored if pack_method is 'none'.")
    parser.add_argument("--num_atlas", "-na", type=int, default=None, help="Number of atlas to pack if multi-atlas packing is used.")
    args = parser.parse_args()

    if args.output_path is None:
        mesh_name = os.path.basename(args.mesh_path).split(".")[0]
        args.output_path = os.path.join("./output", mesh_name)
        os.makedirs(args.output_path, exist_ok=True)

    partuv_pipeline(args, save_output=True)
    
    print("Done")


if __name__ == "__main__":
    main()