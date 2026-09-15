import bpy
import numpy as np
import os

WORKSPACE_DIR = "/Users/subhash/Games"
BRAIN_DIR = "/Users/subhash/.gemini/antigravity-ide/brain/0053e9ac-632c-4a3d-8526-484430948d44"

bpy.context.scene.render.image_settings.file_format = 'PNG'
bpy.context.scene.render.image_settings.color_mode = 'RGBA'

def clean_character_sprites():
    # 1. Caesar Rear Run 1
    src1 = bpy.data.images.load(os.path.join(BRAIN_DIR, "caesar_rear_run1_raw_1789476448643.jpg"))
    w, h = src1.size
    p1 = np.empty(w * h * 4, dtype=np.float32)
    src1.pixels.foreach_get(p1)
    p1 = p1.reshape((h, w, 4))
    rgb1 = p1[:, :, :3]
    max1 = np.max(rgb1, axis=2)
    alpha1 = np.clip((max1 - 0.03) / (0.10 - 0.03), 0.0, 1.0)
    
    y_idx, x_idx = np.indices((h, w))
    # Cut floor below sole of foot
    alpha1[y_idx < 65] = 0.0
    # Cut peripheral road below knee level
    alpha1[(y_idx < 260) & (x_idx < 425)] = 0.0
    alpha1[(y_idx < 260) & (x_idx > 610)] = 0.0
    # Cut road gap between feet
    alpha1[(y_idx < 170) & (x_idx >= 508) & (x_idx <= 532)] = 0.0
    
    scale1 = np.where(alpha1 > 0.01, 1.0 / np.clip(alpha1, 0.25, 1.0), 1.0)
    p1[:, :, :3] = np.clip(rgb1 * scale1[:, :, None], 0.0, 1.0)
    p1[:, :, 3] = alpha1
    
    dst1 = bpy.data.images.new("c_run1_clean", w, h, alpha=True)
    dst1.pixels.foreach_set(p1.reshape(w * h * 4))
    dst1.save_render(os.path.join(WORKSPACE_DIR, "assets/sprites/characters/caesar_rear_run1.png"), scene=bpy.context.scene)
    bpy.data.images.remove(src1)
    bpy.data.images.remove(dst1)
    print("Cleaned caesar_rear_run1.png")

    # 2. Caesar Rear Run 2
    src2 = bpy.data.images.load(os.path.join(BRAIN_DIR, "caesar_rear_run2_raw_1789476464952.jpg"))
    w, h = src2.size
    p2 = np.empty(w * h * 4, dtype=np.float32)
    src2.pixels.foreach_get(p2)
    p2 = p2.reshape((h, w, 4))
    rgb2 = p2[:, :, :3]
    max2 = np.max(rgb2, axis=2)
    alpha2 = np.clip((max2 - 0.03) / (0.10 - 0.03), 0.0, 1.0)
    
    # Cut floor below sole of foot
    alpha2[y_idx < 50] = 0.0
    # Cut peripheral road below knee level
    alpha2[(y_idx < 270) & (x_idx < 420)] = 0.0
    alpha2[(y_idx < 270) & (x_idx > 600)] = 0.0
    # Cut gap between feet
    alpha2[(y_idx < 140) & (x_idx >= 495) & (x_idx <= 525)] = 0.0
    
    scale2 = np.where(alpha2 > 0.01, 1.0 / np.clip(alpha2, 0.25, 1.0), 1.0)
    p2[:, :, :3] = np.clip(rgb2 * scale2[:, :, None], 0.0, 1.0)
    p2[:, :, 3] = alpha2
    
    dst2 = bpy.data.images.new("c_run2_clean", w, h, alpha=True)
    dst2.pixels.foreach_set(p2.reshape(w * h * 4))
    dst2.save_render(os.path.join(WORKSPACE_DIR, "assets/sprites/characters/caesar_rear_run2.png"), scene=bpy.context.scene)
    bpy.data.images.remove(src2)
    bpy.data.images.remove(dst2)
    print("Cleaned caesar_rear_run2.png")

    # 3. Caesar Rear Slide (Remove road, guardrails, and ground dust)
    src3 = bpy.data.images.load(os.path.join(BRAIN_DIR, "caesar_rear_slide_raw_1789476494808.jpg"))
    w, h = src3.size
    p3 = np.empty(w * h * 4, dtype=np.float32)
    src3.pixels.foreach_get(p3)
    p3 = p3.reshape((h, w, 4))
    rgb3 = p3[:, :, :3]
    max3 = np.max(rgb3, axis=2)
    alpha3 = np.clip((max3 - 0.04) / (0.12 - 0.04), 0.0, 1.0)
    
    # Caesar's body is in the center; remove side guardrails and bottom floor
    alpha3[y_idx < 140] = 0.0 # Clear road and dust below sliding body
    alpha3[x_idx < 240] = 0.0 # Clear left railing
    alpha3[x_idx > 800] = 0.0 # Clear right railing
    alpha3[(y_idx < 320) & ((x_idx < 300) | (x_idx > 740))] = 0.0 # Clear lower side barriers
    
    scale3 = np.where(alpha3 > 0.01, 1.0 / np.clip(alpha3, 0.25, 1.0), 1.0)
    p3[:, :, :3] = np.clip(rgb3 * scale3[:, :, None], 0.0, 1.0)
    p3[:, :, 3] = alpha3
    
    dst3 = bpy.data.images.new("c_slide_clean", w, h, alpha=True)
    dst3.pixels.foreach_set(p3.reshape(w * h * 4))
    dst3.save_render(os.path.join(WORKSPACE_DIR, "assets/sprites/characters/caesar_rear_slide.png"), scene=bpy.context.scene)
    bpy.data.images.remove(src3)
    bpy.data.images.remove(dst3)
    print("Cleaned caesar_rear_slide.png")

    # 4. Joan Rear Slide (Remove floor sparks and road plane)
    src4 = bpy.data.images.load(os.path.join(BRAIN_DIR, "joan_rear_slide_raw_1789476603876.jpg"))
    w, h = src4.size
    p4 = np.empty(w * h * 4, dtype=np.float32)
    src4.pixels.foreach_get(p4)
    p4 = p4.reshape((h, w, 4))
    rgb4 = p4[:, :, :3]
    max4 = np.max(rgb4, axis=2)
    alpha4 = np.clip((max4 - 0.03) / (0.10 - 0.03), 0.0, 1.0)
    
    # Remove floor below knee/cape contact (y < 60)
    alpha4[y_idx < 60] = 0.0
    alpha4[(y_idx < 100) & (x_idx < 320)] = 0.0
    
    scale4 = np.where(alpha4 > 0.01, 1.0 / np.clip(alpha4, 0.25, 1.0), 1.0)
    p4[:, :, :3] = np.clip(rgb4 * scale4[:, :, None], 0.0, 1.0)
    p4[:, :, 3] = alpha4
    
    dst4 = bpy.data.images.new("j_slide_clean", w, h, alpha=True)
    dst4.pixels.foreach_set(p4.reshape(w * h * 4))
    dst4.save_render(os.path.join(WORKSPACE_DIR, "assets/sprites/characters/joan_rear_slide.png"), scene=bpy.context.scene)
    bpy.data.images.remove(src4)
    bpy.data.images.remove(dst4)
    print("Cleaned joan_rear_slide.png")

    # 5. Harriet Rear Slide (Remove floor dust)
    src5 = bpy.data.images.load(os.path.join(BRAIN_DIR, "harriet_rear_slide_raw_1789476699724.jpg"))
    w, h = src5.size
    p5 = np.empty(w * h * 4, dtype=np.float32)
    src5.pixels.foreach_get(p5)
    p5 = p5.reshape((h, w, 4))
    rgb5 = p5[:, :, :3]
    max5 = np.max(rgb5, axis=2)
    alpha5 = np.clip((max5 - 0.03) / (0.10 - 0.03), 0.0, 1.0)
    
    # Remove floor dust below sliding boots/lantern (y < 65)
    alpha5[y_idx < 65] = 0.0
    alpha5[(y_idx < 120) & (x_idx < 180)] = 0.0
    
    scale5 = np.where(alpha5 > 0.01, 1.0 / np.clip(alpha5, 0.25, 1.0), 1.0)
    p5[:, :, :3] = np.clip(rgb5 * scale5[:, :, None], 0.0, 1.0)
    p5[:, :, 3] = alpha5
    
    dst5 = bpy.data.images.new("h_slide_clean", w, h, alpha=True)
    dst5.pixels.foreach_set(p5.reshape(w * h * 4))
    dst5.save_render(os.path.join(WORKSPACE_DIR, "assets/sprites/characters/harriet_rear_slide.png"), scene=bpy.context.scene)
    bpy.data.images.remove(src5)
    bpy.data.images.remove(dst5)
    print("Cleaned harriet_rear_slide.png")

clean_character_sprites()
