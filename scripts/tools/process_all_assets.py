import bpy
import numpy as np
import os

BRAIN_DIR = "/Users/subhash/.gemini/antigravity-ide/brain/0053e9ac-632c-4a3d-8526-484430948d44"
WORKSPACE_DIR = "/Users/subhash/Games"

bpy.context.scene.render.image_settings.file_format = 'PNG'
bpy.context.scene.render.image_settings.color_mode = 'RGBA'

ASSET_MAP = [
    # Characters
    ("caesar_run_raw_1789436160657.jpg", "assets/sprites/characters/caesar_run.png", True, 0.03, 0.10),
    ("caesar_jump_raw_1789436212290.jpg", "assets/sprites/characters/caesar_jump.png", True, 0.03, 0.10),
    ("caesar_slide_raw_1789436230453.jpg", "assets/sprites/characters/caesar_slide.png", True, 0.03, 0.10),
    ("joan_run_raw_1789436178919.jpg", "assets/sprites/characters/joan_run.png", True, 0.03, 0.10),
    ("joan_jump_raw_1789436255498.jpg", "assets/sprites/characters/joan_jump.png", True, 0.03, 0.10),
    ("joan_slide_raw_1789436267052.jpg", "assets/sprites/characters/joan_slide.png", True, 0.03, 0.10),
    ("harriet_run_raw_1789436195793.jpg", "assets/sprites/characters/harriet_run.png", True, 0.03, 0.10),
    ("harriet_jump_raw_1789436281149.jpg", "assets/sprites/characters/harriet_jump.png", True, 0.03, 0.10),
    ("harriet_slide_raw_1789436295613.jpg", "assets/sprites/characters/harriet_slide.png", True, 0.03, 0.10),
    
    # Props & Collectibles
    ("obstacle_barricade_1789436327005.jpg", "assets/sprites/props/obstacle_barricade.png", True, 0.03, 0.10),
    ("collectible_fist_1789436337929.jpg", "assets/sprites/props/collectible_fist.png", True, 0.02, 0.08),
    ("collectible_crown_1789436349637.jpg", "assets/sprites/props/collectible_crown.png", True, 0.02, 0.08),
    
    # Environment (Opaque)
    ("road_roman_pbr_1789436316012.jpg", "assets/sprites/environment/road_roman_pbr.png", False, 0.0, 1.0),
]

for src_name, dst_rel, has_alpha, low_th, high_th in ASSET_MAP:
    src_path = os.path.join(BRAIN_DIR, src_name)
    dst_path = os.path.join(WORKSPACE_DIR, dst_rel)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    
    print(f"Processing {src_name} -> {dst_rel}...")
    src_img = bpy.data.images.load(src_path)
    w, h = src_img.size
    
    pixels = np.empty(w * h * 4, dtype=np.float32)
    src_img.pixels.foreach_get(pixels)
    pixels = pixels.reshape((h, w, 4))
    
    if has_alpha:
        rgb = pixels[:, :, :3]
        max_c = np.max(rgb, axis=2)
        alpha = np.clip((max_c - low_th) / (high_th - low_th), 0.0, 1.0)
        
        # Smooth antialiased defringing to remove any dark halo
        scale = np.where(alpha > 0.01, 1.0 / np.clip(alpha, 0.25, 1.0), 1.0)
        pixels[:, :, :3] = np.clip(rgb * scale[:, :, None], 0.0, 1.0)
        pixels[:, :, 3] = alpha
    else:
        pixels[:, :, 3] = 1.0
        
    dst_img = bpy.data.images.new(f"out_{os.path.basename(dst_rel)}", w, h, alpha=True)
    dst_img.pixels.foreach_set(pixels.reshape(w * h * 4))
    dst_img.save_render(dst_path, scene=bpy.context.scene)
    
    bpy.data.images.remove(src_img)
    bpy.data.images.remove(dst_img)
    print(f"  Successfully wrote {dst_path}")

print("ALL ASSETS PROCESSED!")
