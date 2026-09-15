import bpy
import numpy as np
import os

BRAIN_DIR = "/Users/subhash/.gemini/antigravity-ide/brain/0053e9ac-632c-4a3d-8526-484430948d44"
WORKSPACE_DIR = "/Users/subhash/Games"

bpy.context.scene.render.image_settings.file_format = 'PNG'
bpy.context.scene.render.image_settings.color_mode = 'RGBA'

ASSET_MAP = [
    # Julius Caesar (Direct Rear View)
    ("caesar_rear_run1_raw_1789476448643.jpg", "assets/sprites/characters/caesar_rear_run1.png", 0.03, 0.10, None),
    ("caesar_rear_run2_raw_1789476464952.jpg", "assets/sprites/characters/caesar_rear_run2.png", 0.03, 0.10, None),
    ("caesar_rear_jump_iso_1789476741474.jpg", "assets/sprites/characters/caesar_rear_jump.png", 0.03, 0.10, None),
    ("caesar_rear_slide_raw_1789476494808.jpg", "assets/sprites/characters/caesar_rear_slide.png", 0.04, 0.12, "caesar_slide_mask"),
    
    # Joan of Arc (Direct Rear View)
    ("joan_rear_run1_raw_1789476549592.jpg", "assets/sprites/characters/joan_rear_run1.png", 0.03, 0.10, None),
    ("joan_rear_run2_raw_1789476572635.jpg", "assets/sprites/characters/joan_rear_run2.png", 0.03, 0.10, None),
    ("joan_rear_jump_raw_1789476589282.jpg", "assets/sprites/characters/joan_rear_jump.png", 0.03, 0.10, None),
    ("joan_rear_slide_raw_1789476603876.jpg", "assets/sprites/characters/joan_rear_slide.png", 0.03, 0.10, None),
    
    # Harriet Tubman (Direct Rear View)
    ("harriet_rear_run1_raw_1789476653739.jpg", "assets/sprites/characters/harriet_rear_run1.png", 0.03, 0.10, None),
    ("harriet_rear_run2_raw_1789476672228.jpg", "assets/sprites/characters/harriet_rear_run2.png", 0.03, 0.10, None),
    ("harriet_rear_jump_raw_1789476685070.jpg", "assets/sprites/characters/harriet_rear_jump.png", 0.03, 0.10, None),
    ("harriet_rear_slide_raw_1789476699724.jpg", "assets/sprites/characters/harriet_rear_slide.png", 0.03, 0.10, None),
]

for src_name, dst_rel, low_th, high_th, special_mask in ASSET_MAP:
    src_path = os.path.join(BRAIN_DIR, src_name)
    dst_path = os.path.join(WORKSPACE_DIR, dst_rel)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    
    print(f"Processing {src_name} -> {dst_rel}...")
    src_img = bpy.data.images.load(src_path)
    w, h = src_img.size
    
    pixels = np.empty(w * h * 4, dtype=np.float32)
    src_img.pixels.foreach_get(pixels)
    pixels = pixels.reshape((h, w, 4))
    
    rgb = pixels[:, :, :3]
    max_c = np.max(rgb, axis=2)
    alpha = np.clip((max_c - low_th) / (high_th - low_th), 0.0, 1.0)
    
    if special_mask == "caesar_slide_mask":
        # Zero out side railings beyond the center sliding character (center is roughly x: 0.20 to 0.82)
        y_indices, x_indices = np.indices((h, w))
        # Fade out peripheral rails on left/right below y=0.65
        left_rail = (x_indices < w * 0.16) & (y_indices < h * 0.65)
        right_rail = (x_indices > w * 0.86) & (y_indices < h * 0.65)
        bottom_dust = (y_indices < h * 0.08)
        alpha[left_rail | right_rail | bottom_dust] = 0.0
    
    # Antialiased defringing
    scale = np.where(alpha > 0.01, 1.0 / np.clip(alpha, 0.25, 1.0), 1.0)
    pixels[:, :, :3] = np.clip(rgb * scale[:, :, None], 0.0, 1.0)
    pixels[:, :, 3] = alpha
    
    dst_img = bpy.data.images.new(f"out_{os.path.basename(dst_rel)}", w, h, alpha=True)
    dst_img.pixels.foreach_set(pixels.reshape(w * h * 4))
    dst_img.save_render(dst_path, scene=bpy.context.scene)
    
    bpy.data.images.remove(src_img)
    bpy.data.images.remove(dst_img)
    print(f"  Successfully wrote {dst_path}")

print("ALL PURE REAR-VIEW ASSETS PROCESSED!")
